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
    mutate(erasure = case_match(erasure, 0 ~ "NONE", 1 ~ "MEDIUM", 2 ~ "STRONG",
                                3 ~ "INSANE", 4 ~ "PARANOID", NA ~ "NONE")) |>
    mutate(size = as.integer(size))
}


prepareData <- function(jsonFile) {
  dataFromJson(dataFromJsonRaw(jsonFile))
}


dat0 <-
  tibble(file = Sys.glob("../data/first-full-run-2024-Nov/results_2024*.json")) |>
  mutate(data = map(file, prepareData)) |>
  unnest(data) |>
  filter(platform != "Swarm") |>
  select(!file) |>
  bind_rows(prepareData("../data/swarm-run-2024-Dec/results_onlyswarm.json")) |>
  select(platform, size, server, erasure, strategy,
         time_sec, sha256_match, attempts, latitude, longitude)

dat0 |> count(sha256_match)
dat0 |> count(attempts)
dat0 |> filter(sha256_match) |> count(attempts)
dat0 |> count(size)
dat0 |> count(platform)
dat0 |> count(server)
dat0 |> count(erasure)
dat0 |> count(strategy)
dat0 |> count(platform, server, size, erasure, strategy) |> print(n = Inf)
dat0 |> filter(erasure != "NONE" & strategy == "NONE")
dat0 |> distinct(latitude, longitude)

dat <-
  dat0 |>
  filter(sha256_match) |>
  select(platform, server, size, erasure, strategy, time_sec) |>
  mutate(erasure = fct_relevel(erasure, "NONE", "MEDIUM", "STRONG",
                               "INSANE", "PARANOID")) |>
  mutate(strategy = fct_relevel(strategy, "NONE", "DATA", "RACE")) |>
  arrange(platform, server, size, erasure, strategy, time_sec)

dat |> count(platform, server, size, erasure, strategy) |> print(n = Inf)

write_rds(dat, "../data/compiled-data-new.rds", compress = "xz")
