# Running modelsummary() on Bayesian models takes a while because of all the
# calculations involved in creating the GOF statistics. With modelsummary 0.7+,
# though it's now possible to build the base model with modelsummary(..., output
# = "modelsummary_list"), save that as an intermediate object, and then feed it
# through modelsummary() again with whatever other output you want. The
# modelsummary_list-based object thus acts like an output-agnostic ur-model.

build_modelsummary <- function(models) {
  msl <- models |> 
    modelsummary::modelsummary(
      output = "modelsummary_list",
      statistic = "[{conf.low}, {conf.high}]",
      ci_method = "hdi",
      metrics = c("R2")
    )

  return(msl)
}

gof_map <- tribble(
  ~raw,          ~clean,       ~fmt,  ~omit,
  "nobs",        "N",          0,     FALSE,
  "r.squared",   "\\(R^2\\)",  2,     FALSE
)

coef_map <- c(
  "b_derogation_ineffect" = "Derogation in effect",
  "b_panbackdichot" = "Pandemic backsliding (PanBack), dichotomous",
  "b_derogation_ineffect:panbackdichot" = "Derogation in effect × Pandemic backsliding",
  "b_panback" = "Pandemic backsliding (PanBack)",
  "b_pandem" = "Pandemic violations of democratic standards (PanDem)",
  "b_new_cases" = "New cases",
  "b_new_cases_z" = "New cases (standardized)",
  "b_new_deaths" = "New deaths",
  "b_new_deaths_z" = "New deaths (standardized)",
  "b_cumulative_cases" = "Cumulative cases",
  "b_cumulative_cases_z" = "Cumulative cases (standardized)",
  "b_cumulative_deaths" = "Cumulative deaths",
  "b_cumulative_deaths_z" = "Cumulative deaths (standardized)",
  "b_v2x_rule" = "Rule of law index",
  "b_Intercept" = "Intercept",
  "b_Intercept[1]" = "Cut 1",
  "b_Intercept[2]" = "Cut 2",
  "b_Intercept[3]" = "Cut 3"
)


f_derogations <- function(df) {
  BAYES_SEED <- 919416  # From random.org
  
  logit_priors <- c(
    prior(student_t(1, 0, 3), class = Intercept),
    prior(student_t(1, 0, 3), class = b)#,
    # prior(cauchy(0, 1), class = sd, lb = 0)
  )
  
  m_derogations_panback <- brm(
    bf(iccpr_derogation_filed ~ panback + new_cases_z + new_deaths_z + 
        cumulative_cases_z + cumulative_deaths_z + v2x_rule + 
        year_week_num),
    data = df,
    family = bernoulli(),
    prior = logit_priors,
    chains = 4, seed = BAYES_SEED,
    control = list(adapt_delta = 0.91),
    threads = threading(2)
  )

  m_derogations_pandem <- brm(
    bf(iccpr_derogation_filed ~ pandem + new_cases_z + new_deaths_z + 
        cumulative_cases_z + cumulative_deaths_z + v2x_rule + 
        year_week_num),
    data = df,
    family = bernoulli(),
    prior = logit_priors,
    chains = 4, seed = BAYES_SEED,
    control = list(adapt_delta = 0.91),
    threads = threading(2)
  )
  
  return(lst(m_derogations_panback, m_derogations_pandem))
}

f_restrictions <- function(df) {
  BAYES_SEED <- 188747  # From random.org
  
  ologit_priors <- c(
    prior(student_t(1, 0, 3), class = Intercept),
    prior(student_t(1, 0, 3), class = b)
  )
  
  m_restrict_movement <- brm(
    bf(c7_internal_movement ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_restrict_pubtrans <- brm(
    bf(c5_public_transport ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_restrict_stayhome <- brm(
    bf(c6_stay_at_home ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  return(lst(m_restrict_movement, m_restrict_pubtrans, m_restrict_stayhome))
}

f_econ <- function(df) {
  BAYES_SEED <- 123356  # From random.org
  
  ologit_priors <- c(
    prior(student_t(1, 0, 3), class = Intercept),
    prior(student_t(1, 0, 3), class = b)
  )
  
  m_econ_income <- brm(
    bf(e1_income_support ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_econ_debt <- brm(
    bf(e2_debt_relief ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  return(lst(m_econ_income, m_econ_debt))
}

f_hr <- function(df) {
  BAYES_SEED <- 134710  # From random.org
  
  ologit_priors <- c(
    prior(student_t(1, 0, 3), class = Intercept),
    prior(student_t(1, 0, 3), class = b)
  )
  
  m_hr_discrim <- brm(
    bf(pandem_discrim ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_hr_ndrights <- brm(
    bf(pandem_ndrights ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_hr_abusive <- brm(
    bf(pandem_abusive ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_hr_nolimit <- brm(
    bf(pandem_nolimit ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_hr_media <- brm(
    bf(pandem_media ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  return(lst(m_hr_discrim, m_hr_ndrights, m_hr_abusive, m_hr_nolimit, m_hr_media))
}

f_hr <- function(df) {
  BAYES_SEED <- 134710  # From random.org
  
  ologit_priors <- c(
    prior(student_t(1, 0, 3), class = Intercept),
    prior(student_t(1, 0, 3), class = b)
  )
  
  logit_priors <- c(
    prior(student_t(1, 0, 3), class = Intercept),
    prior(student_t(1, 0, 3), class = b)
  )
  
  m_hr_discrim <- brm(
    bf(pandem_discrim ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_hr_ndrights <- brm(
    bf(pandem_ndrights ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = bernoulli(),
    prior = logit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_hr_abusive <- brm(
    bf(pandem_abusive ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_hr_nolimit <- brm(
    bf(pandem_nolimit ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = bernoulli(),
    prior = logit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_hr_media <- brm(
    bf(pandem_media ~ derogation_ineffect*panbackdichot + 
        new_cases_z + new_deaths_z + cumulative_cases_z + cumulative_deaths_z + 
        v2x_rule + year_week_num),
    data = df,
    family = cumulative(),
    prior = ologit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  return(lst(m_hr_discrim, m_hr_ndrights, m_hr_abusive, m_hr_nolimit, m_hr_media))
}

f_treaty <- function(df) {
  BAYES_SEED <- 233840  # From random.org
  
  logit_priors <- c(
    prior(student_t(1, 0, 3), class = Intercept),
    prior(student_t(1, 0, 3), class = b)
  )
  
  m_treaty_panback <- brm(
    bf(noniccprtreatyactionsdichotomous ~ panback + new_cases + new_deaths + 
        cumulative_cases + cumulative_deaths + v2x_rule + year_week_num),
    data = df,
    family = bernoulli(),
    prior = logit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  m_treaty_pandem <- brm(
    bf(noniccprtreatyactionsdichotomous ~ pandem + new_cases + new_deaths + 
        cumulative_cases + cumulative_deaths + v2x_rule + year_week_num),
    data = df,
    family = bernoulli(),
    prior = logit_priors,
    chains = 4, seed = BAYES_SEED,
    threads = threading(2)
  )
  
  return(lst(m_treaty_panback, m_treaty_pandem))
}
