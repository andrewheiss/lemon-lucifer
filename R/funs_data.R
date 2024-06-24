clean_derog <- function(data_raw) {
  library(haven)
  
  derog <- read_stata(data_raw) |>
    zap_formats() |>
    zap_label() |>
    mutate(
      c5_public_transport = factor(c5_public_transport,
        levels = 0:2,
        labels = c("No measures", "Recommend closing", "Require closing"),
        ordered = TRUE
      ),
      c6_stay_at_home = factor(c6_stay_at_home,
        levels = 0:3,
        labels = c(
          "No measures", 
          "Recommend not leaving house", 
          "Require not leaving house, with exceptions", 
          "Require not leaving house, with minimal exceptions"
        ),
        ordered = TRUE
      ),
      c7_internal_movement = factor(c7_internal_movement,
        levels = 0:2,
        labels = c("No measures", "Recommend to not travel", "Restrictions in place"),
        ordered = TRUE
      ),
      e1_income_support = factor(e1_income_support,
        levels = 0:2,
        labels = c(
          "No income support", 
          "Government replaces less than 50% of lost salary", 
          "Government replaces more than 50% of lost salary"
        ),
        ordered = TRUE
      ),
      e2_debt_relief = factor(e2_debt_relief,
        levels = 0:2,
        labels = c("No debt relief", "Narrow relief", "Broad relief"),
        ordered = TRUE
      ),
      pandem_discrim = factor(pandem_discrim,
        levels = c("None", "Minor", "Moderate", "Major"),
        ordered = TRUE
      ),
      pandem_ndrights = factor(pandem_ndrights,
        levels = c("None", "Major"),
        ordered = TRUE
      ),
      pandem_abusive = factor(pandem_abusive,
        levels = c("None", "Minor", "Moderate", "Major"),
        ordered = TRUE
      ),
      pandem_nolimit = factor(pandem_nolimit,
        levels = c("None", "Moderate", "Major"),
        ordered = TRUE
      ),
      pandem_media = factor(pandem_media,
        levels = c("None", "Minor", "Moderate", "Major"),
        ordered = TRUE
      )
    ) |>
    mutate(
      panbackdichot = panbackdichot - 1,
      panbackdichot_bin = as.logical(panbackdichot)
    ) |> 
    mutate(
      across(
        c(new_cases, new_deaths, cumulative_cases, cumulative_deaths),
        list(z = ~ as.numeric(scale(.)))
      )
    )
}

clean_pandem <- function(path) {
  library(readxl)
  library(countrycode)
  
  pandem_raw <- read_excel(path)
  
  pandem_clean <- pandem_raw |>
    mutate(year_quarter = paste0(year, "-", quarter)) |>
    mutate(iso3 = countrycode(country_name, 
      origin = "country.name", 
      destination = "iso3c"),
      country_name = countrycode(iso3, origin = "iso3c", 
        destination = "country.name",
        custom_match = c("TUR" = "Türkiye"))
    ) |>
    select(country_name, iso3, year, year_quarter, pandem, panback)
  
  return(pandem_clean)
}

load_world_map <- function(path) {
  suppressPackageStartupMessages(library(sf))
  
  world_map <- read_sf(path) |>
    filter(ISO_A3 != "ATA") |> 
    rename(iso3 = ISO_A3_EH)
  
  return(world_map)
}

make_derog_count <- function(data) {
  new_derogations <- data |> 
    group_by(iso3) |> 
    summarize(derogations = sum(iccpr_derogation_filed))
  
  return(new_derogations)
}

make_map_data <- function(derog, derog_count, map) {
  suppressPackageStartupMessages(library(sf))
  
  pandem_levels <- c(
    "No violations (0)",
    "Minor violations (0.05–0.15)",
    "Moderate violations (0.20–0.30)",
    "Major violations (0.35–1.00)"
  )
  
  vdem_summaries <- derog |> 
    group_by(iso3) |> 
    summarize(
      avg_panback = mean(panback),
      max_pandem = max(pandem)
    ) |> 
    mutate(avg_panback_cut = cut(
      avg_panback, breaks = c(-Inf, 0.1, 0.2, 0.3, Inf), right = FALSE,
      labels = c("< 0.1 (low risk)", "< 0.2", "< 0.3", "≥ 0.3 (high risk)"))
    ) |> 
    mutate(max_pandem_cut = case_when(
      max_pandem == 0 ~ pandem_levels[1],
      max_pandem >= 0.05 & max_pandem < 0.2 ~ pandem_levels[2],
      max_pandem >= 0.2 & max_pandem < 0.35 ~ pandem_levels[3],
      max_pandem >= 0.35 & max_pandem <= 1 ~ pandem_levels[4]
    )) |> 
    mutate(max_pandem_cut = factor(max_pandem_cut, levels = pandem_levels, ordered = TRUE))
  
  map_with_data <- map |>
    # Fix some Natural Earth ISO weirdness
    # mutate(ISO_A3 = ifelse(ISO_A3 == "-99", as.character(ISO_A3_EH), as.character(ISO_A3))) |>
    mutate(iso3 = case_when(
      ISO_A3 == "GRL" ~ "DNK",
      NAME == "Kosovo" ~ "XKK",
      .default = iso3
    )) |>
    left_join(derog_count, by = join_by(iso3)) |> 
    left_join(vdem_summaries, by = join_by(iso3)) |> 
    mutate(derogations_1plus = ifelse(derogations == 0, NA, derogations))
  
  return(map_with_data)
}
