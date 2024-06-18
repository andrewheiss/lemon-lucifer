gof_map <- tribble(
  ~raw,          ~clean,                 ~fmt, ~omit,
  "nobs",        "N",                    0,    FALSE
)

coef_map <- c(
  "(Intercept)" = "Intercept",
  "derogation_ineffect" = "Derogation in effect",
  "panbackdichot" = "Pandemic backsliding (PanBack), dichotomous",
  "derogation_ineffect:panbackdichot" = "Derogation in effect × Pandemic backsliding",
  "panback" = "Pandemic backsliding (PanBack)",
  "pandem" = "Pandemic violations of democratic standards (PanDem)",
  "new_cases" = "New cases",
  "new_cases_z" = "New cases (standardized)",
  "new_deaths" = "New deaths",
  "new_deaths_z" = "New deaths (standardized)",
  "cumulative_cases" = "Cumulative cases",
  "cumulative_cases_z" = "Cumulative cases (standardized)",
  "cumulative_deaths" = "Cumulative deaths",
  "cumulative_deaths_z" = "Cumulative deaths (standardized)",
  "v2x_rule" = "Rule of law index",
  "No measures|Recommend to not travel" = "No measures | Recommend to not travel",
  "Recommend to not travel|Restrictions in place" = "Recommend to not travel | Restrictions in place",
  "No measures|Recommend closing" = "No measures | Recommend closing",
  "Recommend closing|Require closing" = "Recommend closing | Require closing",
  "No measures|Recommend not leaving house" = "No measures | Recommend not leaving house",
  "Recommend not leaving house|Require not leaving house, with exceptions" = "Recommend not leaving house| Require not leaving house, with exceptions",
  "Require not leaving house, with exceptions|Require not leaving house, with minimal exceptions" = "Require not leaving house, with exceptions | Require not leaving house, with minimal exceptions",
  "No income support|Government replaces less than 50% of lost salary" = "No income support | Government replaces less than 50% of lost salary",
  "Government replaces less than 50% of lost salary|Government replaces more than 50% of lost salary" = "Government replaces less than 50% of lost salary | Government replaces more than 50% of lost salary",
  "No debt relief|Narrow relief" = "No debt relief | Narrow relief",
  "Narrow relief|Broad relief" = "Narrow relief | Broad relief",
  "None|Minor" = "None | Minor",
  "Minor|Moderate" = "Minor | Moderate",
  "Moderate|Major" = "Moderate | Major",
  "None|Moderate" = "None | Moderate"
)

tidy_custom.polr <- function(x, ...) {
  s <- lmtest::coeftest(x)
  out <- data.frame(
    term = row.names(s),
    p.value = s[, "Pr(>|t|)"])
  out
}
