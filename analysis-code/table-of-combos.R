library(tidyverse)
library(knitr)


swarmCombos <-
  crossing(
    platform = c("Swarm"),
    erasure_coding = as.character(0:4),
    retrieval_strategy = c("NONE", "DATA", "RACE"),
    server = 1:3
  ) |>
  mutate(replicates = 30) |>
  mutate(retrieval_strategy = case_when(
    platform == "Swarm" & erasure_coding == "0" ~ "NONE",
    platform != "Swarm"                         ~ NA,
    TRUE                                        ~ retrieval_strategy
  )) |>
  filter(erasure_coding == "0" | retrieval_strategy != "NONE") |>
  distinct()

arwIpfsCombos <-
  crossing(
    platform = c("IPFS", "Arweave"),
    erasure_coding = "",
    retrieval_strategy = "",
    server = 1:3
  ) |>
  mutate(replicates = 30)

bind_rows(arwIpfsCombos, swarmCombos) |>
  kable()
