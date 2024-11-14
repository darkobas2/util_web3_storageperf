library(jsonlite)
library(tidyverse)
library(broom)
library(ggfortify)



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


dataFromJsonRaw <- function(jsonFile) {
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
    select(!size_kb & !server & !timestamp) |>
    mutate(platform = ifelse(platform == "Ipfs", "IPFS", platform)) |>
    semi_join(serversFromConfig(), by = join_by(platform, ip)) |>
    left_join(serversFromConfig(), by = join_by(platform, ip)) |>
    relocate(size, server, time_sec, attempts, sha256_match, .after = platform) |>
    relocate(timeout = `dl_retrieval-timeout`,
             strategy = dl_redundancy,
             erasure = ul_redundancy, .after = time_sec) |>
    mutate(strategy = case_match(strategy, 0 ~ "NONE", 1 ~ "DATA", 3 ~ "RACE")) |>
    mutate(size = as.integer(size))
}


prepareData <- function(jsonFile) {
  dataFromJson(dataFromJsonRaw(jsonFile))
}



datSwarm <-
  bind_rows(
    prepareData("../data/results_onlyswarm_2024-11-06_19-08.json"),
    prepareData("../data/results_onlyswarm_2024-11-07_19-24.json")
  ) |>
  filter(sha256_match) |>
  select(platform | size | server | erasure | strategy | time_sec) |>
  mutate(strategy = fct_relevel(strategy, "NONE", "DATA", "RACE"))

datIPFSArw <-
  prepareData("../data/results_2024-11-11_14-19.json") |>
  filter(sha256_match & platform != "Swarm") |>
  mutate(erasure = 0L) |>
  mutate(strategy = as_factor(strategy)) |>
  select(platform | size | server | erasure | strategy | time_sec)

swarmModel <-
  datSwarm |>
  mutate(logSize2 = log(size)^2, logTime = log(time_sec)) |>
  select(server | erasure | strategy | logSize2 | logTime) |>
  lm(logTime ~ logSize2 + erasure + server + strategy +
       logSize2:erasure + logSize2:server + logSize2:strategy +
       erasure:server + server:strategy,
     data = _)

arwModel <-
  datIPFSArw |>
  filter(platform == "Arweave") |>
  mutate(logTime = log(time_sec), logSize2 = log(size)^2) |>
  lm(logTime ~ logSize2 * server, data = _)

ipfsModel <-
  datIPFSArw |>
  filter(platform == "IPFS") |>
  mutate(logTime = log(time_sec), logSize2 = log(size)^2) |>
  lm(logTime ~ logSize2 * server, data = _)

bind_rows(datSwarm, datIPFSArw) |>
  distinct(platform, server, erasure, strategy) |>
  crossing(logSize2 = log(10^seq(log10(1), log10(1e7), l = 201))^2) |>
  (\(x) mutate(x, pred = case_when(
    platform == "Arweave" ~ predict(arwModel, x),
    platform == "IPFS" ~ predict(ipfsModel, x),
    platform == "Swarm" ~ predict(swarmModel, x)
  )))() |>
  mutate(size = exp(sqrt(logSize2)), pred = exp(pred)) |>
  #filter(size == max(size)) |>
  #summarize(pred = mean(pred), .by = c(platform, erasure, strategy))
  ggplot(aes(x = size, y = pred, linetype = as_factor(erasure), color = strategy)) +
  geom_line() +
  scale_x_log10() +
  scale_y_log10() +
  facet_grid(server ~ platform) +
  theme_bw()
