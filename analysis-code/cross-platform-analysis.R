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
    mutate(erasure = case_match(erasure, 0 ~ "NONE", 1 ~ "MEDIUM", 2 ~ "STRONG",
                                3 ~ "INSANE", 4 ~ "PARANOID")) |>
    mutate(size = as.integer(size))
}


prepareData <- function(jsonFile) {
  dataFromJson(dataFromJsonRaw(jsonFile))
}



dat <- prepareData("../data/results_2024-11-11_14-19.json") |>
  select(platform, size, server, erasure, strategy,
         time_sec, sha256_match, attempts)

dat |> count(sha256_match)
dat |> count(attempts)
dat |> count(size)
dat |> count(platform)
dat |> count(server)
dat |> count(erasure)
dat |> count(strategy)
dat |> count(platform, server, size) |> print(n = Inf)


dat |>
  filter(sha256_match) |>
  ggplot(aes(x = as_factor(size), y = time_sec)) +
  geom_boxplot(alpha = 0.3, coef = Inf, color = "steelblue", fill = "steelblue") +
  scale_x_discrete(labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  labs(x = "File size", y = "Download time (seconds)") +
  facet_grid(server ~ platform) +
  theme_bw()

dat |>
  filter(sha256_match) |>
  ggplot(aes(x = size, y = time_sec)) +
  geom_point(alpha = 0.7, shape = 1, color = "steelblue",
             position = position_jitter(width = 0.2, height = 0)) +
  scale_x_log10(breaks = c(1, 10, 100, 1000, 10000, 100000),
                labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  labs(x = "File size", y = "Download time (seconds)") +
  facet_grid(server ~ platform) +
  theme_bw()


# Platform-specific models

platformModel <- function(data, formula, platf) {
  data |>
    filter(sha256_match) |>
    filter(platform == platf) |>
    select(size | server | time_sec) |>
    mutate(log_time = log(time_sec), log_size = log(size)) |>
    lm(formula = formula, data = _)
}

diagnose <- function(model, color = "steelblue", alpha = 0.3, ...) {
  autoplot(model, smooth.colour = NA, colour = color, alpha = alpha, ...) + theme_bw()
}

plotPlatformModel <- function(data, model, platf) {
  data |>
    filter(sha256_match) |>
    filter(platform == platf) |>
    mutate(pred = exp(predict(model))) |>
    ggplot(aes(x = size, y = time_sec)) +
    geom_point(alpha = 0.7, shape = 1, color = "steelblue",
               position = position_jitter(width = 0.1, height = 0, seed = 421)) +
    geom_line(aes(y = pred), linewidth = 1, color = "goldenrod") +
    scale_x_log10(breaks = c(1, 10, 100, 1000, 10000, 100000),
                  labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
    scale_y_log10() +
    labs(x = "File size", y = "Download time (seconds)") +
    facet_grid(. ~ server) +
    theme_bw()
}

analyzeModel <- function(data, platform, formula = log_time ~ I(log_size^2) + server) {
  model <- platformModel(data, formula, platform)
  show(diagnose(model))
  print(anova(model))
  print(summary(model))
  plotPlatformModel(data, model, platform)
}


analyzeModel(dat, "Arweave")
analyzeModel(dat, "IPFS")
analyzeModel(dat, "Swarm")
