library(jsonlite)
library(tidyverse)
library(broom)
library(ggfortify)
library(ggbeeswarm)



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
                                3 ~ "INSANE", 4 ~ "PARANOID")) |>
    mutate(size = as.integer(size))
}


prepareData <- function(jsonFile) {
  dataFromJson(dataFromJsonRaw(jsonFile))
}


# Platform-specific models

fitModel <- function(data, formula = logTime ~ logSize2 * server) {
  data |>
    mutate(logTime = log(time_sec), logSize2 = log(size)^2) |>
    lm(formula = formula, data = _)
}


diagnose <- function(model, color = "steelblue", alpha = 0.3, shape = 1, ...) {
  autoplot(model, smooth.colour = NA, colour = color, alpha = alpha, shape = shape) +
    theme_bw()
}


plotModel <- function(data, model) {
  data |>
    mutate(pred = exp(predict(model))) |>
    ggplot(aes(x = size, y = time_sec)) +
    geom_quasirandom(alpha = 0.8, color = "steelblue") +
    geom_line(aes(y = pred), linewidth = 1, color = "goldenrod") +
    scale_x_log10(breaks = c(1, 10, 100, 1000, 10000, 100000),
                  labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
    scale_y_log10() +
    labs(x = "File size", y = "Download time (seconds)") +
    facet_grid(. ~ server) +
    theme_bw()
}


fitPlotModel <- function(data, formula = logTime ~ logSize2 * server) {
  plotModel(fitModel(data), data = data)
}



dat0 <-
  prepareData("../data/results_2024-11-11_14-19.json") |>
  select(platform, size, server, erasure, strategy,
         time_sec, sha256_match, attempts)

dat0 |> count(sha256_match)
dat0 |> count(attempts)
dat0 |> filter(sha256_match) |> count(attempts)
dat0 |> count(size)
dat0 |> count(platform)
dat0 |> count(server)
dat0 |> count(erasure)
dat0 |> count(strategy)
dat0 |> count(platform, server, size) |> print(n = Inf)

dat <-
  dat0 |>
  filter(sha256_match & platform != "Swarm") |>
  select(platform, server, size, time_sec) |>
  arrange(platform, server, size, time_sec)

dat |>
  ggplot(aes(x = as_factor(size), y = time_sec)) +
  geom_boxplot(alpha = 0.3, coef = Inf, color = "steelblue", fill = "steelblue") +
  scale_x_discrete(labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  labs(x = "File size", y = "Download time (seconds)") +
  facet_grid(server ~ platform) +
  theme_bw()

dat |>
  ggplot(aes(x = size, y = time_sec)) +
  geom_quasirandom(alpha = 0.6, color = "steelblue") +
  scale_x_log10(breaks = c(1, 10, 100, 1000, 10000, 100000),
                labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  labs(x = "File size", y = "Download time (seconds)") +
  facet_grid(server ~ platform) +
  theme_bw()


dat |> filter(platform == "Arweave") |> fitModel() |> diagnose()
dat |> filter(platform == "IPFS") |> fitModel() |> diagnose()

dat |> filter(platform == "Arweave") |> fitPlotModel()
dat |> filter(platform == "IPFS") |> fitPlotModel()

dat |> filter(platform == "Arweave") |> fitModel() |> summary() |> tidy()
dat |> filter(platform == "IPFS") |> fitModel() |> summary() |> tidy()

arwModel <- dat |> filter(platform == "Arweave") |> fitModel()
ipfsModel <- dat |> filter(platform == "IPFS") |> fitModel()
dat |>
  distinct(platform, server) |>
  crossing(logSize2 = log(10^seq(log10(1), log10(1e6), l = 201))^2) |>
  (\(x) mutate(x, pred = ifelse(
    platform == "IPFS",
    predict(ipfsModel, x),
    predict(arwModel, x)
  )))() |>
  mutate(size = exp(sqrt(logSize2)), pred = exp(pred)) |>
  ggplot(aes(x = size, y = pred)) +
  geom_line(color = "steelblue") +
  scale_x_log10() +
  scale_y_log10() +
  facet_grid(server ~ platform) +
  theme_bw()
