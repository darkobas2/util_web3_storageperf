library(tidyverse)


dat <-
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

dat |>
  mutate(strategy = ifelse(strategy != "RACE", "NONE/DATA", "RACE")) |>
  mutate(size = case_match(size_kb, 1~"1 KB", 10~"10 KB", 100~"100 KB", 1000~"1 MB",
                           10000~"10 MB", 100000~"100 MB", 500000~"500 MB")) |>
  mutate(size = as_factor(size)) |>
  # z-zcores per size category for download time:
  mutate(time = (time_sec - mean(time_sec)) / sd(time_sec), .by = size) |>
  # There are no NONE erasure-level data for 500 MB, so let's remove those:
  filter(size != "500 MB") |>
  ggplot(aes(x = erasure, y = time, color = strategy, fill = strategy)) +
  geom_boxplot(alpha = 0.3) +
  labs(color = "Strategy: ", fill = "Strategy: ", x = "Erasure level",
       y = "Download time z-score") +
  facet_grid(. ~ size, scales = "free_y", labeller = label_both) +
  scale_color_manual(values = c("steelblue", "goldenrod")) +
  scale_fill_manual(values = c("steelblue", "goldenrod")) +
  coord_cartesian(ylim = c(NA, 5.2)) +
  theme_bw() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 40, vjust = 0.75, hjust = 0.6))

dat |>
  mutate(strategy = ifelse(strategy != "RACE", "NONE/DATA", "RACE")) |>
  mutate(size = case_match(size_kb, 1~"1 KB", 10~"10 KB", 100~"100 KB", 1000~"1 MB",
                           10000~"10 MB", 100000~"100 MB", 500000~"500 MB")) |>
  mutate(size = as_factor(size)) |>
  # z-zcores per size category for download time:
  mutate(time = (time_sec - mean(time_sec)) / sd(time_sec), .by = size) |>
  summarize(
    m = mean(time),
    s = sd(time),
    n = n(),
    .by = c(size, size_kb, erasure, strategy)
  ) |>
  # There are no NONE erasure-level data for 500 MB, so let's remove those:
  filter(size != "500 MB") |>
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
dat |>
  filter(size_kb < 500000) |>
  mutate(strategy = ifelse(strategy != "RACE", "NONE/DATA", "RACE")) |>
  mutate(size = case_match(size_kb, 1~"1 KB", 10~"10 KB", 100~"100 KB",
                           1000~"1 MB", 10000~"10 MB", 100000~"100 MB")) |>
  mutate(size = fct_reorder(size, size_kb)) |>
  select(!size_kb) |>
  #(\(x) bind_rows(x, x |> filter(erasure == "NONE") |> mutate(strategy == "RACE")))() |>
  # z-zcores per size category for download time:
  mutate(time = (time_sec - mean(time_sec)) / sd(time_sec), .by = size) |>
  nest(data = !size) |>
  mutate(ANOVA_noint = map(data, \(x) lm(time ~ erasure + strategy, data = x))) |>
  mutate(ANOVA_int   = map(data, \(x) lm(time ~ erasure * strategy, data = x))) |>
  # Model selection: should the erasure:strategy interaction term be used?
  mutate(AIC_noint = map_dbl(ANOVA_noint, AIC), AIC_int = map_dbl(ANOVA_int, AIC)) |>
  mutate(AIC_diff = AIC_noint - AIC_int)

# Interaction terms are always favored except for 100 KB data, but there the delta AIC
# is less than 2. So we go ahead with interactions.
anovaDat <-
  dat |>
  filter(size_kb < 500000) |>
  mutate(strategy = ifelse(strategy != "RACE", "NONE/DATA", "RACE")) |>
  mutate(size = case_match(size_kb, 1~"1 KB", 10~"10 KB", 100~"100 KB",
                           1000~"1 MB", 10000~"10 MB", 100000~"100 MB")) |>
  mutate(size = fct_reorder(size, size_kb)) |>
  select(!size_kb) |>
  # z-zcores per size category for download time:
  mutate(time = (time_sec - mean(time_sec)) / sd(time_sec), .by = size) |>
  select(!time_sec) |>
  nest(data = !size) |>
  mutate(ANOVA = map(data, \(x) lm(time ~ erasure * strategy, data = x)))

# Model quality
anovaDat |>
  mutate(glance = map(ANOVA, broom::glance)) |>
  unnest(glance) |>
  select(!data & !ANOVA) |>
  rename(r2 = r.squared, adj_r2 = adj.r.squared)

# ANOVA tables
anovaDat |>
  mutate(tidy = map(ANOVA, compose(broom::tidy, anova))) |>
  unnest(tidy) |>
  # Divide by 6 to Bonferroni-correct the p-values for the 6 file sizes:
  mutate(signif = case_when(
    p.value <= 0.001 / 6 ~ "***",
    p.value <= 0.01 / 6  ~ "**",
    p.value <= 0.05 / 6  ~ "*",
    TRUE                 ~ "-"
  )) |>
  select(!data & !ANOVA) |>
  # For 1 KB, strategy doesn't matter and erasure:strategy might not.
  # For 100 KB, erasure:strategy doesn't matter.
  # Otherwise, all other adjusted p-values are very low.
  print(n = Inf)

# Regression coefficients
anovaDat |>
  mutate(tidy = map(ANOVA, broom::tidy)) |>
  unnest(tidy) |>
  # Divide by 6 to Bonferroni-correct the p-values for the 6 file sizes:
  mutate(signif = case_when(
    p.value <= 0.001 / 6 ~ "***",
    p.value <= 0.01 / 6  ~ "**",
    p.value <= 0.05 / 6  ~ "*",
    TRUE             ~ "-"
  )) |>
  select(!data & !ANOVA) |>
  # Remove intercept and terms which are always NA:
  filter(term != "(Intercept)" & term != "erasurePARANOID:strategyRACE") |>
  filter(signif != "-") |>
  arrange(size, estimate) |>
  print(n = Inf)

# Tukey post-hoc:
anovaDat |>
  mutate(tukey = map(ANOVA, compose(broom::tidy, TukeyHSD, aov))) |>
  unnest(tukey) |>
  mutate(signif = case_when(
    adj.p.value <= 0.001 / 6 ~ "***",
    adj.p.value <= 0.01 / 6  ~ "**",
    adj.p.value <= 0.05 / 6  ~ "*",
    TRUE             ~ "-"
  )) |>
  select(!data & !ANOVA & !null.value) |>
  filter(contrast == "STRONG:NONE/DATA-MEDIUM:NONE/DATA")



# Polynomial fits, to detect hump-shape
polyModel <-
  dat |>
  filter(size_kb < 500000) |>
  filter(strategy != "RACE") |> # Or DATA
  mutate(size = case_match(size_kb, 1~"1 KB", 10~"10 KB", 100~"100 KB",
                           1000~"1 MB", 10000~"10 MB", 100000~"100 MB")) |>
  mutate(size = fct_reorder(size, size_kb)) |>
  select(!size_kb) |>
  # z-zcores per size category for download time:
  mutate(time = (time_sec - mean(time_sec)) / sd(time_sec), .by = size) |>
  select(!time_sec) |>
  mutate(erasure_num = as.integer(erasure)) |>
  nest(data = !size) |>
  mutate(fit = map(data, \(x) lm(time ~ poly(erasure_num, degree = 3), data = x))) |>
  mutate(fittab = map(fit, broom::tidy), glance = map(fit, broom::glance))

polyModel |>
  unnest(fittab) |>
  filter(term == "poly(erasure_num, degree = 3)2") |>
  mutate(adj.p.value = p.adjust(p.value, "bonferroni"), .keep = "unused") |>
  select(!statistic) |>
  unnest(glance) |>
  select(size, estimate, std.error, adj.pval = adj.p.value, adj.r2 = adj.r.squared, AIC)

polyModel |>
  mutate(pred = map(fit, \(x) round(predict(x), 4))) |>
  unnest(c(data, pred)) |>
  summarize(
    mean = mean(time),
    lower = mean(time) - sd(time),
    upper = mean(time) + sd(time),
    .by = c(size, erasure, strategy, pred)
  ) |>
  ggplot(aes(x = erasure, y = mean, ymin = lower, ymax = upper, color = strategy)) +
  geom_line(aes(x = erasure, y = pred, group = size), color = "black", alpha = 0.5) +
  geom_point(size = 2, color = "steelblue",
             position = position_dodge(width = 0.6)) +
  geom_errorbar(width = 0.3, color = "steelblue",
                position = position_dodge(width = 0.6)) +
  labs(color = "Strategy: ", x = "Erasure level",
       y = "Download time z-score (mean +/- 1 std dev)") +
  facet_grid(. ~ size, scales = "free_y", labeller = label_both) +
  theme_bw() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 40, vjust = 1, hjust = 1))
