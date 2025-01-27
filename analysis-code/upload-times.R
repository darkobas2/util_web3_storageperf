library(jsonlite)
library(tidyverse)



dataFromJsonRaw <- function(jsonFile) {
  fromJSON(jsonFile) |>
    (`[`)(1) |>
    as_tibble() |>
    unnest(swarm) |>
    rename(erasure = ul_redundancy, time = upload_time)
}


fileSizeFromJsonRaw <- function(jsonFile) {
  fromJSON(jsonFile) |>
    (`[`)(1) |>
    (`[[`)(1) |>
    names() |>
    as.integer()
}



dat <-
  tibble(file = Sys.glob("../references/swarm-run-2024-dec/*.json")) |>
  mutate(size_kb = map_int(file, fileSizeFromJsonRaw)) |>
  mutate(data = map(file, dataFromJsonRaw)) |>
  unnest(data) |>
  select(erasure, size_kb, time) |>
  arrange(erasure, size_kb, time) |>
  mutate(erasure = case_match(
    erasure,
    0 ~ "NONE",
    1 ~ "MEDIUM",
    2 ~ "STRONG",
    3 ~ "INSANE",
    4 ~ "PARANOID"
  ))


dat |>
  mutate(erasure = as_factor(erasure)) |>
  ggplot(aes(x = as_factor(size_kb), y = time, color = erasure, fill = erasure)) +
  geom_boxplot(alpha = 0.3, coef = Inf) +
  scale_x_discrete(labels = c("1 KB", "10 KB", "100 KB", "1 MB", "10 MB", "100 MB")) +
  scale_y_log10(breaks = 10^(-1:3), labels = c(0.1, 1, 10, 100, 1000)) +
  scale_color_viridis_d(option = "B", end = 0.85) +
  scale_fill_viridis_d(option = "B", end = 0.85) +
  labs(x = "File size", y = "Upload time (seconds)",
       color = "Erasure coding", fill = "Erasure coding") +
  theme_bw()
