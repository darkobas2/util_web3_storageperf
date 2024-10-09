library(tidyverse)


dat <-
  jsonlite::fromJSON("../data/results-no50.json") |>
  tibble() |>
  rename(json = 1) |>
  mutate(storage = c("Swarm", "IPFS", "Arweave"), .before = 1) |>
  unnest(json) |>
  unnest(json) |>
  relocate(size, .after = storage) |>
  rename(time = download_time_seconds, size_kb = size) |>
  mutate(server = case_when(
    ip %in% c("download.gateway.ethswarm.org", "5.9.50.180:8080",
              "https://permagate.io") ~ "Server 1",
    ip %in% c("188.245.154.61:1633", "188.245.154.61:8080",
              "https://ar.perplex.finance") ~ "Server 2",
    ip %in% c("188.245.177.151:1633", "188.245.177.151:8080",
              "https://ar-io.dev") ~ "Server 3"
  )) |>
  mutate(size_kb = case_when(
    size_kb ==     "1" ~ "1 KB",
    size_kb ==    "10" ~ "10 KB",
    size_kb ==   "100" ~ "100 KB",
    size_kb ==  "1000" ~ "1 MB",
    size_kb == "10000" ~ "10 MB"
  )) |>
  mutate(size_kb = fct_relevel(size_kb, "1 KB", "10 KB", "100 KB", "1 MB", "10 MB"))


dat |>
  drop_na() |>
  select(storage, size_kb, server, time) |>
  mutate(storage = fct_reorder(storage, time)) |>
  ggplot(aes(x = time, color = storage, fill = storage)) +
  geom_density(alpha = 0.2) +
  scale_x_continuous() +
  labs(x = "Retrieval time (seconds)", y = "Density",
       color = "Platform", fill = "Platform") +
  scale_color_manual(values = c("steelblue", "goldenrod", "forestgreen")) +
  scale_fill_manual(values = c("steelblue", "goldenrod", "forestgreen")) +
  facet_grid(server ~ size_kb, scales = "fixed") +
  theme_bw()
