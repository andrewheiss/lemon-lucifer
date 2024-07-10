# Diagnostic plots

plot_trace <- function(model, params) {
  model |>
    tidybayes::gather_draws(!!!syms(params)) |>
    ggplot(aes(x = .iteration, y = .value, color = factor(.chain))) +
    geom_line(linewidth = 0.1) +
    scale_color_viridis_d(option = "rocket", end = 0.85) +
    labs(color = "Chain") +
    facet_wrap(vars(.variable), scales = "free_y") +
    theme_pandem()
}

plot_trank <- function(model, params) {
  model |>
    tidybayes::gather_draws(!!!syms(params)) |>
    group_by(.variable) |>
    mutate(draw_rank = rank(.value)) |>
    ggplot(aes(x = draw_rank, color = factor(.chain))) +
    stat_bin(geom = "step", binwidth = 200, position = position_identity(), boundary = 0) +
    scale_color_viridis_d(option = "rocket", end = 0.85) +
    labs(color = "Chain") +
    facet_wrap(vars(.variable), scales = "free_y") +
    theme_pandem()
}

plot_pp <- function(model) {
  bayesplot::pp_check(model, ndraws = 100, type = "bars") +
    theme_pandem()
}
