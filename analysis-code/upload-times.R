library(jsonlite)
library(tidyverse)
library(ggbeeswarm)
library(ggfortify)



uploadDataFromJsonRaw <- function(jsonFile) {
  fromJSON(jsonFile) |>
    (`[`)(1) |>
    as_tibble() |>
    unnest(swarm) |>
    rename(erasure = ul_redundancy, time_sec = upload_time)
}


uploadFileSizeFromJsonRaw <- function(jsonFile) {
  fromJSON(jsonFile) |>
    (`[`)(1) |>
    (`[[`)(1) |>
    names() |>
    (\(x) if (length(x) > 0) as.integer(x) else NA_integer_)()
}


correctedSize <- function(erasure, encryption) {
  case_when( # File size overhead from erasure coding and packed-address chunks
    (erasure == "NONE")     & (encryption == "unencrypted") ~ (128/128) * (128/127),
    (erasure == "MEDIUM")   & (encryption == "unencrypted") ~ (128/119) * (128/127),
    (erasure == "STRONG")   & (encryption == "unencrypted") ~ (128/107) * (128/127),
    (erasure == "INSANE")   & (encryption == "unencrypted") ~ (128/97)  * (128/127),
    (erasure == "PARANOID") & (encryption == "unencrypted") ~ (128/38)  * (128/127),
    (erasure == "NONE")     & (encryption == "encrypted")   ~ (64/64)   * (64/63),
    (erasure == "MEDIUM")   & (encryption == "encrypted")   ~ (64/59)   * (64/63),
    (erasure == "STRONG")   & (encryption == "encrypted")   ~ (64/53)   * (64/63),
    (erasure == "INSANE")   & (encryption == "encrypted")   ~ (64/48)   * (64/63),
    (erasure == "PARANOID") & (encryption == "encrypted")   ~ (64/19)   * (64/63)
  )
}


humanReadableSize <- function(size_kb) {
  gdata::humanReadable(1000*size_kb, standard = "SI", digits = 0) |>
    str_trim()
}


ztrans <- function(x) (x - mean(x)) / sd(x)


tidyUploadData <- function(referencePath) {
  tibble(file = Sys.glob(referencePath)) |>
    mutate(size_kb = map_int(file, uploadFileSizeFromJsonRaw)) |>
    drop_na() |> # Drop any faulty references
    mutate(data = map(file, uploadDataFromJsonRaw)) |>
    unnest(data) |>
    select(erasure, size_kb, time_sec) |>
    arrange(erasure, size_kb, time_sec) |>
    mutate(erasure = as_factor(case_match(
      erasure,
      0 ~ "NONE",
      1 ~ "MEDIUM",
      2 ~ "STRONG",
      3 ~ "INSANE",
      4 ~ "PARANOID"
    )))
}



# Any faulty references?
tibble(file = Sys.glob("../data/swarm-2025-07_with_PR5097/references/*")) |>
  mutate(size_kb = map_int(file, uploadFileSizeFromJsonRaw)) |>
  filter(is.na(size_kb))

datUpload <- tidyUploadData("../data/swarm-2025-07/references/*")


# Plotting the raw data:
datUpload |>
  mutate(time_min = time_sec / 60) |>
  ggplot(aes(x = size_kb, y = time_min, color = erasure,
             group = as_factor(str_c(size_kb, erasure)))) +
  geom_quasirandom(alpha = 0.3, dodge.width = 0.6) +
  scale_x_log10(limits = c(0.5, 1e6),
                breaks = c(10, 1000, 100000),
                labels = humanReadableSize(c(10, 1000, 100000))) +
  scale_y_log10(limits = c(0.00125, 2.6)) +
  scale_color_viridis_d(option = "C", end = 0.85) +
  labs(x = "File size", y = "Upload time (minutes)",
       color = "Erasure coding", fill = "Erasure coding") +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  theme_bw()


uploadModel1 <-
  datUpload |>
  glm(time_sec ~ I(log(size_kb)^2) + erasure,
      data = _, family = gaussian(link = "log"))
broom::glance(uploadModel1)
summary(uploadModel1)


datUpload |>
  mutate(time_predict = predict(uploadModel1, type = "response")) |>
  mutate(erasure = as_factor(str_c("Erasure: ", erasure))) |>
  ggplot(aes(x = size_kb)) +
  geom_boxplot(aes(y = time_sec, group = size_kb),
               fill = "steelblue", color = "steelblue", alpha = 0.3) +
  geom_line(aes(y = time_predict), color = "black", alpha = 0.5) +
  scale_x_log10(breaks = c(1, 100, 10000, 1000000),
                labels = humanReadableSize(c(1, 100, 10000, 1000000))) +
  scale_y_log10(breaks = 10^(-1:2), labels = c(0.1, 1, 10, 100)) +
  labs(x = "File size", y = "Upload time (seconds)",
       color = "Erasure coding", fill = "Erasure coding") +
  facet_grid(. ~ erasure) +
  theme_bw()


uploadModel2 <-
  datUpload |>
  mutate(eff_size_kb = size_kb * correctedSize(erasure, "unencrypted")) |>
  glm(time_sec ~ I(log(eff_size_kb)^2) + erasure,
      data = _, family = gaussian(link = "log"))
broom::glance(uploadModel2)
summary(uploadModel2)


datUpload |>
  mutate(eff_size_kb = size_kb * correctedSize(erasure, "unencrypted")) |>
  mutate(pred = predict(uploadModel2, type = "response")) |>
  ggplot(aes(x = eff_size_kb, color = erasure, fill = erasure)) +
  geom_boxplot(aes(y = time_sec, group = str_c(erasure, eff_size_kb)),
               alpha = 0.3, width = 0.1) +
  geom_line(aes(y = pred)) +
  scale_x_log10(breaks = c(10, 1000, 100000),
                labels = humanReadableSize(c(10, 1000, 100000))) +
  scale_y_log10(breaks = c(0.5, 30, 1800),
                labels = c("0.5 s", "1 m", "30 m")) +
  scale_color_viridis_d(option = "C", end = 0.85) +
  scale_fill_viridis_d(option = "C", end = 0.85) +
  labs(x = "Effective file size", y = "Upload time",
       color = "Erasure coding: ", fill = "Erasure coding: ") +
  theme_bw() +
  theme(legend.position = "bottom")



# Compare upload times with previous benchmarks
uploadDat <-
  tidyUploadData("../data/swarm-2025-07/references/*") |>
  mutate(dataset = "v2.6", .before = 1) |>
  bind_rows(tidyUploadData("../data/swarm-2025-07_with_PR5097/references/*") |>
              mutate(dataset = "v2.6+PR", .before = 1)) |>
  mutate(dataset = as_factor(dataset)) |>
  mutate(size = fct_reorder(humanReadableSize(size_kb), size_kb))


uploadDat |>
  mutate(time_min = time_sec / 60) |>
  mutate(dataset = str_remove(dataset, "Release ")) |>
  ggplot(aes(x = dataset, y = time_min, color = erasure,
             group = as_factor(str_c(size_kb, erasure)))) +
  geom_quasirandom(alpha = 0.3, dodge.width = 0.6) +
  facet_grid(. ~ size) +
  scale_y_log10() +
  scale_color_viridis_d(option = "C", end = 0.85) +
  labs(x = "Release", y = "Upload time (minutes)",
       color = "Erasure coding:") +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  theme_bw() +
  theme(legend.position = "bottom")

uploadDat |>
  mutate(ztime = ztrans(time_sec), .by = c(size, erasure)) |>
  ggplot(aes(x = dataset, y = ztime, color = erasure,
             group = as_factor(str_c(size_kb, erasure)))) +
  geom_quasirandom(alpha = 0.3, dodge.width = 0.6) +
  facet_wrap(~ size, scales = "fixed", nrow = 1) +
  scale_y_continuous(limits = c(NA, 5)) + # Remove 9 outliers
  scale_color_viridis_d(option = "C", end = 0.85) +
  labs(x = "File size", y = "Upload time (z-score)",
       color = "Erasure coding:") +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  theme_bw() +
  theme(legend.position = "bottom")

# Compare each pair of observation groups with Wilcoxon rank sum tests; plot results:
uploadDat |>
  nest(data = dataset | time_sec) |>
  mutate(wilcox = map(data, \(x) {
    wilcox.test(time_sec ~ dataset, data = x,
                conf.int = TRUE, conf.level = 0.95)
  } )) |>
  mutate(wilcox = map(wilcox, broom::tidy)) |>
  unnest(wilcox) |>
  select(!data & !statistic & !method & !alternative) |>
  mutate(adj.p.value = p.adjust(p.value, "fdr"), .after = p.value) |>
  mutate(adv = case_when(
    adj.p.value <  0.05 & estimate > 0 ~ "v2.6+PR",
    adj.p.value <  0.05 & estimate < 0 ~ "v2.6",
    adj.p.value >= 0.05                ~ "No difference"
  )) |>
  ggplot(aes(x = erasure, y = estimate, ymin = conf.low,
             ymax = conf.high, color = adv)) +
  geom_hline(yintercept = 0, alpha = 0.4, linetype = "dashed") +
  geom_point() +
  geom_errorbar(width = 0.1) +
  scale_color_manual(
    name = "Speed advantage:",
    values = c("v2.6+PR"="#E69F00", "No difference"="grey70", "v2.6"="#0072B2"),
    drop = FALSE
  ) +
  facet_grid(size ~ ., scales = "free_y") +
  labs(x = NULL, y = "Estimated difference (seconds)", color = "") +
  theme_bw() +
  theme(legend.position = "bottom")
