library(targets)
library(tarchetypes)
suppressPackageStartupMessages(library(dplyr))

options(
  tidyverse.quiet = TRUE,
  dplyr.summarise.inform = FALSE
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

# Pipeline ----------------------------------------------------------------
list(
  ## Raw data files ----
  tar_target(derog_back_raw,
    here_rel("data", "raw_data", "JHR Symposium HR and DB 4 30 24 stata data.dta"),
    format = "file"),
  
  ## Process and clean data ----
  tar_target(derog, clean_derog(derog_back_raw)),
  
  ## Model things ----
  tar_target(modelsummary_functions, lst(coef_map, gof_map, tidy_custom.polr))
)
