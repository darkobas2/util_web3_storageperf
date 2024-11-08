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

dat <-
  bind_rows(
    prepareData("../data/results_onlyswarm_2024-11-06_19-08.json"),
    prepareData("../data/results_onlyswarm_2024-11-07_19-24.json")
  ) |>
  select(platform, size, server, erasure, strategy,
         time_sec, sha256_match, attempts)


dat |> count(sha256_match)
dat |> count(attempts)
dat |> count(size)
dat |> count(platform)
dat |> count(server)
dat |> count(platform, server, size, erasure, strategy) |> print(n = Inf)


dat |>
  filter(sha256_match) |>
  mutate(erasure = fct_relevel(erasure, "NONE", "MEDIUM", "INSANE")) |>
  mutate(erasure = fct_relabel(erasure, \(x) str_c("Erasure level: ", x))) |>
  mutate(strategy = fct_relevel(strategy, "NONE", "DATA", "RACE")) |>
  ggplot(aes(x = as_factor(size), y = time_sec, color = strategy, fill = strategy)) +
  geom_boxplot(alpha = 0.3, coef = Inf) +
  scale_x_discrete(labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  scale_color_manual(values = c(NONE = "steelblue",
                                DATA = "goldenrod",
                                RACE = "forestgreen")) +
  scale_fill_manual(values  = c(NONE = "steelblue",
                                DATA = "goldenrod",
                                RACE = "forestgreen")) +
  labs(x = "File size", y = "Download time (seconds)",
       color = "Retrieval strategy", fill = "Retrieval strategy") +
  facet_grid(server ~ erasure) +
  theme_bw()


jointModel <- dat |>
  filter(sha256_match) |>
  mutate(erasure_strategy = str_c(erasure, strategy, sep = "_")) |>
  mutate(erasure_strategy = fct_relevel(erasure_strategy, "NONE_NONE", "MEDIUM_DATA",
                                        "MEDIUM_RACE", "INSANE_DATA", "INSANE_RACE")) |>
  mutate(log_size = log(size), log_time = log(time_sec)) |>
  select(server | erasure_strategy | log_size | log_time) |>
  lm(log_time ~ I(log_size^2) + server + erasure_strategy, data = _)

jointModel |>
  autoplot(smooth.colour = NA, colour = "steelblue", alpha = 0.3, shape = 1) +
  theme_bw()

anova(jointModel)
summary(jointModel)

tibble(residuals = residuals(jointModel)) |>
  ggplot(aes(x = residuals)) +
  geom_histogram(color = "steelblue", fill = "steelblue", alpha = 0.2, bins = 30) +
  theme_bw()

dat |>
  filter(sha256_match) |>
  mutate(erasure_strategy = str_c(erasure, strategy, sep = "_")) |>
  mutate(pred = predict(jointModel)) |>
  ggplot(aes(x = log(time_sec), y = pred,
             color = erasure_strategy, size = log10(size))) +
  geom_abline(alpha = 0.5, linetype = "dashed") +
  geom_point(alpha = 0.75, shape = 1) +
  theme_bw()

dat |>
  filter(sha256_match) |>
  mutate(pred = exp(predict(jointModel))) |>
  mutate(erasure = fct_relevel(erasure, "NONE", "MEDIUM", "INSANE")) |>
  mutate(erasure = fct_relabel(erasure, \(x) str_c("Erasure level: ", x))) |>
  mutate(strategy = fct_relevel(strategy, "NONE", "DATA", "RACE")) |>
  ggplot(aes(x = size, color = strategy, fill = strategy)) +
  geom_point(aes(y = time_sec), alpha = 0.5, shape = 1,
             position = position_jitterdodge(jitter.width = 0.5)) +
  geom_line(aes(y = pred), linewidth = 1) +
  scale_x_log10(breaks = 10^(0:5),
                labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  scale_color_manual(values = c(NONE = "steelblue",
                                DATA = "goldenrod",
                                RACE = "forestgreen")) +
  scale_fill_manual(values  = c(NONE = "steelblue",
                                DATA = "goldenrod",
                                RACE = "forestgreen")) +
  labs(x = "File size", y = "Download time (seconds)",
       color = "Retrieval strategy", fill = "Retrieval strategy") +
  facet_grid(server ~ erasure) +
  theme_bw()

