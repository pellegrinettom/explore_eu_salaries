#-------------------------------------------------------------------------------
# 0. SETUP
#-------------------------------------------------------------------------------

# import libraries
library(dplyr)
library(ggplot2)
library(maps)
library(viridis)
library(ggrepel)
library(ggridges)
library(tidyr)
library(ggcorrplot)

# define personalized theme
personalized_theme <- function() {
  theme_minimal() +
    theme(
      plot.title = element_text(size = 16, hjust = 0, face = "bold"),
      plot.subtitle = element_text(size = 12, hjust = 0),
      axis.title = element_text(size = 9, face = "bold"),
      axis.text = element_text(size = 9),
      legend.text = element_text(size = 9),
      legend.key.size = unit(0.5, "cm"),
      legend.key.width = unit(0.5, "cm"),
      plot.caption = element_text(hjust = 0, color = "grey37")
    )
}

# set default theme
theme_set(theme_bw())

# load dataset
dataset <- read.csv("Data/cleaned_data/final_salaries_data.csv")

# load auxiliary data for lat/long
latlong <- read.csv("files/latlong.csv")
dataset <- inner_join(dataset, latlong, by = "location")

# adjust population size
dataset$city_population <- dataset$city_population / 1000000

#-------------------------------------------------------------------------------
# PLOT 1: AVG MEDIAN SALARY BY CITY
#-------------------------------------------------------------------------------

# group by location and compute the avg and IQR on median salary
temp <- dataset %>%
  group_by(location) |>
  mutate(estimatedMedian_yearly = estimatedMedian_yearly / 1000) |>
  summarise(
    mean = mean(estimatedMedian_yearly),
    median_min = quantile(estimatedMedian_yearly, 0.25),
    median_max = quantile(estimatedMedian_yearly, 0.75),
  ) |>
  arrange(desc(mean)) |>
  inner_join(latlong, by = "location")

# rank locations by avg median salary (needed to reorder the x axis)
temp$rank <- seq(1, nrow(temp))

# create a new column to specify point type
temp$point_type <- ifelse(temp$mean > 0, "Mean", "Other")

# plot
p1 <- ggplot(temp, aes(x = reorder(location, rank))) +
  geom_segment(
    aes(xend = location, y = median_max, yend = median_min),
    color = "lightsteelblue2",
    linewidth = 0.7
  ) +
  geom_point(aes(y = mean, color = point_type, shape = point_type), size = 2) +
  geom_point(
    aes(y = median_min, color = "Top-Bottom 25%", shape = "Top-Bottom 25%"),
    size = 2,
    alpha = 0.6
  ) +
  geom_point(
    aes(y = median_max, color = "Top-Bottom 25%", shape = "Top-Bottom 25%"),
    size = 2,
    alpha = 0.6
  ) +
  scale_color_manual(
    values = c(
      "Mean" = "dodgerblue4",
      "Other" = "gray",
      "Top-Bottom 25%" = "#22A884FF"
    )
  ) +
  scale_shape_manual(
    values = c("Mean" = 19, "Other" = 18, "Top-Bottom 25%" = 18)
  ) +
  scale_y_continuous(
    breaks = c(15, 30, 45, 60, 75, 90, 105, 120),
    labels = scales::comma
  ) +
  labs(
    x = "City",
    y = "Median Annual Earnings (Thousands EUR)",
    title = "Euro Salaries in the Spotlight",
    subtitle = "Exploring Median Annual Earnings across European Cities",
    caption = "Distribution of median annual salaries in a sample of 96 job titles."
  ) +
  personalized_theme() +
  theme(
    axis.text.x = element_text(angle = 90, hjust = 1),
    legend.title = element_blank(),
    legend.position = "top",
    legend.direction = "horizontal",
    legend.justification = "left",
    legend.box.just = "left",
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_line(color = "gray", linetype = "dotted", linewidth = 0.5),
    panel.grid.minor.y = element_line(color = "gray", linetype = "dotted", linewidth = 0.5),
  )

ggsave("visuals/avgmediansalary.png", plot = p1, bg = "white", width = 8, height = 6)

#-------------------------------------------------------------------------------
# PLOT 2: BOXPLOT MEDIAN SALARY BY CITY
#-------------------------------------------------------------------------------

# plot
p2 <- ggplot(
  dataset |>
    inner_join(temp, by = "location"),
  aes(x = reorder(location, rank), y = estimatedMedian_yearly / 1000)
) +
  geom_boxplot(
    fill = "#6AAAB7", color = "#440154FF", alpha = 0.6,
    outlier.shape = NA
  ) +
  labs(
    x = "City",
    y = "Median Annual Earnings (Thousands EUR)",
    title = "Euro Salaries in the Spotlight",
    subtitle = "Exploring Median Annual Earnings across European Cities",
    caption = "Distribution of median annual salaries in a sample of 96 job titles."
  ) +
  scale_y_continuous(breaks = seq(0, 200, 25)) +
  geom_jitter(shape = 16, color = "#440154FF", position = position_jitter(0.2), alpha = 0.10) +
  personalized_theme() +
  theme(
    axis.text.x = element_text(angle = 90, hjust = 1),
    legend.title = element_blank(),
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_line(color = "gray", linetype = "dotted", linewidth = 0.5),
    panel.grid.minor.y = element_line(color = "gray", linetype = "dotted", linewidth = 0.5),
  )

dat <- ggplot_build(p2)$data[[1]]

p2 <- p2 + geom_segment(data = dat, aes(
  x = xmin, xend = xmax,
  y = middle, yend = middle
), colour = "#D44292", linewidth = 1)

ggsave("visuals/avgmediansalarybox.png", plot = p2, bg = "white", width = 8, height = 6)

#-------------------------------------------------------------------------------
# PLOT 3: MAP AVG MEDIAN SALARY EU
#-------------------------------------------------------------------------------

# select EU countries
eu_countries <- c(
  "Spain", "France", "Switzerland", "Germany",
  "Austria", "Belgium", "UK", "Netherlands", "Poland", "Italy"
)

# get map data
eu_maps <- map_data("world", region = eu_countries)

# remove cities (too many otherwise)
filtered_temp <- temp |>
  filter(!(location %in% c("Den Haag", "Utrecht", "Rotterdam", "Eindhoven", "Basel", "Geneva")))

# plot
p3 <- ggplot() +
  geom_polygon(
    data = eu_maps, aes(x = long, y = lat, group = group),
    fill = "#cecfcf", color = "#fffcfce8"
  ) +
  geom_point(
    data = filtered_temp, aes(x = long, y = lat, fill = mean, size = mean),
    alpha = 0.6, color = "black", shape = 21
  ) +
  scale_size(range = c(2, 7), labels = function(x) format(x, scientific = FALSE)) +
  scale_fill_viridis(
    option = "mako", name = "Median Yearly Salary (Eur)",
    trans = "log1p"
  ) +
  guides(size = "none") +
  geom_text_repel(
    data = filtered_temp, aes(x = long, y = lat, label = location),
    hjust = 1, size = 2.5, box.padding = 0.45,
    segment.color = "transparent"
  ) +
  labs(
    title = "The Geography of Euro Earnings",
    subtitle = "Exploring Median Annual Earnings across European Cities",
    caption = "Average median annual salary in a sample of 96 job titles.",
    colors = "Thousands EUR"
  ) +
  theme_void() +
  theme(
    plot.title = element_text(size = 16, hjust = 0, face = "bold"),
    legend.title = element_blank(),
    legend.justification = "left",
    legend.box.just = "left",
    plot.caption = element_text(hjust = 0, color = "grey37"),
  )

ggsave("visuals/avgmediansalarymap.png", plot = p3, bg = "white", width = 6, height = 6)

#-------------------------------------------------------------------------------
# PLOT 4: CORRELATION MATRIX
#-------------------------------------------------------------------------------

# reshape df from long to wide
wide_df <- dataset %>%
  distinct(location, estimatedMedian_yearly, job) %>%
  spread(location, estimatedMedian_yearly)

# calculate the correlation matrix
cor_matrix <- cor(wide_df |> select(-job), use = "pairwise.complete.obs")

# plot heatmap of the correlation matrix
p4 <- ggcorrplot(
  cor_matrix,
  type = "upper",
  legend.title = "Correlation",
  hc.order = TRUE
) +
  scale_fill_viridis_c(option = "mako", limits = c(-1, 1)) +
  personalized_theme() +
  labs(
    title = "How Similar are Salaries Across Cities?",
    subtitle = "Pairwise correlations in job salaries across European cities",
    caption = "Pearson correlation coefficient between median salaries for common job titles\nin European countries.",
    fill = "Correlation"
  ) +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    axis.text.x = element_text(size = 8, angle = 90, hjust = 1),
    axis.text.y = element_text(size = 8),
    axis.title = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
  )

ggsave("visuals/corrheatmap.png", plot = p4, bg = "white", width = 6, height = 6)

#-------------------------------------------------------------------------------
# PLOT 5: HIGHEST AND LOWEST SALARIES
#-------------------------------------------------------------------------------

# identify top and bottom 10 jobs
grouped_data <- dataset %>%
  group_by(job) %>%
  summarise(mean = mean(estimatedMedian_yearly)) |>
  mutate(rank = dense_rank(desc(mean))) %>%
  {
    keep <<- .
  } %>%
  filter(rank <= 10 | rank >= nrow(keep) - 10) %>%
  mutate(
    overall_mean = mean(keep$mean),
    deviation = mean - overall_mean
  )

# define tick labels
labels_low <- c("-50k", "-40k", "-30k", "-20k", "-10k")
labels_high <- c("+10k", "+20k", "+30k", "+40k", "+50k")
central_label <- scales::comma(as.integer(unique(grouped_data$overall_mean)))
labels <- c(labels_low, central_label, labels_high)

grouped_data$is_above <- ifelse(grouped_data$deviation >= 0, "positive", "negative")

# plot
p5 <- ggplot(
  grouped_data,
  aes(x = reorder(job, -deviation), y = deviation, color = is_above)
) +
  geom_segment(
    aes(xend = job, yend = 0),
    color = "lightsteelblue2",
    linewidth = 0.4
  ) +
  geom_point(size = 2, alpha = 1) +
  geom_hline(
    yintercept = 0,
    linetype = "solid",
    color = "black",
    linewidth = 0.8
  ) +
  labs(
    x = "Job", y = "Distance from Avg. Median Salary",
    title = "Euro Jobs: Highs and Lows in Salaries",
    subtitle = "Top 10 Best and Worst Paid Jobs Across Europe",
    caption = "Deviations from average median yearly salary across selected European countries."
  ) +
  theme(legend.position = "none") +
  scale_y_continuous(
    labels = labels,
    breaks = seq(-50000, 50000, 10000),
    limits = c(-50000, 50000)
  ) +
  scale_color_manual(values = c("negative" = "#D44292", "positive" = "#2A788EFF")) +
  personalized_theme() +
  theme(
    plot.title = element_text(
      size = 16,
      hjust = 0.5,
      face = "bold",
      margin = margin(0, 0, 10, 0)
    ),
    plot.subtitle = element_text(hjust = 0.5),
    legend.title = element_blank(),
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    axis.text.x = element_text(size = 10),
    axis.text.y = element_text(size = 8),
    axis.title = element_text(size = 11, face = "bold"),
    panel.grid.major.y = element_line(color = "gray", linetype = "dotted", linewidth = 0.5),
    panel.grid.minor.y = element_line(color = "gray", linetype = "dotted", linewidth = 0.5),
    axis.title.x = element_text(margin = margin(10, 0, 0, 0)),
  ) +
  coord_flip()


ggsave("visuals/highestandlowestsalaries.png", plot = p5, bg = "white", width = 7, height = 6)

#-------------------------------------------------------------------------------
# PLOT 6: RIDGE PLOT LARGE CITIES
#-------------------------------------------------------------------------------

# calculate the quartiles
grouped_data <- dataset %>%
  group_by(location) %>%
  summarise(mean = mean(estimatedMedian_yearly)) |>
  filter()

p6 <- ggplot(
  dataset |>
    filter(location %in% c("Milano", "London", "Berlin", "Paris", "Madrid")) |>
    mutate(location = reorder(location, estimatedMedian_yearly, FUN = mean)),
  aes(
    x = estimatedMedian_yearly,
    y = location,
    fill = factor(after_stat(quantile))
  )
) +
  stat_density_ridges(
    geom = "density_ridges_gradient", calc_ecdf = TRUE,
    quantiles = 4, quantile_lines = TRUE
  ) +
  scale_fill_viridis_d(
    option = "mako",
    name = "Quartiles",
    guide = guide_legend(override.aes = list(size = 0, alpha = 1))
  ) +
  labs(title = "Median Salaries in Main European Cities") +
  labs(
    x = "Median Yearly Salary (EUR)",
    y = "City",
    title = "A Closer Look at Large Cities",
    subtitle = "Distribution of Median Yearly Salary",
    caption = "Distribution of median yearly salaries in a sample of 96 job titles."
  ) +
  scale_x_continuous(labels = scales::comma, breaks = seq(0, 150000, 25000), limits = c(0, 150000)) +
  personalized_theme() +
  theme(
    plot.title = element_text(size = 16, face = "bold", margin = margin(0, 0, 10, 0)),
    legend.position = "top",
    legend.direction = "horizontal",
    legend.justification = "left",
    legend.box.just = "left",
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    axis.text.x = element_text(size = 10),
    axis.text.y = element_text(size = 10),
    axis.title.x = element_text(size = 11, face = "bold", margin = margin(10, 0, 0, 0)),
    axis.title.y = element_text(size = 11, face = "bold"),
    panel.grid.major.y = element_line(color = "gray", linetype = "solid", linewidth = 0.5),
    panel.grid.minor.y = element_line(color = "gray", linetype = "solid", linewidth = 0.5),
  )

ggsave("visuals/ridgeslargecities.png", plot = p6, bg = "white", width = 7, height = 6)
