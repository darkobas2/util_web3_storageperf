library(jsonlite)
library(tidyverse)
library(broom)
library(ggfortify)
library(ggbeeswarm)
library(lme4)



cbPal <- function(k) { # Colorblind-friendly palette
  c("#0072B2", "#E69F00", "#009E73", "#CC79A7", "#56B4E9", "#999999", "#D55E00")[k]
}


diagnose <- function(model, color = cbPal(1), alpha = 0.3, shape = 1, ...) {
  autoplot(model, smooth.colour = NA, colour = color, alpha = alpha, shape = shape) +
    theme_bw()
}


plotModel <- function(data, model) {
  data |>
    mutate(pred = exp(predict(model))) |>
    ggplot(aes(x = size, y = time_sec)) +
    geom_quasirandom(alpha = 0.8, color = cbPal(1)) +
    geom_line(aes(y = pred), linewidth = 1, color = cbPal(2)) +
    scale_x_log10(breaks = c(1, 10, 100, 1000, 10000, 100000),
                  labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
    scale_y_log10() +
    labs(x = "File size", y = "Download time (seconds)") +
    facet_grid(. ~ server) +
    theme_bw()
}



dat <- read_rds("../data/compiled-data.rds")

dat |>
  ggplot(aes(x = as_factor(size), y = time_sec)) +
  geom_boxplot(alpha = 0.2, coef = Inf, color = cbPal(1), fill = cbPal(1)) +
  scale_x_discrete(labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  labs(x = "File size", y = "Download time (seconds)") +
  facet_grid(server ~ platform) +
  theme_bw()

dat |>
  filter(platform == "Swarm") |>
  mutate(strategy = as_factor(ifelse(strategy != "RACE", "NONE/DATA", "RACE"))) |>
  ggplot(aes(x = as_factor(size), y = time_sec, color = strategy, fill = strategy)) +
  geom_boxplot(alpha = 0.2, coef = Inf) +
  scale_x_discrete(labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  scale_color_manual(values = cbPal(1:2)) +
  scale_fill_manual(values = cbPal(1:2)) +
  labs(x = "File size", y = "Download time (seconds)") +
  facet_grid(server ~ erasure) +
  theme_bw() +
  theme(legend.position = "bottom")

dat |>
  filter(platform == "Swarm") |>
  mutate(strategy = as_factor(ifelse(strategy != "RACE", "NONE/DATA", "RACE"))) |>
  ggplot(aes(x = as_factor(size), y = time_sec, color = erasure, fill = erasure)) +
  geom_boxplot(alpha = 0.2, coef = Inf) +
  scale_x_discrete(labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  scale_color_manual(values = cbPal(1:5)) +
  scale_fill_manual(values = cbPal(1:5)) +
  labs(x = "File size", y = "Download time (seconds)") +
  facet_grid(server ~ strategy) +
  theme_bw() +
  theme(legend.position = "bottom")


modelSwarm <-
  dat |>
  filter(platform == "Swarm") |>
  mutate(strategy = as_factor(ifelse(strategy != "RACE", "NONE/DATA", "RACE"))) |>
  mutate(erasure = case_match(
    erasure,
    "NONE"     ~ 0,
    "MEDIUM"   ~ 9/128,
    "STRONG"   ~ 21/128,
    "INSANE"   ~ 31/128,
    "PARANOID" ~ 90/128
  )) |>
  mutate(logSize2 = log(size)^2, logTime = log(time_sec)) |>
  select(platform | server | erasure | strategy | logSize2 | logTime) |>
  lmer(logTime ~ logSize2 + erasure + strategy +
         logSize2:erasure + logSize2:strategy + erasure:strategy + (1|server), data = _)

glance(modelSwarm)
diagnose(modelSwarm)
anova(modelSwarm)
summary(modelSwarm)





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
