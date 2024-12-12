library(jsonlite)
library(tidyverse)
library(ggfortify)
library(ggbeeswarm)
library(lme4)
library(broom.mixed)



cbPal <- function(k) { # Colorblind-friendly palette
  c("#0072B2", "#E69F00", "#009E73", "#CC79A7", "#999999", "#D55E00", "#56B4E9")[k]
}


diagnose <- function(model, color = cbPal(1), alpha = 0.3, shape = 1, ...) {
  autoplot(model, smooth.colour = NA, colour = color, alpha = alpha, shape = shape) +
    theme_bw()
}



dat <- read_rds("../data/compiled-data-new.rds")

dat |>
  ggplot(aes(x = as_factor(size), y = time_sec)) +
  geom_boxplot(alpha = 0.2, coef = Inf, color = cbPal(1), fill = cbPal(1)) +
  scale_x_discrete(labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  labs(x = "File size", y = "Download time (seconds)") +
  facet_grid(server ~ platform) +
  theme_bw()


# Swarm

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

dat |>
  filter(platform == "Swarm") |>
  mutate(strategy = as_factor(ifelse(strategy != "RACE", "NONE/DATA", "RACE"))) |>
  ggplot(aes(x = log(size)^2, y = log(time_sec), color = server)) +
  geom_quasirandom(alpha = 0.2) +
  geom_smooth(method = lm, se = FALSE) +
  scale_color_manual(values = cbPal(1:3)) +
  scale_fill_manual(values = cbPal(1:3)) +
  facet_grid(strategy ~ erasure) +
  theme_bw()

dat |>
  filter(platform == "Swarm") |>
  filter(server == "Server 3" & erasure == "NONE" & strategy == "NONE") |>
  ggplot(aes(x = log(size)^2, y = log(time_sec))) +
  geom_quasirandom(alpha = 0.2, color = cbPal(1)) +
  geom_smooth(method = lm) +
  theme_bw()

modelSwarm <-
  dat |>
  filter(platform == "Swarm") |>
  mutate(strategy = as_factor(ifelse(strategy != "RACE", "NONE/DATA", "RACE"))) |>
  mutate(erasure = case_match(
    erasure,
    "NONE"     ~ 0,
    "MEDIUM"   ~ 0.01,
    "STRONG"   ~ 0.05,
    "INSANE"   ~ 0.1,
    "PARANOID" ~ 0.5
  )) |>
  glmer(time_sec ~ I(log(size)^2) + erasure + strategy +
          I(log(size)^2):erasure + I(log(size)^2):strategy +
          erasure:strategy + (1 + erasure | server),
        data = _, family = gaussian(link = "log")) |>
  (\(x) { print(glance(x)); x; } )()

dat |>
  filter(platform == "Swarm") |>
  mutate(strategy = as_factor(ifelse(strategy != "RACE", "NONE/DATA", "RACE"))) |>
  mutate(pred = predict(modelSwarm, type = "response")) |>
  mutate(erasure = fct_relabel(erasure, \(x) str_c("Erasure level: ", x))) |>
  ggplot(aes(x = size, color = strategy, fill = strategy)) +
  geom_quasirandom(aes(y = time_sec), alpha = 0.5, shape = 1) +
  geom_line(aes(y = pred), linewidth = 1) +
  scale_x_log10(breaks = 10^(0:5),
                labels = c("1KB", "10KB", "100KB", "1MB", "10MB", "100MB")) +
  scale_y_log10() +
  scale_color_manual(values = cbPal(1:2)) +
  scale_fill_manual(values  = cbPal(1:2)) +
  labs(x = "File size", y = "Download time (seconds)",
       color = "Retrieval strategy", fill = "Retrieval strategy") +
  facet_grid(server ~ erasure) +
  theme_bw()

anova(modelSwarm)
summary(modelSwarm)


# IPFS

dat |>
  filter(platform == "IPFS") |>
  ggplot(aes(x = log(size)^3, y = log(time_sec), color = server)) +
  geom_quasirandom(alpha = 0.4) +
  geom_smooth(method = lm, se = FALSE) +
  scale_color_manual(values = cbPal(1:3)) +
  theme_bw()

modelIPFS <-
  dat |>
  filter(platform == "IPFS") |>
  glmer(time_sec ~ I(log(size)^3) + (1 + I(log(size)^3) | server),
        data = _, family = gaussian(link = "log")) |>
  (\(x) { print(glance(x)); x; } )()

dat |>
  filter(platform == "IPFS") |>
  mutate(pred = predict(modelIPFS, type = "response")) |>
  ggplot(aes(x = size, y = time_sec, color = server)) +
  geom_quasirandom(alpha = 0.4) +
  geom_line(aes(y = pred), linewidth = 1) +
  scale_color_manual(values = cbPal(1:3)) +
  scale_x_log10() +
  scale_y_log10() +
  theme_bw()

anova(modelIPFS)
summary(modelIPFS)


# Arweave

dat |>
  filter(platform == "Arweave") |>
  ggplot(aes(x = log(size)^3, y = log(time_sec), color = server)) +
  geom_quasirandom(alpha = 0.4) +
  geom_smooth(method = lm, se = FALSE) +
  scale_color_manual(values = cbPal(1:3)) +
  theme_bw()

modelArweave <-
  dat |>
  filter(platform == "Arweave") |>
  glmer(time_sec ~ I(log(size)^3) + (1 + I(log(size)^3) | server),
        data = _, family = gaussian(link = "log")) |>
  (\(x) { print(glance(x)); x; } )()

dat |>
  filter(platform == "Arweave") |>
  mutate(pred = predict(modelArweave, type = "response")) |>
  ggplot(aes(x = size, y = time_sec, color = server)) +
  geom_quasirandom(alpha = 0.4) +
  geom_line(aes(y = pred), linewidth = 1) +
  scale_color_manual(values = cbPal(1:3)) +
  scale_x_log10() +
  scale_y_log10() +
  theme_bw()

anova(modelIPFS)
summary(modelIPFS)


# Predictions from the models

dat |>
  mutate(strategy = as_factor(ifelse(strategy != "RACE", "NONE/DATA", "RACE"))) |>
  mutate(erasure = case_match(
    erasure,
    "NONE"     ~ 0,
    "MEDIUM"   ~ 0.01,
    "STRONG"   ~ 0.05,
    "INSANE"   ~ 0.1,
    "PARANOID" ~ 0.5
  )) |>
  distinct(platform, erasure, strategy) |>
  crossing(size = 10^seq(log10(1), log10(1e7), l = 201)) |>
  (\(x) mutate(x, pred = case_when(
    platform == "Arweave" ~ predict(modelArweave, x, re.form = NA, type = "response"),
    platform == "IPFS" ~ predict(modelIPFS, x, re.form = NA, type = "response"),
    platform == "Swarm" ~ predict(modelSwarm, x, re.form = NA, type = "response")
  )))() |>
  mutate(erasure = as_factor(erasure)) |>
  ggplot(aes(x = size, y = pred, color = erasure, linetype = strategy,
             group = str_c(platform, erasure, strategy))) +
  geom_line() +
  scale_x_log10() +
  scale_y_log10() +
  scale_color_viridis_d(option = "C", end = 0.8) +
  annotate(geom = "text", label = "Arweave", x = 2e6, y = 9) +
  annotate(geom = "text", label = "IPFS", x = 6e6, y = 700) +
  annotate(geom = "text", label = "Swarm", x = 1e5, y = 900) +
  labs(x = "File size (KB)", y = "Predicted download time (seconds)") +
  theme_bw()

# On a lin-lin scale:
dat |>
  mutate(strategy = as_factor(ifelse(strategy != "RACE", "NONE/DATA", "RACE"))) |>
  mutate(erasure = case_match(
    erasure,
    "NONE"     ~ 0,
    "MEDIUM"   ~ 0.01,
    "STRONG"   ~ 0.05,
    "INSANE"   ~ 0.1,
    "PARANOID" ~ 0.5
  )) |>
  distinct(platform, erasure, strategy) |>
  crossing(size = 10^seq(log10(1), log10(1e7), l = 201)) |>
  (\(x) mutate(x, pred = case_when(
    platform == "Arweave" ~ predict(modelArweave, x, re.form = NA, type = "response"),
    platform == "IPFS" ~ predict(modelIPFS, x, re.form = NA, type = "response"),
    platform == "Swarm" ~ predict(modelSwarm, x, re.form = NA, type = "response")
  )))() |>
  mutate(erasure = as_factor(erasure)) |>
  ggplot(aes(x = size, y = pred, color = erasure, linetype = strategy,
             group = str_c(platform, erasure, strategy))) +
  geom_line() +
  scale_color_viridis_d(option = "C", end = 0.8) +
  annotate(geom = "text", label = "Arweave", x = 9.5e6, y = 4000) +
  annotate(geom = "text", label = "IPFS", x = 8e6, y = 12000) +
  #annotate(geom = "text", label = "Swarm", x = 1e5, y = 900) +
  labs(x = "File size (KB)", y = "Predicted download time (seconds)") +
  theme_bw()
