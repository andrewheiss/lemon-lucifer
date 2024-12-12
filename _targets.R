library(targets)
library(tarchetypes)
suppressPackageStartupMessages(library(dplyr))

options(
  tidyverse.quiet = TRUE,
  dplyr.summarise.inform = FALSE
)

# Bayesian stuff
suppressPackageStartupMessages(library(brms))
options(
  mc.cores = 4,
  brms.backend = "cmdstanr"
)

set.seed(900991)  # From random.org

# This hardcodes the absolute path in _targets.yaml, so to make this more
# portable, we rewrite it every time this pipeline is run (and we don't track
# _targets.yaml with git)
tar_config_set(
  store = here::here("_targets"),
  script = here::here("_targets.R")
)

tar_option_set(
  packages = c("tidyverse"),
  format = "qs",
  workspace_on_error = TRUE,
  workspaces = c()
)

# here::here() returns an absolute path, which then gets stored in tar_meta and
# becomes computer-specific (i.e. /Users/andrew/Research/blah/thing.Rmd).
# There's no way to get a relative path directly out of here::here(), but
# fs::path_rel() works fine with it (see
# https://github.com/r-lib/here/issues/36#issuecomment-530894167)
here_rel <- function(...) {fs::path_rel(here::here(...))}

# Run the R scripts in R/
tar_source()

# Set some conditional flags
should_deploy <- identical(Sys.getenv("UPLOAD_WEBSITES"), "TRUE")
is_docker <- identical(Sys.getenv("IS_DOCKER"), "TRUE")

# Pipeline ----------------------------------------------------------------
list(
  ## Raw data files ----
  tar_target(daily_data_raw_file,
    here_rel("data", "raw_data", "daily_panel.rds"),
    format = "file"),
  tar_target(derog_back_raw,
    here_rel("data", "raw_data", "JHR Symposium HR and DB 4 30 24 stata data.dta"),
    format = "file"),
  tar_target(naturalearth_raw_file,
    here_rel("data", "raw_data", "ne_110m_admin_0_countries",
      "ne_110m_admin_0_countries.shp"),
    format = "file"),
  tar_target(treaty_actions_raw_file,
    here_rel("data", "raw_data", "Treaty Action Data for Graphs.xlsx"),
    format = "file"),

  ## Process and clean data ----
  tar_target(derog, clean_derog(derog_back_raw)),
  tar_target(daily_data, readRDS(daily_data_raw_file)),

  tar_target(world_map, load_world_map(naturalearth_raw_file)),
  tar_target(derog_count, make_derog_count(daily_data)),
  tar_target(map_with_data, make_map_data(derog, derog_count, world_map)),

  tar_target(
    action_state_type,
    readxl::read_excel(treaty_actions_raw_file, sheet = "HR Treaty Action by St and Type")
  ),
  tar_target(
    action_treaty,
    readxl::read_excel(treaty_actions_raw_file, sheet = "Treaty Actions by Treaty")
  ),
  tar_target(
    action_non_derog,
    readxl::read_excel(treaty_actions_raw_file, sheet = "Non-Derogation Actions Filed")
  ),

  ## Graphics ----
  tar_target(graphic_functions, lst(
    theme_pandem, set_annotation_fonts, clrs, label_pp
  )),
  tar_target(diagnostic_functions, lst(plot_trace, plot_trank, plot_pp)),
  tar_target(helper_functions, lst(
    fmt_p_inline, fmt_coef, calc_preds, calc_preds_details, make_preds_inline,
    calc_preds_diffs, calc_preds_diffs_details, calc_fuzzy_labs,
    line_divider, line_divider_v, nested_settings, nested_settings_diffs,
    theme_fuzzy_bar, theme_diffs, label_scale_pp, make_diffs_tbl
  )),

  ## Model things ----
  tar_target(modelsummary_functions, lst(coef_map, gof_map)),

  tar_target(m_derogations, f_derogations(derog)),
  tar_target(m_tbl_derogations, build_modelsummary(m_derogations)),

  tar_target(m_restrictions, f_restrictions(derog)),
  tar_target(m_tbl_restrictions, build_modelsummary(m_restrictions)),

  tar_target(m_hr, f_hr(derog)),
  tar_target(m_tbl_hr, build_modelsummary(m_hr)),

  ## Manuscript and analysis notebook ----
  tar_quarto(manuscript, path = "manuscript", quiet = FALSE),

  tar_quarto(website, path = ".", quiet = FALSE),
  tar_target(deploy_script, here_rel("deploy.sh"), format = "file", cue = tar_cue_skip(!should_deploy)),
  tar_target(deploy, {
    # Force a dependency
    website
    # Run the deploy script
    if (should_deploy) processx::run(paste0("./", deploy_script))
  }, cue = tar_cue_skip(!should_deploy)),

  ## Render the README ----
  tar_quarto(readme, here_rel("README.qmd"))
)
