library(tidyverse)
library(broom)
library(ggfortify)
library(jsonlite)



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


dataFromJsonRaw <- function(jsonFile = "../results.json") {
  jsonlite::fromJSON(jsonFile) |>
    as_tibble() |>
    unnest(tests) |>
    unnest(results)
}


dataFromJson <- function(jsonFile = "../results.json") {
  dataFromJsonRaw(jsonFile) |>
    mutate(sha256_match = (sha256_match == "true")) |>
    mutate(storage = ifelse(storage == "Ipfs", "IPFS", storage)) |>
    rename(time_sec = download_time_seconds) |>
    mutate(size_kb = as.integer(size)) |>
    select(!size & !server & !timestamp) |>
    left_join(serversFromConfig(), by = join_by(storage, ip)) |>
    relocate(size_kb, server, time_sec, attempts, sha256_match, .after = storage)
}



dat <- dataFromJson()

dat |>
  select(storage | size_kb | server | time_sec) |>
  mutate(storage = fct_reorder(storage, time_sec)) |>
  mutate(size = case_when(
    size_kb ==     1 ~ "1 KB",
    size_kb ==    10 ~ "10 KB",
    size_kb ==   100 ~ "100 KB",
    size_kb ==  1000 ~ "1 MB",
    size_kb == 10000 ~ "10 MB"
  )) |>
  mutate(size = fct_reorder(size, size_kb)) |>
  ggplot(aes(x = time_sec, color = storage, fill = storage)) +
  geom_density(alpha = 0.2, bw = 0.05) +
  scale_x_log10(breaks = c(10, 60, 360), labels = c("10s", "1m", "6m")) +
  labs(x = "Retrieval time", y = "Density", color = "Platform", fill = "Platform") +
  scale_color_manual(values = c("steelblue", "goldenrod", "forestgreen")) +
  scale_fill_manual(values = c("steelblue", "goldenrod", "forestgreen")) +
  facet_grid(server ~ size, scales = "fixed") +
  theme_bw()


dat |>
  ggplot(aes(x = size_kb, y = time_sec, group = size_kb)) +
  geom_point(color = "steelblue", alpha = 0.5) +
  geom_boxplot(color = "steelblue", fill = "steelblue", alpha = 0.2, outlier.shape=NA) +
  scale_x_log10() +
  facet_grid(server ~ storage) +
  theme_bw()

dat |>
  ggplot(aes(x = size_kb, y = time_sec)) +
  geom_point(color = "steelblue", alpha = 0.5) +
  geom_smooth(method = lm) +
  scale_x_log10() +
  labs(x = "File size (KB)", y = "Download time (seconds)") +
  facet_grid(server ~ storage) +
  theme_bw()

regressionDat <- dat |>
  mutate(size = log10(size_kb)) |>
  nest(data = !storage & !server) |>
  mutate(fit = map(data, \(dat) lm(time_sec ~ size, data = dat))) |>
  mutate(regtab = map(fit, broom::tidy)) |>
  unnest(regtab)

regressionDat |>
  filter(term != "(Intercept)") |>
  mutate(diagnostics = map(fit, \(x) {
    autoplot(x, smooth.colour = NA, alpha = 0.3, colour = "steelblue") + theme_bw()
  } )) |>
  mutate(diagnostics = pmap(list(diagnostics, storage, server), \(dia, sto, se) {
    gridExtra::grid.arrange(grobs = dia@plots, top = str_c(sto, ", ", se))
  } ))
