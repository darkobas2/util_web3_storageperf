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
    relocate(size_kb, server = ip, time_sec, attempts, sha256_match,
             .after = platform) |>
    relocate(timeout = `dl_retrieval-timeout`,
             strategy = dl_redundancy,
             erasure = ul_redundancy, .after = time_sec)
}



dat <- dataFromJsonRaw("../data/results_onlyswarm.json") |> dataFromJson()

dat |> count(sha256_match)
dat |> count(size_kb)
dat |> count(platform)
dat |> count(server)
dat |> count(strategy)
dat |> count(timeout)
dat |> count(erasure)
dat |> count(size_kb, erasure, strategy, timeout)

dat |>
  ggplot(aes(x = time_sec)) +
  geom_density(color = "steelblue", fill = "steelblue", alpha = 0.2) +
  facet_grid(erasure ~ strategy, labeller = label_both) +
  scale_x_log10() +
  theme_bw() +
  theme(panel.grid = element_blank())
