library(tidyverse)



dat <-
  read_rds("../data/swarm-2025-01/swarm.rds") |>
  filter(sha256_match) |>
  mutate(erasure = fct_relevel(erasure, "NONE", "MEDIUM", "STRONG",
                               "INSANE", "PARANOID")) |>
  mutate(strategy = fct_relevel(strategy, "NONE", "DATA", "RACE")) |>
  select(erasure, strategy, size_kb, server, time_sec) |>
  arrange(erasure, strategy, size_kb, server, time_sec)



# I clearly see it, for the same small and medium sizes standard deviations
# are halved or more reduced.
#
# Normalize differences from the mean by file size, subtract left numbers from right to
# get normalized standard deviations deltas as an effect of turning on the race strategy.
# Plot by left right for file size and y not log scale, four charts for the 4 levels.
#
# Or something like this.
# My hypothesis is that the lines will all be under the x axis for the first 3-4 sizes
# showing decrease of variance

dat_mv <-
  dat |>
  mutate(strategy = ifelse(strategy!="RACE", "Strategy: NONE/DATA", "Strategy: RACE")) |>
  mutate(size = case_match(size_kb, 1~"1 KB", 10~"10 KB", 100~"100 KB", 1000~"1 MB",
                           10000~"10 MB", 100000~"100 MB", 500000~"500 MB")) |>
  mutate(size = as_factor(size)) |>
  summarize(
    m = mean(time_sec),
    s = sd(time_sec),
    n = n(),
    .by = c(size, size_kb, erasure, strategy)
  )


dat_mv |>
  ggplot(aes(x = erasure, y = m, ymin = m - s, ymax = m + s, group = size)) +
  geom_line(alpha = 0.5, color = "steelblue") +
  geom_point(size = 2, color = "steelblue") +
  geom_errorbar(width = 0.2, color = "steelblue") +
  labs(color = "File size", x = "Erasure level",
       y = "Mean +/- 1 std dev download time (seconds)") +
  facet_grid(size ~ strategy, scales = "free_y") +
  theme_bw()

dat_mv |>
  ggplot(aes(x = size_kb, y = m, ymin = m - s, ymax = m + s, group = erasure)) +
  geom_line(alpha = 0.5, color = "steelblue") +
  geom_point(size = 2, color = "steelblue") +
  geom_errorbar(width = 0.2, color = "steelblue") +
  scale_x_log10() +
  scale_y_log10() +
  labs(x = "File size (KB)", color = "Erasure level",
       y = "Mean +/- 1 std dev download time (seconds)") +
  facet_grid(erasure ~ strategy, scales = "free_y") +
  theme_bw()
