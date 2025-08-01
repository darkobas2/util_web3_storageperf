library(jsonlite)
library(tidyverse)
library(ggbeeswarm)



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
tibble(file = Sys.glob("../data/swarm-2025-07/references/*")) |>
  mutate(size_kb = map_int(file, uploadFileSizeFromJsonRaw)) |>
  filter(is.na(size_kb))

datUpload <- tidyUploadData("../data/swarm-2025-06/references/*")


datUpload |>
  ggplot(aes(x = size_kb, y = time_sec, color = erasure, fill = erasure,
             group = as_factor(str_c(size_kb, erasure)))) +
  geom_boxplot(alpha = 0.3) +
  scale_x_log10(limits = c(0.5, 1e6),
                breaks = c(10, 1000, 100000),
                labels = c("10 KB", "1 MB", "100 MB")) +
  scale_y_log10(limits = c(0.08, 2300),
                breaks = c(0.5, 30, 1800),
                labels = c("0.5 s", "1 m", "30 m")) +
  scale_color_viridis_d(option = "C", end = 0.85) +
  scale_fill_viridis_d(option = "C", end = 0.85) +
  labs(x = "File size", y = "Upload time",
       color = "Erasure coding", fill = "Erasure coding") +
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
                labels = c("1 KB", "100 KB", "10 MB", "1 GB")) +
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
                labels = c("10 KB", "1 MB", "100 MB")) +
  scale_y_log10(breaks = c(0.5, 30, 1800),
                labels = c("0.5 s", "1 m", "30 m")) +
  scale_color_viridis_d(option = "C", end = 0.85) +
  scale_fill_viridis_d(option = "C", end = 0.85) +
  labs(x = "Effective file size", y = "Upload time",
       color = "Erasure coding: ", fill = "Erasure coding: ") +
  theme_bw() +
  theme(legend.position = "bottom")



# Compare upload times with previous benchmarks
uploadSets <-
  tidyUploadData("../data/swarm-2025-06/references/*") |>
  mutate(dataset = "2025-06", .before = 1) |>
  bind_rows(tidyUploadData("../data/swarm-2025-07/references/*") |>
              mutate(dataset = "2025-07", .before = 1))

uploadSets |>
  ggplot(aes(x = dataset, y = time_sec, color = dataset)) +
  geom_quasirandom(alpha = 0.3) +
  facet_grid(erasure ~ size_kb) +
  scale_y_log10() +
  scale_color_manual(values = c("steelblue", "goldenrod")) +
  guides(color = "none", fill = "none") +
  theme_bw()

uploadSets |>
  mutate(ztime = (time_sec - mean(time_sec)) / sd(time_sec),
         .by = c(dataset, size_kb, erasure)) |>
  ggplot(aes(x = dataset, y = ztime, color = dataset)) +
  geom_quasirandom(alpha = 0.3) +
  facet_grid(erasure ~ size_kb) +
  scale_color_manual(values = c("steelblue", "goldenrod")) +
  guides(color = "none", fill = "none") +
  theme_bw()

# Compare each pair of observation groups with Wilcoxon rank sum tests; plot results:
uploadSets |>
  mutate(ztime = (time_sec - mean(time_sec)) / sd(time_sec),
         .by = c(dataset, size_kb, erasure)) |>
  select(!time_sec) |>
  nest(data = dataset | ztime) |>
  filter(map_lgl(data, \(x) nrow(distinct(x, dataset)) == 2L)) |>
  mutate(wilcox = map(data, \(x) wilcox.test(ztime ~ dataset, data = x,
                                             conf.int = TRUE, conf.level = 0.95))) |>
  mutate(wilcox = map(wilcox, broom::tidy)) |>
  unnest(wilcox) |>
  select(!data & !statistic & !method & !alternative) |>
  mutate(adj.p.value = p.adjust(p.value, "fdr"), .after = p.value) |>
  mutate(signif = ifelse(adj.p.value < 0.05, "", "not ") |> str_c("significant")) |>
  mutate(size_kb = as_factor(size_kb)) |>
  ggplot(aes(x = size_kb, y = estimate, ymin = conf.low, ymax = conf.high,
             color = signif)) +
  geom_point() +
  geom_errorbar(width = 0.2) +
  scale_color_manual(values = c("significant"="steelblue", "not significant"="gray60")) +
  scale_x_discrete(breaks = c(1, 10, 100, 1000, 10000, 50000),
                   labels = c("1 KB", "10 KB", "100 KB", "1 MB", "10 MB", "50 MB")) +
  facet_grid(erasure ~ .) +
  labs(x = "File size", y = "Estimated difference") +
  theme_bw()
