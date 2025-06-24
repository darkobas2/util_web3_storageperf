library(jsonlite)
library(tidyverse)
library(lme4)
library(broom)



readDownloadData <- function(file) {
  read_rds(file) |>
    # Remove failed downloads:
    filter(sha256_match) |>
    # Remove columns that are no longer needed:
    select(!sha256_match & !attempts) |>
    # Convert erasure and strategy to factors, for easier handling later:
    mutate(erasure = fct_relevel(erasure, "NONE", "MEDIUM", "STRONG",
                                 "INSANE", "PARANOID")) |>
    mutate(strategy = fct_relevel(strategy, "NONE", "DATA", "RACE")) |>
    # Keep rows in a logical order:
    arrange(platform, erasure, strategy, size_kb, server)
}



dat <-
  readDownloadData("../data/swarm-2025-04/swarm.rds") |>
  mutate(dataset = "2025-04", .before = 1) |>
  bind_rows(readDownloadData("../data/swarm-2025-06/swarm.rds") |>
              mutate(dataset = "2025-06", .before = 1))


dat |>
  filter(strategy %in% c("NONE", "DATA")) |>
  ggplot(aes(x = size_kb, y = time_sec, color = dataset, fill = dataset,
             group = str_c(server, erasure, size_kb, dataset))) +
  geom_boxplot(alpha = 0.3, coef = Inf) +
  scale_x_log10(breaks = c(10, 1000, 100000),
                labels = c("10 KB", "1 MB", "100 MB")) +
  scale_y_log10(breaks = c(0.5, 30, 1800),
                labels = c("0.5 s", "1 m", "30 m")) +
  scale_color_manual(values = c("steelblue", "goldenrod")) +
  scale_fill_manual(values = c("steelblue", "goldenrod")) +
  labs(x = "File size", y = "Download time",
       color = "Dataset: ", fill = "Dataset: ") +
  facet_grid(erasure ~ server) +
  theme_bw() +
  theme(legend.position = "bottom")


dat |>
  mutate(ztime = (time_sec - mean(time_sec)) / sd(time_sec),
         .by = c(dataset, size_kb, server, erasure, strategy)) |>
  select(!platform & !time_sec) |>
  filter(size_kb <= 10000) |>
  filter(strategy %in% c("NONE", "DATA")) |>
  mutate(size_kb = as_factor(size_kb)) |>
  ggplot(aes(x = size_kb, y = ztime, color = dataset, fill = dataset,
             group = str_c(server, erasure, size_kb, dataset))) +
  geom_boxplot(alpha = 0.3, coef = Inf) +
  scale_color_manual(values = c("steelblue", "goldenrod")) +
  scale_fill_manual(values = c("steelblue", "goldenrod")) +
  labs(x = "File size (KB)", y = "Download time (z-score)",
       color = "Dataset: ", fill = "Dataset: ") +
  facet_grid(erasure ~ server) +
  theme_bw() +
  theme(legend.position = "bottom")


dat |>
  mutate(ztime = (time_sec - mean(time_sec)) / sd(time_sec),
         .by = c(dataset, size_kb, server, erasure, strategy)) |>
  select(!platform & !time_sec) |>
  nest(data = dataset | server | ztime) |>
  filter(map_lgl(data, \(x) nrow(distinct(x, dataset)) == 2L)) |>
  mutate(wilcox = map(data, \(x) wilcox.test(ztime ~ dataset, data = x,
                                             conf.int = TRUE, conf.level = 0.95))) |>
  mutate(wilcox = map(wilcox, tidy)) |>
  unnest(wilcox) |>
  select(!data & !statistic & !method & !alternative) |>
  mutate(adj.p.value = p.adjust(p.value, "fdr"), .after = p.value) |>
  mutate(signif = ifelse(adj.p.value < 0.05, "significant", "nonsignificant")) |>
  mutate(strategy = ifelse(strategy == "RACE", "RACE", "NONE/DATA")) |>
  mutate(size_kb = as_factor(size_kb)) |>
  ggplot(aes(x = size_kb, y = estimate, ymin = conf.low, ymax = conf.high,
             color = signif)) +
  geom_point() +
  geom_errorbar(width = 0.2) +
  scale_color_manual(values = c("significant"="steelblue", "nonsignificant"="gray")) +
  facet_grid(erasure ~ strategy) +
  theme_bw()
