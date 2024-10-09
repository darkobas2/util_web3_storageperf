library(tidyverse)


serversFromConfig <- function(configFile = "../config.json") {
  jsonlite::fromJSON(configFile) |>
    as_tibble() |>
    select(contains("dl")) |>
    mutate(server = str_c("Server ", 1:3), .before = 1) |>
    rename_with(\(x) str_remove(x, "_dl_servers"), !server) |>
    pivot_longer(!server, names_to = "storage", values_to = "ip") |>
    mutate(storage = case_match(
      storage,
      "swarm" ~ "Swarm",
      "ipfs"  ~ "IPFS",
      "arw"   ~ "Arweave"
    ))
}


dataFromJson <- function(jsonFile = "../data/results-no50.json") {
  jsonlite::fromJSON(jsonFile) |>
    tibble() |>
    rename(json = 1) |>
    mutate(storage = c("Swarm", "IPFS", "Arweave"), .before = 1) |>
    unnest(json) |>
    unnest(json) |>
    rename(time_sec = download_time_seconds) |>
    select(!server) |>
    left_join(serversFromConfig(), by = join_by(storage, ip)) |>
    mutate(size_kb = case_when(
      size ==     "1" ~ "1 KB",
      size ==    "10" ~ "10 KB",
      size ==   "100" ~ "100 KB",
      size ==  "1000" ~ "1 MB",
      size == "10000" ~ "10 MB"
    )) |>
    mutate(size_kb = fct_reorder(size_kb, as.integer(size))) |>
    select(!size) |>
    relocate(size_kb, server, time_sec, attempts, sha256_match, .after = storage)
}



dataFromJson() |>
  drop_na() |>
  select(storage | size_kb | server | time_sec) |>
  mutate(storage = fct_reorder(storage, time_sec)) |>
  ggplot(aes(x = time_sec, color = storage, fill = storage)) +
  geom_density(alpha = 0.2) +
  scale_x_continuous() +
  labs(x = "Retrieval time (seconds)", y = "Density",
       color = "Platform", fill = "Platform") +
  scale_color_manual(values = c("steelblue", "goldenrod", "forestgreen")) +
  scale_fill_manual(values = c("steelblue", "goldenrod", "forestgreen")) +
  facet_grid(server ~ size_kb, scales = "fixed") +
  theme_bw()
