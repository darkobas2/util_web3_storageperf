library(jsonlite)
library(tidyverse)


serversFromConfig <- function(configFile = "../data/config.json") {
  fromJSON(configFile) |>
    as_tibble() |>
    select(contains("dl")) |>
    mutate(server = str_c("Server ", 1:3), .before = 1) |>
    rename_with(\(x) str_remove(x, "_dl_servers"), !server) |>
    pivot_longer(!server, names_to = "platform", values_to = "ip") |>
    mutate(platform = case_match(
      platform,
      "swarm" ~ "Swarm",
      "ipfs"  ~ "IPFS",
      "arw"   ~ "Arweave"
    ))
}


dataFromJsonRaw <- function(jsonFile = "../data/results.json") {
  fromJSON(jsonFile) |>
    as_tibble() |>
    unnest(tests) |>
    unnest(results) |>
    rename(time_sec = download_time_seconds,
           replicate = ref,
           platform = storage)
}


dataFromJson <- function(rawTable) {
  rawTable |>
    mutate(sha256_match = (sha256_match == "true")) |>
    mutate(size_kb = as.integer(size)) |>
    select(!size & !server & !timestamp) |>
    mutate(platform = ifelse(platform == "Ipfs","IPFS",platform)) |>
    semi_join(serversFromConfig(), by = join_by(platform, ip)) |>
    left_join(serversFromConfig(), by = join_by(platform, ip)) |>
    relocate(size_kb, server, time_sec, attempts, sha256_match,
             .after = platform)
}



dat <- dataFromJsonRaw("../data/results.json") |> dataFromJson()

dat |> count(sha256_match)
dat |> count(size_kb)
dat |> count(platform)
dat |> count(server)

dat |>
  filter(sha256_match) |>
  select(platform | size_kb | server | time_sec) |>
  mutate(platform = fct_reorder(platform, time_sec)) |>
  mutate(size = case_when(
    size_kb ==     1 ~ "1 KB",
    size_kb ==    10 ~ "10 KB",
    size_kb ==   100 ~ "100 KB",
    size_kb ==  1000 ~ "1 MB",
    size_kb == 10000 ~ "10 MB"
  )) |>
  mutate(size = fct_reorder(size, size_kb)) |>
  ggplot(aes(x = time_sec, color = platform, fill = platform)) +
  geom_density(alpha = 0.2, bw = 0.05) +
  scale_x_log10() +
  labs(x = "Download time (seconds)", y = "Density",
       color = "Platform: ", fill = "Platform: ") +
  scale_color_manual(
    values = c("steelblue", "goldenrod", "forestgreen")
  ) +
  scale_fill_manual(
    values = c("steelblue", "goldenrod", "forestgreen")
  ) +
  facet_grid(server ~ size, scales = "fixed") +
  theme_bw() +
  theme(legend.position = "bottom", panel.grid = element_blank())
