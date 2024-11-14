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


diagnose <- function(model, color = "steelblue", alpha = 0.3, shape = 1, ...) {
  autoplot(model, smooth.colour = NA, colour = color, alpha = alpha, shape = shape) +
    theme_bw()
}



dat0 <-
  bind_rows(
    prepareData("../data/results_onlyswarm_2024-11-06_19-08.json"),
    prepareData("../data/results_onlyswarm_2024-11-07_19-24.json")
  ) |>
  select(platform, size, server, erasure, strategy,
         time_sec, sha256_match, attempts)


dat0 |> count(sha256_match)
dat0 |> count(attempts)
dat0 |> filter(sha256_match) |> count(attempts)
dat0 |> count(size)
dat0 |> count(platform)
dat0 |> count(server)
dat0 |> count(platform, server, size, erasure, strategy) |> print(n = Inf)

dat <-
  dat0 |>
  filter(sha256_match) |>
  mutate(strategy = fct_relevel(strategy, "NONE", "DATA", "RACE")) |>
  arrange(server, erasure, strategy, size, time_sec)

dat |>
  mutate(erasure = case_match(erasure, 0 ~ "NONE", 1 ~ "MEDIUM", 3 ~ "INSANE")) |>
  mutate(erasure = fct_relevel(erasure, "NONE", "MEDIUM", "INSANE")) |>
  mutate(erasure = fct_relabel(erasure, \(x) str_c("Erasure level: ", x))) |>
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


jointModel <-
  dat |>
  mutate(logSize2 = log(size)^2, logTime = log(time_sec)) |>
  select(platform | server | erasure | strategy | logSize2 | logTime) |>
  lm(logTime ~ logSize2 + erasure + server + strategy + server:strategy +
       logSize2:erasure + logSize2:server + logSize2:strategy, data = _)

glance(jointModel)
diagnose(jointModel)
anova(jointModel)
summary(jointModel)

dat |>
  mutate(pred = exp(predict(jointModel))) |>
  mutate(erasure = case_match(erasure, 0 ~ "NONE", 1 ~ "MEDIUM", 3 ~ "INSANE")) |>
  mutate(erasure = fct_relevel(erasure, "NONE", "MEDIUM", "INSANE")) |>
  mutate(erasure = fct_relabel(erasure, \(x) str_c("Erasure level: ", x))) |>
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
