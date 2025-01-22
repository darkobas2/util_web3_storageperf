library(jsonlite)
library(tidyverse)


dataFromJsonRaw <- function(jsonFile) {
  fromJSON(jsonFile) |>
    (`[`)(1) |>
    as_tibble() |>
    unnest(swarm) |>
    rename(erasure = ul_redundancy) |>
    mutate(erasure = case_match(
      erasure,
      0 ~ "NONE",
      1 ~ "MEDIUM",
      2 ~ "STRONG",
      3 ~ "INSANE",
      4 ~ "PARANOID",
      NA ~ "NONE"))
}


tibble(file = Sys.glob("../references/references_onlyswarm_*_3_2024-12-*.json")) |>
  mutate(data = map(file, dataFromJsonRaw)) |>
  unnest(data)
