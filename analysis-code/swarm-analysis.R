library(tidyverse)



dat0 <-
  read_rds("../data/swarm-2025-01/swarm.rds") |>
  filter(sha256_match) |>
  mutate(erasure = fct_relevel(erasure, "NONE", "MEDIUM", "STRONG",
                               "INSANE", "PARANOID")) |>
  mutate(strategy = fct_relevel(strategy, "NONE", "DATA", "RACE")) |>
  select(erasure, strategy, size_kb, server, time_sec) |>
  arrange(erasure, strategy, size_kb, server, time_sec)

# I clearly see it, for the same small and medium sizes standard deviations
# are halved or more reduced.
#
# Normalize differences from the mean by file size, subtract left numbers from right to
# get normalized standard deviations deltas as an effect of turning on the race strategy.
# Plot by left right for file size and y not log scale, four charts for the 4 levels.
#
# Or something like this.
# My hypothesis is that the lines will all be under the x axis for the first 3-4 sizes
# showing decrease of variance

dat0 |>
  mutate(strategy = ifelse(strategy != "RACE", "NONE/DATA", "RACE")) |>
  mutate(size = case_match(size_kb, 1~"1 KB", 10~"10 KB", 100~"100 KB", 1000~"1 MB",
                           10000~"10 MB", 100000~"100 MB", 500000~"500 MB")) |>
  mutate(size = as_factor(size)) |>
  # There are no NONE erasure-level data for 500 MB, so let's remove those:
  filter(size != "500 MB") |>
  ggplot(aes(x = erasure, y = time_sec, color = strategy, fill = strategy)) +
  geom_boxplot(alpha = 0.3) +
  labs(color = "Strategy: ", fill = "Strategy: ", x = "Erasure level",
       y = "Download time (seconds)") +
  facet_wrap(~ size, scales = "free_y", nrow = 1, labeller = label_both) +
  scale_color_manual(values = c("steelblue", "goldenrod")) +
  scale_fill_manual(values = c("steelblue", "goldenrod")) +
  theme_bw() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 40, vjust = 0.75, hjust = 0.6))

datErasure <-
  dat0 |>
  # There are no NONE erasure-level data for 500 MB, so let's remove those:
  filter(size_kb < 500000) |>
  mutate(strategy = ifelse(strategy != "RACE", "NONE/DATA", "RACE")) |>
  mutate(size = case_match(size_kb, 1~"1 KB", 10~"10 KB", 100~"100 KB",
                           1000~"1 MB", 10000~"10 MB", 100000~"100 MB")) |>
  mutate(size = as_factor(size)) |>
  # z-zcores per size category for download time:
  mutate(time = (time_sec - mean(time_sec)) / sd(time_sec), .by = size) |>
  relocate(size, size_kb, strategy) |>
  arrange(size, strategy, erasure, server, time)

datErasure |>
  summarize(m = mean(time), s = sd(time), .by = c(size, erasure, strategy)) |>
  ggplot(aes(x = erasure, y = m, ymin = m - s, ymax = m + s, color = strategy)) +
  geom_line(aes(group = str_c(size, strategy)), alpha = 0.5) +
  geom_point(size = 2, position = position_dodge(width = 0.6)) +
  geom_errorbar(width = 0.3, position = position_dodge(width = 0.6)) +
  labs(color = "Strategy: ", x = "Erasure level",
       y = "Download time z-score (mean +/- 1 std dev)") +
  facet_grid(. ~ size, scales = "free_y", labeller = label_both) +
  scale_color_manual(values = c("steelblue", "goldenrod")) +
  theme_bw() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 40, vjust = 1, hjust = 1))



# Fit ANOVA for each size separately. Predictors: erasure level and retrieval strategy.
# Fit twice: with- and without the erasure:strategy interaction term. Note: there are
# no NONE erasure-level data for 500 MB, so let's remove those.
datErasure |>
  nest(data = !size) |>
  mutate(ANOVA_noint = map(data, \(x) lm(time ~ erasure + strategy, data = x))) |>
  mutate(ANOVA_int   = map(data, \(x) lm(time ~ erasure * strategy, data = x))) |>
  # Model selection: should the erasure:strategy interaction term be used?
  mutate(AIC_noint = map_dbl(ANOVA_noint, AIC), AIC_int = map_dbl(ANOVA_int, AIC)) |>
  mutate(AIC_diff = AIC_noint - AIC_int)

# Interaction terms are always favored except for 100 KB data, but there the delta AIC
# is less than 2. So we go ahead with interactions.

# Model quality
datErasure |>
  nest(data = !size) |>
  mutate(ANOVA = map(data, \(x) lm(time ~ erasure * strategy, data = x))) |>
  mutate(glance = map(ANOVA, broom::glance)) |>
  unnest(glance) |>
  select(!data & !ANOVA & !df.residual & !nobs & !statistic)

# ANOVA tables
datErasure |>
  nest(data = !size) |>
  mutate(ANOVA = map(data, \(x) lm(time ~ erasure * strategy, data = x))) |>
  mutate(tidy = map(ANOVA, compose(broom::tidy, anova))) |>
  unnest(tidy) |>
  # Correct p-values for multiple comparison from the 6 file sizes:
  mutate(adj.p.value = p.adjust(p.value, method = "bonferroni"), .by = size) |>
  mutate(signif = case_when(
    adj.p.value <= 0.001 ~ "***",
    adj.p.value <= 0.01  ~ "**",
    adj.p.value <= 0.05  ~ "*",
    TRUE                 ~ "-"
  )) |>
  select(!data & !ANOVA) |>
  # For 1 KB, strategy doesn't matter and erasure:strategy might not.
  # For 100 KB, erasure:strategy doesn't matter.
  # Otherwise, all other adjusted p-values are very low.
  filter(term != "Residuals") |>
  print(n = Inf)

# Regression coefficients
datErasure |>
  nest(data = !size) |>
  mutate(ANOVA = map(data, \(x) lm(time ~ erasure * strategy, data = x))) |>
  mutate(tidy = map(ANOVA, broom::tidy)) |>
  unnest(tidy) |>
  # Correct p-values for multiple comparison from the 6 file sizes:
  mutate(adj.p.value = p.adjust(p.value, method = "bonferroni"), .by = size) |>
  mutate(signif = case_when(
    adj.p.value <= 0.001 ~ "***",
    adj.p.value <= 0.01  ~ "**",
    adj.p.value <= 0.05  ~ "*",
    TRUE                 ~ "-"
  )) |>
  select(!data & !ANOVA) |>
  # Remove intercepts and non-significant terms:
  filter(term != "(Intercept)") |>
  filter(signif != "-") |>
  arrange(size, estimate) |>
  print(n = Inf)

# Tukey post-hoc:
datErasure |>
  nest(data = !size) |>
  mutate(ANOVA = map(data, \(x) lm(time ~ erasure * strategy, data = x))) |>
  mutate(tukey = map(ANOVA, compose(broom::tidy, TukeyHSD, aov))) |>
  unnest(tukey) |>
  mutate(adj.p.value = p.adjust(adj.p.value, method = "bonferroni"), .by = size) |>
  mutate(signif = case_when(
    adj.p.value <= 0.001 ~ "***",
    adj.p.value <= 0.01  ~ "**",
    adj.p.value <= 0.05  ~ "*",
    TRUE                 ~ "-"
  )) |>
  select(!data & !ANOVA & !null.value) |>
  filter(term == "strategy")
