library(tidyverse)
library(knitr)


swarmCombos <-
  crossing(
    platform = c("Swarm"),
    `erasure coding` = as.character(0:4),
    `retrieval strategy` = c("NONE", "DATA", "RACE"),
    `file size (KB)` = c("1", "10", "100", "1 000", "10 000", "100 000"),
    server = 1:3
  ) |>
  mutate(replicates = 30) |>
  mutate(`retrieval strategy` = case_when(
    platform == "Swarm" & `erasure coding` == "0" ~ "NONE",
    platform != "Swarm"                         ~ NA,
    TRUE                                        ~ `retrieval strategy`
  )) |>
  filter(`erasure coding` == "0" | `retrieval strategy` != "NONE") |>
  distinct()

arwIpfsCombos <-
  crossing(
    platform = c("IPFS", "Arweave"),
    `erasure coding` = "",
    `retrieval strategy` = "",
    `file size (KB)` = c("1", "10", "100", "1 000", "10 000", "100 000"),
    server = 1:3
  ) |>
  mutate(replicates = 30)

bind_rows(arwIpfsCombos, swarmCombos) |>
  kable(align = "lrrrrr")
