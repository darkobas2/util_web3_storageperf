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


fitModel <- function(data, formula = log_time ~ I(log_size^2) + server) {
  data |>
    mutate(log_time = log(time_sec), log_size = log(size)) |>
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
    scale_y_log10(limits = c(0.08, 180)) +
    labs(x = "File size", y = "Download time (seconds)") +
    facet_grid(. ~ server) +
    theme_bw()
}


fitPlotModel <- function(data, formula = log_time ~ I(log_size^2) + server) {
  fitModel(data) |> plotModel(data = data) + ggtitle(data$set[1])
}


analyzeModel <- function(data, formula = log_time ~ I(log_size^2) + server) {
  model <- fitModel(data, formula)
  show(diagnose(model))
  print(anova(model))
  print(summary(model))
  plotModel(data, model)
}


compareSims <- function(method) {
  dat |>
    mutate(log_time = log(time_sec)) |>
    select(!time_sec) |>
    nest(data = set | log_time) |>
    mutate(test = map(data, \(x) method(log_time ~ set, data = x))) |>
    mutate(test = map(test, tidy)) |>
    unnest(test) |>
    select(size | server | p.value) |>
    arrange(p.value)
}



dat1 <-
  bind_rows(
    prepareData("../data/results_onlyswarm_2024-11-06_19-08.json"),
    prepareData("../data/results_onlyswarm_2024-11-07_19-24.json")
  ) |>
  filter(erasure == "NONE" & strategy == "NONE") |>
  filter(sha256_match) |>
  mutate(set = "Nov 6-7", .before = 1) |>
  select(set, size, server, time_sec)

dat2 <-
  prepareData("../data/results_2024-11-11_14-19.json") |>
  filter(platform == "Swarm") |>
  filter(sha256_match) |>
  mutate(set = "Nov 11", .before = 1) |>
  select(set, size, server, time_sec)

dat <-
  bind_rows(dat1, dat2) |>
  mutate(set = as_factor(set)) |>
  arrange(set, size, server)

dat |>
  mutate(set = fct_relevel(set, "Nov 6-7", "Nov 11")) |>
  ggplot(aes(x = as_factor(size), y = time_sec, color = set, fill = set)) +
  geom_boxplot(alpha = 0.2) +
  scale_x_discrete(labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  scale_color_manual(values = c("steelblue", "goldenrod")) +
  scale_fill_manual(values = c("steelblue", "goldenrod")) +
  labs(x = "File size", y = "Download time (seconds)", color = NULL, fill = NULL) +
  facet_grid(. ~ server) +
  theme_bw() +
  theme(legend.position = "bottom")

dat |>
  mutate(set = fct_relevel(set, "Nov 6-7", "Nov 11")) |>
  ggplot(aes(x = size, y = time_sec, color = set)) +
  geom_quasirandom(alpha = 0.5) +
  scale_x_log10(breaks = c(1, 10, 100, 1000, 10000, 100000),
                labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  scale_color_manual(values = c("steelblue", "goldenrod")) +
  labs(x = "File size", y = "Download time (seconds)", color = NULL) +
  facet_grid(. ~ server) +
  theme_bw() +
  theme(legend.position = "bottom")


compareSims(t.test) |> mutate(test = "t") |>
  bind_rows(compareSims(wilcox.test) |> mutate(test = "wilcox")) |>
  pivot_wider(names_from = test, values_from = p.value, names_prefix = "pvalue.") |>
  arrange(server, size) |>
  mutate(across(starts_with("pvalue"), \(x) case_when(
    x < 0.001 ~ "***",
    x < 0.01 ~ "**",
    x < 0.05 ~ "*",
    TRUE ~ "-"
  )))


dat |> filter(set == "Nov 6-7") |> fitModel() |> diagnose()
dat |> filter(set == "Nov 11")  |> fitModel() |> diagnose()
dat |> fitModel() |> diagnose()

dat |> filter(set == "Nov 6-7") |> fitPlotModel()
dat |> filter(set == "Nov 11")  |> fitPlotModel()
dat |> fitPlotModel()

dat |>
  filter(set == "Nov 6-7") |> # Or "Nov 11"
  fitModel() |>
  summary() |>
  tidy()
