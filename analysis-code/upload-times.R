library(jsonlite)
library(tidyverse)
library(broom)
library(ggbeeswarm)



dataFromJsonRaw <- function(jsonFile) {
  fromJSON(jsonFile) |>
    (`[`)(1) |>
    as_tibble() |>
    unnest(swarm) |>
    rename(erasure = ul_redundancy, time_sec = upload_time)
}


fileSizeFromJsonRaw <- function(jsonFile) {
  fromJSON(jsonFile) |>
    (`[`)(1) |>
    (`[[`)(1) |>
    names() |>
    as.integer()
}



dat <-
  tibble(file = Sys.glob("../data/swarm-2025-01/references/*.json")) |>
  mutate(size_kb = map_int(file, fileSizeFromJsonRaw)) |>
  mutate(data = map(file, dataFromJsonRaw)) |>
  unnest(data) |>
  select(erasure, size_kb, time_sec) |>
  arrange(erasure, size_kb, time_sec) |>
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
  ggplot(aes(x = as_factor(size_kb), y = time_sec, color = erasure, fill = erasure)) +
  geom_boxplot(alpha = 0.3, coef = Inf) +
  scale_x_discrete(labels = c("1 KB", "10 KB", "100 KB", "1 MB", "10 MB", "100 MB")) +
  scale_y_log10(breaks = 10^(-1:3), labels = c(0.1, 1, 10, 100, 1000)) +
  scale_color_viridis_d(option = "B", end = 0.85) +
  scale_fill_viridis_d(option = "B", end = 0.85) +
  labs(x = "File size", y = "Upload time (seconds)",
       color = "Erasure coding", fill = "Erasure coding") +
  theme_bw()


uploadModel <-
  dat |>
  mutate(erasure = as_factor(erasure)) |>
  glm(time_sec ~ I(log(size_kb)^2) + erasure,
      data = _, family = gaussian(link = "log")) |>
  (\(x) { print(glance(x)); x; } )()


dat |>
  mutate(time_predict = predict(uploadModel, type = "response")) |>
  mutate(erasure = as_factor(str_c("Erasure: ", erasure))) |>
  ggplot(aes(x = size_kb)) +
  geom_quasirandom(aes(y = time_sec), shape = 1, color = "steelblue") +
  geom_line(aes(y = time_predict), color = "black", alpha = 0.8) +
  scale_x_log10(breaks = 10^(0:5),
                labels = c("1 KB", "10 KB", "100 KB", "1 MB", "10 MB", "100 MB")) +
  scale_y_log10(breaks = 10^(-1:2), labels = c(0.1, 1, 10, 100)) +
  labs(x = "File size", y = "Upload time (seconds)",
       color = "Erasure coding", fill = "Erasure coding") +
  facet_grid(. ~ erasure) +
  theme_bw()
