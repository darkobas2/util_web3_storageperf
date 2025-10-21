library(tidyverse)
library(ggbeeswarm)
library(lme4)
library(ggfortify)



readDownloadData <- function(file) {
  read_rds(file) |>
    filter(sha256_match) |>
    select(!sha256_match & !attempts) |>
    mutate(erasure = fct_relevel(erasure, "NONE", "MEDIUM", "STRONG",
                                 "INSANE", "PARANOID")) |>
    mutate(strategy = fct_relevel(strategy, "NONE", "DATA", "RACE")) |>
    arrange(platform, erasure, strategy, size_kb, server)
}


humanReadableSize <- function(size_kb) {
  (1000 * size_kb) |>
    gdata::humanReadable(standard = "SI", digits = 0) |>
    str_trim()
}


ztrans <- function(x) (x - mean(x)) / sd(x)


# Compare download time z-scores visually:
compareZplot <- function(downloadDat, strat) {
  downloadDat |>
    mutate(ztime = ztrans(time_sec),
           .by = c(size, server, erasure, strategy)) |>
    filter(as.character(strategy) %in% c("NONE", strat)) |>
    ggplot(aes(x = size, y = ztime, color = dataset, fill = dataset,
               group = str_c(server, erasure, size, dataset))) +
    geom_quasirandom(alpha = 0.3, dodge.width = 0.8) +
    scale_color_manual(values = c("#0072B2", "#E69F00")) +
    labs(x = "File size", y = "Download time (z-score)",
         color = "Dataset: ", fill = "Dataset: ") +
    facet_grid(erasure ~ server) +
    guides(color = guide_legend(override.aes = list(alpha = 1))) +
    theme_bw() +
    theme(legend.position = "bottom")
}



downloadDat <-
  bind_rows(
    readDownloadData("../data/swarm-2025-07/swarm.rds") |>
      mutate(dataset = "v2.6", .before = 1),
    readDownloadData("../data/swarm-2025-07_with_PR5097/swarm.rds") |>
      mutate(dataset = "v2.6+PR", .before = 1)
  ) |>
  select(!platform) |>
  mutate(size = fct_reorder(humanReadableSize(size_kb), size_kb)) |>
  mutate(dataset = as_factor(dataset))


# Side-by-side comparisons
# For the DATA strategy:
downloadDat |>
  filter(as.character(strategy) %in% c("NONE", "DATA")) |>
  mutate(size_b = 1000*size_kb) |>
  ggplot(aes(x = size_b, y = time_sec, color = dataset,
             group = str_c(server, erasure, size_b, dataset))) +
  geom_quasirandom(alpha = 0.3, dodge.width = 0.6) +
  scale_x_log10(labels = scales::label_bytes()) +
  scale_y_log10() +
  scale_color_manual(values = c("#0072B2", "#E69F00")) +
  labs(x = "File size", y = "Download time (seconds)",
       color = "Dataset: ", fill = "Dataset: ") +
  facet_grid(erasure ~ server) +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  theme_bw() +
  theme(legend.position = "bottom")

# For the RACE strategy:
downloadDat |>
  filter(as.character(strategy) %in% c("NONE", "RACE")) |>
  mutate(size_b = 1000*size_kb) |>
  ggplot(aes(x = size_b, y = time_sec, color = dataset,
             group = str_c(server, erasure, size_b, dataset))) +
  geom_quasirandom(alpha = 0.3, dodge.width = 0.6) +
  scale_x_log10(labels = scales::label_bytes()) +
  scale_y_log10() +
  scale_color_manual(values = c("#0072B2", "#E69F00")) +
  labs(x = "File size", y = "Download time (seconds)",
       color = "Dataset: ", fill = "Dataset: ") +
  facet_grid(erasure ~ server) +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  theme_bw() +
  theme(legend.position = "bottom")

# Both strategies, merging the different servers:
downloadDat |>
  mutate(strategy = ifelse(strategy == "RACE", "RACE", "NONE/DATA")) |>
  mutate(size_b = 1000*size_kb) |>
  ggplot(aes(x = size_b, y = time_sec, color = dataset,
             group = str_c(erasure, size_b, dataset))) +
  geom_quasirandom(alpha = 0.3, dodge.width = 0.6) +
  scale_x_log10(labels = scales::label_bytes()) +
  scale_y_log10() +
  scale_color_manual(values = c("#0072B2", "#E69F00")) +
  labs(x = "File size", y = "Download time (seconds)",
       color = "Dataset: ", fill = "Dataset: ") +
  facet_grid(erasure ~ strategy) +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  theme_bw() +
  theme(legend.position = "bottom")


# Comparison of time z-scores (to fix issues of scale)
# For the DATA strategy:
downloadDat |>
  mutate(ztime = ztrans(time_sec),
         .by = c(size, server, erasure, strategy)) |>
  filter(as.character(strategy) %in% c("NONE", "DATA")) |>
  ggplot(aes(x = size, y = ztime, color = dataset, fill = dataset,
             group = str_c(server, erasure, size, dataset))) +
  geom_quasirandom(alpha = 0.3, dodge.width = 0.8) +
  scale_color_manual(values = c("#0072B2", "#E69F00")) +
  labs(x = "File size", y = "Download time (z-score)",
       color = "Dataset: ", fill = "Dataset: ") +
  facet_grid(erasure ~ server) +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  theme_bw() +
  theme(legend.position = "bottom")

# For the RACE strategy:
downloadDat |>
  mutate(ztime = ztrans(time_sec),
         .by = c(size, server, erasure, strategy)) |>
  filter(as.character(strategy) %in% c("NONE", "RACE")) |>
  ggplot(aes(x = size, y = ztime, color = dataset, fill = dataset,
             group = str_c(server, erasure, size, dataset))) +
  geom_quasirandom(alpha = 0.3, dodge.width = 0.8) +
  scale_color_manual(values = c("#0072B2", "#E69F00")) +
  labs(x = "File size", y = "Download time (z-score)",
       color = "Dataset: ", fill = "Dataset: ") +
  facet_grid(erasure ~ server) +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  theme_bw() +
  theme(legend.position = "bottom")

# Both strategies, merging the different servers:
downloadDat |>
  mutate(ztime = ztrans(time_sec),
         .by = c(size, server, erasure, strategy)) |>
  mutate(strategy = ifelse(strategy == "RACE", "RACE", "NONE/DATA")) |>
  ggplot(aes(x = size, y = ztime, color = dataset, fill = dataset,
             group = str_c(erasure, size, dataset))) +
  geom_quasirandom(alpha = 0.3, dodge.width = 0.8) +
  scale_color_manual(values = c("#0072B2", "#E69F00")) +
  labs(x = "File size", y = "Download time (z-score)",
       color = "Dataset: ", fill = "Dataset: ") +
  facet_grid(erasure ~ strategy) +
  guides(color = guide_legend(override.aes = list(alpha = 1))) +
  theme_bw() +
  theme(legend.position = "bottom")


# Compare each pair of observation groups with Mann-Whitney tests:
downloadDat |>
  select(!size_kb) |>
  nest(data = dataset | server | time_sec) |>
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
  mutate(adv = fct_relevel(adv, "v2.6", "No difference")) |>
  mutate(strategy = ifelse(strategy == "RACE", "RACE", "NONE/DATA")) |>
  ggplot(aes(x = strategy, y = estimate, ymin = conf.low,
             ymax = conf.high, color = adv)) +
  geom_hline(yintercept = 0, alpha = 0.4, linetype = "dashed") +
  geom_point() +
  geom_errorbar(width = 0.2) +
  scale_color_manual(
    name = "Speed advantage:",
    values = c("v2.6" = "#0072B2",
               "No difference" = "grey70",
               "v2.6+PR" = "#E69F00"),
    drop = FALSE
  ) +
  facet_grid(size ~ erasure, scales = "free_y") +
  labs(x = NULL, y = "Estimated difference (seconds)") +
  theme_bw() +
  theme(legend.position = "bottom")


# The same, but also broken down by server identity:
downloadDat |>
  select(!size_kb) |>
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
  mutate(adv = fct_relevel(adv, "v2.6", "No difference")) |>
  mutate(strategy = ifelse(strategy == "RACE", "RACE", "NONE/DATA")) |>
  ggplot(aes(x = strategy, y = estimate, ymin = conf.low,
             ymax = conf.high, color = adv, group = server)) +
  geom_hline(yintercept = 0, alpha = 0.4, linetype = "dashed") +
  geom_point(position = position_dodge(width = 0.5)) +
  geom_errorbar(width = 0.3, position = position_dodge(width = 0.5)) +
  scale_color_manual(
    name = "Speed advantage:",
    values = c("v2.6" = "#0072B2",
               "No difference" = "grey70",
               "v2.6+PR" = "#E69F00"),
    drop = FALSE
  ) +
  facet_grid(size ~ erasure, scales = "free_y") +
  labs(
    x = NULL, y = "Estimated difference (seconds)", shape = "Server:"
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

# Fit GLMM:
downloadDat |>
  filter(strategy != "NONE") |>
  glmer(time_sec ~ I(log(size_kb)^2) + erasure + strategy + dataset +
          (1 | server),
        data = _, family = gaussian(link = "log")) |>
  summary()
