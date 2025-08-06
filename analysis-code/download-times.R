library(tidyverse)
library(ggbeeswarm)



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


humanReadableSize <- function(size_kb) {
  gdata::humanReadable(1000*size_kb, standard = "SI", digits = 0)
}


# Side-by-side visualization of the different sets of results:
compareTimePlot <- function(data, strategy) {
  data |>
    filter(strategy %in% c("NONE", {{strategy}})) |>
    mutate(size_b = 1000*size_kb) |>
    ggplot(aes(x = size_b, y = time_sec, color = dataset,
               group = str_c(server, erasure, size_b, dataset))) +
    geom_quasirandom(alpha = 0.3, dodge.width = 0.6) +
    scale_x_log10(labels = scales::label_bytes()) +
    scale_y_log10() +
    scale_color_manual(values = c("steelblue", "goldenrod")) +
    labs(x = "File size", y = "Download time (seconds)",
         color = "Dataset: ", fill = "Dataset: ") +
    facet_grid(erasure ~ server) +
    theme_bw() +
    theme(legend.position = "bottom")
}


# Compare download time z-scores
compareZplot <- function(data, strategy) {
  data |>
    mutate(ztime = (time_sec - mean(time_sec)) / sd(time_sec),
           .by = c(size_kb, server, erasure, strategy)) |>
    mutate(size = str_trim(humanReadableSize(size_kb))) |>
    select(!platform & !time_sec & !size_kb) |>
    filter(strategy %in% c("NONE", {{strategy}})) |>
    mutate(size = as_factor(size)) |>
    ggplot(aes(x = size, y = ztime, color = dataset, fill = dataset,
               group = str_c(server, erasure, size, dataset))) +
    geom_quasirandom(alpha = 0.3, dodge.width = 0.8) +
    scale_color_manual(values = c("steelblue", "goldenrod")) +
    labs(x = "File size", y = "Download time (z-score)",
         color = "Dataset: ", fill = "Dataset: ") +
    facet_grid(erasure ~ server) +
    theme_bw() +
    theme(legend.position = "bottom")
}



dat <-
  readDownloadData("../data/swarm-2025-06/swarm.rds") |>
  mutate(dataset = "2025-06", .before = 1) |>
  bind_rows(readDownloadData("../data/swarm-2025-07/swarm.rds") |>
              mutate(dataset = "2025-07", .before = 1))


# Side-by-side comparisons:
compareTimePlot(dat, "DATA") # For the DATA strategy
compareTimePlot(dat, "RACE") # For the RACE strategy

# Comparison of time z-scores (to fix issues of scale):
compareZplot(dat, "DATA") # For the DATA strategy
compareZplot(dat, "RACE") # For the RACE strategy

# Compare each pair of observation groups with Wilcoxon rank sum tests; plot results:
dat |>
  mutate(size = fct_reorder(str_trim(humanReadableSize(size_kb)), size_kb)) |>
  select(!platform & !size_kb) |>
  nest(data = dataset | server | time_sec) |>
  filter(map_lgl(data, \(x) nrow(distinct(x, dataset)) == 2L)) |>
  mutate(wilcox = map(data, \(x) wilcox.test(time_sec ~ dataset, data = x,
                                             conf.int = TRUE, conf.level = 0.95))) |>
  mutate(wilcox = map(wilcox, broom::tidy)) |>
  unnest(wilcox) |>
  select(!data & !statistic & !method & !alternative) |>
  mutate(adj.p.value = p.adjust(p.value, "fdr"), .after = p.value) |>
  mutate(signif = case_when(
    adj.p.value <  0.05 & estimate > 0 ~ "New release significantly faster",
    adj.p.value <  0.05 & estimate < 0 ~ "New release significantly slower",
    TRUE                               ~ "Difference not significant"
  )) |>
  mutate(strategy = ifelse(strategy == "RACE", "RACE", "NONE/DATA")) |>
  ggplot(aes(x = strategy, y = estimate, ymin = conf.low, ymax = conf.high,
             color = signif)) +
  geom_hline(yintercept = 0, alpha = 0.4, linetype = "dashed") +
  geom_point() +
  geom_errorbar(width = 0.2) +
  scale_color_manual(name = "Significance:",
                     values = c("gray70", "steelblue", "firebrick")) +
  facet_grid(size ~ erasure, scales = "free_y") +
  labs(x = NULL, y = "Estimated difference (seconds)") +
  theme_bw()
