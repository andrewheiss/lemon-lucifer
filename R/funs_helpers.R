library(glue)

fmt_p_inline <- function(x, direction, estimand = "or", html = FALSE) {
  direction <- ifelse(direction == "gt", ">", "<")
  threshold <- ifelse(estimand == "or", 1, 0)

  estimand_html <- ifelse(estimand == "or", "e<sup>β</sup>", r"[e^\beta]")

  if (html) {
    out <- glue(
      r"[<em>p</em>({est} {direction} 1) = {x}]",
      x = label_number(accuracy = 0.01, style_negative = "minus")(x),
      est = ifelse(estimand == "or", "e<sup>β</sup>", "∆")
    )
  } else {
    out <- glue(
      r"[$p[{est} {direction} {threshold}] = {x}$]",
      x = label_number(accuracy = 0.01)(x),
      est = ifelse(estimand == "or", r"[e^\beta]", r"[\Delta]")
    )
  }

  return(out)
}

fmt_coef <- function(x, html = FALSE) {
  if (html) {
    out <- glue(
      r"[e<sup>β</sup> = {x}]",
      x = label_number(accuracy = 0.01, style_negative = "minus")(x)
    )
  } else {
    out <- glue(
      r"[$e^\beta = {x}$]",
      x = label_number(accuracy = 0.01)(x)
    )
  }

  return(out)
}

calc_preds <- function(x) {
  x |>
    epred_draws(
      datagrid(model = x, derogation_ineffect = unique, panbackdichot = unique),
      ndraws = 500, seed = 1234
    ) |>
    ungroup() |>
    mutate(
      derogation_ineffect = factor(derogation_ineffect, labels = c("No derogation", "Derogation"), ordered = TRUE),
      panbackdichot = factor(panbackdichot, labels = c("Low backsliding risk", "High backsliding risk"), ordered = TRUE)
    )
}

calc_preds_details <- function(preds) {
  preds |>
    group_by(.category, derogation_ineffect, panbackdichot) |>
    median_hdci(.epred) |>
    arrange(desc(.category)) |>
    group_by(derogation_ineffect, panbackdichot) |>
    mutate(
      prob_nice = scales::label_percent(accuracy = 0.1)(.epred),
      prob_ci_nice = case_when(
        round(.lower, 2) == round(.upper, 2) ~ glue("≈{label_percent(accuracy = 1)(.upper)}"),
        .default = glue("{ymin}–{ymax}",
          ymin = label_number(accuracy = 1, scale = 100)(.lower),
          ymax = label_percent(accuracy = 1)(.upper)
        )
      )
    ) |>
    ungroup()
}

make_preds_inline <- function(preds_details) {
  preds_details |>
    mutate(across(
      c(.category, derogation_ineffect, panbackdichot),
      ~ janitor::make_clean_names(., allow_dupes = TRUE)
    )) |>
    split(~ panbackdichot + derogation_ineffect + .category, drop = TRUE)
}

calc_preds_diffs <- function(preds) {
  bind_rows(
    preds |>
      group_by(panbackdichot, .category) |>
      compare_levels(.epred, by = derogation_ineffect, comparison = "control") |>
      ungroup(),
    preds |>
      group_by(derogation_ineffect, .category) |>
      compare_levels(.epred, by = panbackdichot, comparison = "control") |>
      ungroup()
  ) |>
    mutate(
      panbackdichot = fct_recode(
        panbackdichot,
        "High − low backsliding risk" = "High backsliding risk - Low backsliding risk"
      ),
      panbackdichot = fct_relevel(
        panbackdichot,
        "Low backsliding risk", "High backsliding risk", "High − low backsliding risk"
      )
    )
}

calc_preds_diffs_details <- function(preds_diffs) {
  preds_diffs |>
    group_by(panbackdichot, derogation_ineffect, .category) |>
    reframe(
      post_medians = median_hdci(.epred, .width = 0.95),
      p_gt_0 = sum(.epred > 0) / n()
    ) |>
    unnest(post_medians) |>
    mutate(
      display_min = pmin(abs(ymin), abs(ymax)),
      display_max = pmax(abs(ymin), abs(ymax)),
      pp_nice = label_number(accuracy = 0.1, scale = 100, style_negative = "minus")(y),
      pp_ci_nice = case_when(
        round(ymin, 2) == round(ymax, 2) ~ glue("≈{label_percent(accuracy = 1)(ymax)}"),
        .default = glue("{ymin}–{ymax}",
          ymin = label_number(accuracy = 1, scale = 100)(display_min),
          ymax = label_number(accuracy = 1, scale = 100)(display_max)
        )
      )
    ) |>
    mutate(
      p_lt_0 = 1 - p_gt_0,
      p_gt = fmt_p_inline(p_gt_0, "gt", estimand = "diff"),
      p_lt = fmt_p_inline(p_lt_0, "lt", estimand = "diff"),
      p_d = if_else(y > 0, p_gt, p_lt)
    )
}

calc_fuzzy_labs <- function(preds_details, filter_small = TRUE) {
  if (filter_small) {
    preds_details <- filter(preds_details, .epred >= 0.05)
  }

  preds_details |>
    group_by(derogation_ineffect, panbackdichot) |>
    mutate(
      y_end = cumsum(.epred),
      y_start = lag(y_end, default = 0),
      y = y_end - ((y_end - y_start) / 2)
    ) |>
    mutate(
      y = case_when(
        y <= 0.06 ~ 0.06,
        y >= 0.94 ~ 0.94,
        .default = y
      )
    ) |>
    arrange(panbackdichot, derogation_ineffect, desc(.category)) |>
    group_by(panbackdichot, derogation_ineffect) |>
    mutate(
      v_distance = dplyr::lead(y) - y,
      is_close = v_distance < 0.1 & !is.na(v_distance),
      move_left = is_close,
      move_right = dplyr::lag(is_close, default = FALSE)
    ) |>
    mutate(
      x = case_when(
        move_left ~ 15,
        move_right ~ 500 - 15,
        .default = 250
      ),
      hjust = case_when(
        move_left ~ 0,
        move_right ~ 1,
        .default = 0.5
      )
    )
}

line_divider <- grid::linesGrob(
  x = c(0, 1), y = c(0.5, 0.5),
  gp = grid::gpar(col = "grey80", lty = "dashed", lwd = 0.75)
)

line_divider_v <- grid::linesGrob(
  x = c(0.5, 0.5), y = c(0, 1),
  gp = grid::gpar(col = "grey80", lty = "dashed", lwd = 0.75)
)

nested_settings <- ggh4x::strip_nested(
  background_x = list(ggplot2::element_rect(fill = "grey92"), NULL),
  text_x = list(NULL, ggplot2::element_text(size = ggplot2::rel(0.87))),
  by_layer_x = TRUE
)

nested_settings_diffs <- ggh4x::strip_nested(
  background_x = list(ggplot2::element_rect(fill = "grey92"), ggplot2::element_rect(fill = "grey82")),
  by_layer_x = TRUE,
  bleed = TRUE
)

theme_fuzzy_bar <- ggplot2::theme(
  strip.text = ggplot2::element_text(size = ggplot2::rel(0.75)),
  legend.title.position = "top",
  legend.position = "top",
  legend.title = ggplot2::element_text(size = ggplot2::rel(1)),
  legend.background = ggplot2::element_rect(),
  plot.tag.position = c(0, 1),
  plot.tag = ggplot2::element_text(size = ggplot2::rel(0.9))
)

theme_diffs <- ggplot2::theme(
  strip.background = ggplot2::element_rect(fill = "grey92"),
  strip.text = ggplot2::element_text(size = ggplot2::rel(0.65)),
  plot.title = ggplot2::element_text(size = ggplot2::rel(0.9)),
  plot.tag.position = c(0, 1),
  plot.tag = ggplot2::element_text(size = ggplot2::rel(0.9))
)

label_scale_pp <- function(x) {
  scales::label_number(
    accuracy = 1.1, scale = 100, style_negative = "minus"
  )(x)
}

make_diffs_tbl <- function(diffs) {
  diffs_summary <- diffs |>
    group_by(panbackdichot, derogation_ineffect, .category) |>
    reframe(
      post_medians = median_hdci(.epred, .width = 0.95),
      p_gt_0 = sum(.epred > 0) / n()
    ) |>
    unnest(post_medians)

  tbl_diffs <- diffs_summary |>
    mutate(
      panbackdichot = str_replace(panbackdichot, " − ", "−"),
      derogation_ineffect = str_replace(derogation_ineffect, " - ", "−")
    ) |>
    mutate(cat1 = case_when(
      str_detect(panbackdichot, "−") ~ panbackdichot,
      str_detect(derogation_ineffect, "−") ~ derogation_ineffect,
    )) |>
    mutate(cat2 = case_when(
      !str_detect(panbackdichot, "−") ~ panbackdichot,
      !str_detect(derogation_ineffect, "−") ~ derogation_ineffect,
    )) |>
    mutate(group_label = as.character(glue("{cat2}: {cat1}"))) |>
    mutate(across(c(y, ymin, ymax), ~ label_scale_pp(.))) |>
    mutate(ci = glue("[{ymin}, {ymax}]")) |>
    mutate(y_ci = paste(y, ci)) |>
    mutate(p_gt_0 = label_number(accuracy = 0.01)(p_gt_0))

  group_labels_rle <- rle(tbl_diffs$group_label)
  group_labels <- set_names(
    cumsum(group_labels_rle$lengths) - group_labels_rle$lengths + 1,
    group_labels_rle$values
  ) |> as.list()

  tbl_diffs |>
    select(Severity = .category, `Median ∆` = y_ci, `p(∆ > 0)` = p_gt_0) |>
    tt(width = c(0.4, 0.4, 0.2)) |>
    group_tt(i = group_labels) |>
    style_tt(j = 2:3, align = "c") |>
    style_tt(
      i = as.numeric(group_labels) + 0:(length(group_labels) - 1),
      j = 1, bold = TRUE, background = "#e6e6e6", align = "l"
    )
}
