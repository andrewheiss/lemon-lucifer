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
