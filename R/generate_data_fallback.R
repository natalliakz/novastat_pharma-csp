# =============================================================================
# SCRIPT   : generate_data_fallback.R
# STUDY    : NSVT-001 | NovaStat Therapeutics (FICTIONAL - AI-generated demo)
# PURPOSE  : R equivalent of sas/generate_sdtm.sas + sas/create_adam.sas
#            Use this when Altair SLC is not available. Produces identical
#            CSV outputs in data/sdtm/ and data/adam/.
# DEMO NOTE: In Positron with Altair SLC, run sas/generate_sdtm.sas and
#            sas/create_adam.sas directly — this is the "hero" demo path.
#            The R bridge in R/bridge.R reads SAS data without needing CSVs.
# NOTE     : ALL DATA IS SYNTHETIC. For demonstration purposes only.
# =============================================================================

library(tidyverse)

set.seed(42)

STUDYID <- "NSVT-001"
DRUG    <- "NST-4892"

dir.create("data/sdtm", recursive = TRUE, showWarnings = FALSE)
dir.create("data/adam",  recursive = TRUE, showWarnings = FALSE)

cat("Generating synthetic SDTM/ADaM data for NSVT-001...\n")
cat("NOTE: All data is AI-generated and synthetic. For demonstration only.\n\n")

# =============================================================================
# SITES
# =============================================================================
sites <- tribble(
  ~SITEID, ~COUNTRY, ~REGION,        ~n_subj,
  "101",   "USA",    "Americas",     40,
  "102",   "USA",    "Americas",     35,
  "103",   "USA",    "Americas",     38,
  "104",   "USA",    "Americas",     37,
  "105",   "DEU",    "Europe",       32,
  "106",   "DEU",    "Europe",       30,
  "107",   "GBR",    "Europe",       33,
  "108",   "JPN",    "AsiaPacific",  35
)

# =============================================================================
# DM: DEMOGRAPHICS
# =============================================================================
dm_rows <- pmap_dfr(sites, function(SITEID, COUNTRY, REGION, n_subj) {
  map_dfr(seq_len(n_subj), function(subj_n) {
    age  <- round(25 + runif(1) * 45)
    sex  <- sample(c("F", "M"), 1, prob = c(0.60, 0.40))

    race_probs <- switch(COUNTRY,
      "USA" = c(0.62, 0.13, 0.12, 0.13),
      "DEU" = c(0.90, 0.03, 0.04, 0.03),
      "GBR" = c(0.86, 0.06, 0.05, 0.03),
      "JPN" = c(0.01, 0.01, 0.97, 0.01),
                c(0.50, 0.15, 0.25, 0.10)
    )
    race <- sample(c("WHITE","BLACK OR AFRICAN AMERICAN","ASIAN",
                     "AMERICAN INDIAN OR ALASKA NATIVE"), 1, prob = race_probs)

    ethnic <- if (COUNTRY == "USA" && runif(1) < 0.18)
                "HISPANIC OR LATINO" else "NOT HISPANIC OR LATINO"

    if (sex == "F") {
      heightbl <- max(148, min(185, round(rnorm(1, 158, 6))))
      weightbl <- max(44,  min(112, round(rnorm(1, 64,  11))))
    } else {
      heightbl <- max(158, min(200, round(rnorm(1, 175, 7))))
      weightbl <- max(54,  min(135, round(rnorm(1, 82,  13))))
    }
    bmibl <- round(weightbl / (heightbl / 100)^2, 1)
    dascr <- max(2.0, min(8.5, round(rnorm(1, 5.2, 1.1), 1)))

    trt01pn <- (subj_n - 1) %% 3L
    trt01p  <- c("Placebo", paste(DRUG, "100mg"), paste(DRUG, "200mg"))[trt01pn + 1]

    rfstdt  <- as.Date("2023-01-01") + floor(runif(1) * 180)
    rfenddt <- rfstdt + 168

    tibble(
      STUDYID = STUDYID,
      DOMAIN  = "DM",
      USUBJID = glue::glue("{STUDYID}-{SITEID}-{sprintf('%03d', subj_n)}"),
      SUBJID  = sprintf("%03d", subj_n),
      SITEID  = SITEID,
      COUNTRY = COUNTRY,
      REGION  = REGION,
      AGE     = age,
      AGEGR1  = case_when(age < 40 ~ "<40", age < 65 ~ "40-64", TRUE ~ ">=65"),
      SEX     = sex,
      RACE    = race,
      ETHNIC  = ethnic,
      HEIGHTBL = heightbl,
      WEIGHTBL = weightbl,
      BMIBL   = bmibl,
      DASCR   = dascr,
      DASGRP  = case_when(dascr < 3.2 ~ "Remission", dascr < 3.7 ~ "Low",
                          dascr < 5.1 ~ "Moderate", TRUE ~ "High"),
      TRT01P  = trt01p,
      TRT01PN = trt01pn,
      ARM     = trt01p,
      ACTARM  = trt01p,
      RFSTDTC = format(rfstdt,  "%Y-%m-%d"),
      RFENDTC = format(rfenddt, "%Y-%m-%d"),
      SAFFL   = "Y",
      ITTFL   = "Y",
      PPROTFL = if_else(runif(1) < 0.95, "Y", "N")
    )
  })
})

dm <- dm_rows
write_csv(dm, "data/sdtm/dm.csv")
cat(sprintf("DM: %d subjects written to data/sdtm/dm.csv\n", nrow(dm)))

# =============================================================================
# AE: ADVERSE EVENTS
# =============================================================================
ae_dict <- tribble(
  ~AEDECOD,                              ~AEBODSYS,                                    ~base_prob, ~sev_p,
  "Headache",                            "Nervous System Disorders",                   0.28,       0.04,
  "Nausea",                              "Gastrointestinal Disorders",                 0.22,       0.03,
  "Fatigue",                             "General Disorders",                           0.25,       0.06,
  "Upper Respiratory Tract Infection",   "Infections and Infestations",                0.16,       0.02,
  "Arthralgia",                          "Musculoskeletal and Connective Tissue Dis.", 0.20,       0.07,
  "Hypertension",                        "Vascular Disorders",                          0.13,       0.10,
  "Rash",                                "Skin and Subcutaneous Tissue Disorders",     0.11,       0.08,
  "Dizziness",                           "Nervous System Disorders",                   0.13,       0.03,
  "Insomnia",                            "Psychiatric Disorders",                       0.10,       0.02,
  "ALT Increased",                       "Investigations",                              0.09,       0.12
)

set.seed(777)
ae <- dm |>
  select(USUBJID, TRT01PN, AGE, DASCR, RFSTDTC) |>
  cross_join(ae_dict) |>
  mutate(
    trt_mult = 1 + TRT01PN * 0.18,
    age_mult = 1 + pmax(0, (AGE - 45) * 0.008),
    das_mult = 1 + pmax(0, (DASCR - 4.5) * 0.06),
    adj_prob = pmin(0.60, base_prob * trt_mult * age_mult * das_mult),
    include  = runif(n()) < adj_prob
  ) |>
  filter(include) |>
  mutate(
    STUDYID  = STUDYID,
    DOMAIN   = "AE",
    VISITNUM = ceiling(runif(n()) * 6),
    VISIT    = paste("WEEK", VISITNUM * 4),
    rfstdt   = as.Date(RFSTDTC),
    ae_day   = pmax(1, floor(runif(n()) * VISITNUM * 28)),
    AESTDTC  = format(rfstdt + ae_day, "%Y-%m-%d"),
    dur      = pmax(1, round(rgamma(n(), 2, scale = 7))),
    AEENDTC  = format(rfstdt + ae_day + dur, "%Y-%m-%d"),
    sev_u    = runif(n()),
    AESEV    = case_when(
      sev_u < sev_p * (1 + TRT01PN * 0.15) ~ "SEVERE",
      sev_u < 0.38 ~ "MODERATE",
      TRUE         ~ "MILD"
    ),
    AESEVN   = case_when(AESEV == "SEVERE" ~ 3L, AESEV == "MODERATE" ~ 2L, TRUE ~ 1L),
    AESER    = if_else(AESEVN == 3 & runif(n()) < 0.35, "Y", "N"),
    rel_p    = if_else(TRT01PN == 0, 0.12, 0.32 + TRT01PN * 0.08),
    AEREL    = if_else(runif(n()) < rel_p, "RELATED", "NOT RELATED"),
    AEOUT    = if_else(AESEVN == 3 & runif(n()) < 0.15,
                       "NOT RECOVERED/NOT RESOLVED", "RECOVERED/RESOLVED")
  ) |>
  arrange(USUBJID, AESTDTC) |>
  group_by(USUBJID) |>
  mutate(AESEQ = row_number()) |>
  ungroup() |>
  select(STUDYID, DOMAIN, USUBJID, AESEQ, AEDECOD, AEBODSYS,
         AESEV, AESEVN, AESER, AEREL, AEOUT, AESTDTC, AEENDTC, VISITNUM, VISIT)

write_csv(ae, "data/sdtm/ae.csv")
cat(sprintf("AE: %d records written to data/sdtm/ae.csv\n", nrow(ae)))

# =============================================================================
# EX: EXPOSURE
# =============================================================================
set.seed(321)
ex <- dm |>
  select(USUBJID, TRT01P, TRT01PN, RFSTDTC) |>
  cross_join(tibble(VIS = 1:6)) |>
  mutate(
    STUDYID  = STUDYID,
    DOMAIN   = "EX",
    EXTRT    = if_else(TRT01PN == 0, "PLACEBO",
               if_else(TRT01PN == 1, paste(DRUG, "100mg"), paste(DRUG, "200mg"))),
    EXDOSE   = c(0, 100, 200)[TRT01PN + 1],
    EXDOSU   = "mg",
    EXROUTE  = "SUBCUTANEOUS",
    VISITNUM = VIS,
    VISIT    = paste("WEEK", VIS * 4),
    rfstdt   = as.Date(RFSTDTC),
    EXSTDTC  = format(rfstdt + (VIS - 1) * 28, "%Y-%m-%d"),
    EXENDTC  = format(rfstdt + VIS * 28 - 1,   "%Y-%m-%d"),
    comp     = pmax(0, pmin(1, rnorm(n(), 0.88, 0.08))),
    EXOCCUR  = if_else(runif(n()) < comp, "Y", "N"),
    EXSEQ    = VIS
  ) |>
  select(STUDYID, DOMAIN, USUBJID, EXSEQ, EXTRT, EXDOSE, EXDOSU,
         EXROUTE, EXOCCUR, VISITNUM, VISIT, EXSTDTC, EXENDTC)

write_csv(ex, "data/sdtm/ex.csv")
cat(sprintf("EX: %d records written to data/sdtm/ex.csv\n", nrow(ex)))

# =============================================================================
# DS: DISPOSITION (with dropout logic)
# =============================================================================

ae_feat <- ae |>
  group_by(USUBJID) |>
  summarise(
    AENUM     = n(),
    AESNUM    = sum(AESER == "Y"),
    AEMAXSEVN = max(AESEVN),
    .groups   = "drop"
  )

ex_feat <- ex |>
  group_by(USUBJID) |>
  summarise(COMPLPCT = mean(EXOCCUR == "Y") * 100, .groups = "drop")

set.seed(888)
ds <- dm |>
  select(USUBJID, SITEID, TRT01PN, RFSTDTC, RFENDTC) |>
  left_join(ae_feat, by = "USUBJID") |>
  left_join(ex_feat, by = "USUBJID") |>
  replace_na(list(AENUM = 0, AESNUM = 0, AEMAXSEVN = 0, COMPLPCT = 100)) |>
  mutate(
    dp_prob = pmin(0.65,
      0.05 +
      (AENUM      >  2) * 0.10 +
      (AENUM      >  4) * 0.08 +
      (AEMAXSEVN  == 3) * 0.18 +
      (AESNUM     >= 1) * 0.08 +
      (COMPLPCT   < 80) * 0.09 +
      (SITEID %in% c("107","108")) * 0.05 +
      (TRT01PN    == 2) * 0.03
    ),
    dropout = runif(n()) < dp_prob,
    dr = sample(4, n(), replace = TRUE, prob = c(0.35, 0.40, 0.15, 0.10)),
    DSDECOD = case_when(
      !dropout           ~ "COMPLETED",
      AEMAXSEVN == 3 | AESNUM >= 1 ~ case_when(
        runif(n()) < 0.60 ~ "ADVERSE EVENT",
        runif(n()) < 0.85 ~ "WITHDRAWAL BY SUBJECT",
        runif(n()) < 0.95 ~ "LOST TO FOLLOW-UP",
        TRUE               ~ "PROTOCOL DEVIATION"
      ),
      TRUE ~ case_when(
        dr == 1 ~ "ADVERSE EVENT",
        dr == 2 ~ "WITHDRAWAL BY SUBJECT",
        dr == 3 ~ "LOST TO FOLLOW-UP",
        TRUE    ~ "PROTOCOL DEVIATION"
      )
    ),
    EOSSTT  = if_else(dropout, "DISCONTINUED", "COMPLETED"),
    DPTFL   = if_else(dropout, "Y", "N"),
    rfstdt  = as.Date(RFSTDTC),
    dp_day  = if_else(dropout, round(runif(n()) * 140) + 14L, 168L),
    DSSTDTC = if_else(dropout,
                      format(rfstdt + dp_day, "%Y-%m-%d"),
                      RFENDTC),
    STUDYID = STUDYID,
    DOMAIN  = "DS",
    DSCAT   = "DISPOSITION EVENT",
    DSSEQ   = 1L
  ) |>
  select(STUDYID, DOMAIN, USUBJID, DSSEQ, DSCAT, DSDECOD, EOSSTT, DPTFL, DSSTDTC)

write_csv(ds, "data/sdtm/ds.csv")
cat(sprintf("DS: %d subjects | Dropout rate: %.1f%%\n",
            nrow(ds), mean(ds$DPTFL == "Y") * 100))

# =============================================================================
# ADSL: SUBJECT LEVEL ANALYSIS DATASET
# =============================================================================

adsl <- dm |>
  left_join(ds |> select(USUBJID, DSDECOD, EOSSTT, DPTFL, DSSTDTC), by = "USUBJID") |>
  left_join(ae_feat, by = "USUBJID") |>
  left_join(ex_feat, by = "USUBJID") |>
  replace_na(list(AENUM = 0, AESNUM = 0, AEMAXSEVN = 0, COMPLPCT = 100)) |>
  mutate(
    DATASET   = "ADSL",
    SEXN      = if_else(SEX == "F", 1L, 2L),
    RACEN     = case_when(
      RACE == "WHITE"                         ~ 1L,
      RACE == "BLACK OR AFRICAN AMERICAN"     ~ 2L,
      RACE == "ASIAN"                         ~ 3L,
      TRUE                                    ~ 4L
    ),
    REGIONN   = case_when(
      REGION == "Europe"      ~ 1L,
      REGION == "AsiaPacific" ~ 2L,
      TRUE                    ~ 0L
    ),
    BMIGRP    = case_when(
      BMIBL < 18.5 ~ "Underweight", BMIBL < 25.0 ~ "Normal",
      BMIBL < 30.0 ~ "Overweight",  TRUE          ~ "Obese"
    ),
    DAS28BL   = DASCR,
    DAS28GRP  = DASGRP,
    AEMAXSEV  = case_when(
      AEMAXSEVN == 3 ~ "SEVERE", AEMAXSEVN == 2 ~ "MODERATE",
      AEMAXSEVN == 1 ~ "MILD",   TRUE ~ "NONE"
    ),
    N_ALT_AE      = 0L,   # would be derived from ae join in full version
    N_NEURO_GI_AE = 0L,
    N_MISSED_DOSES = as.integer(round((100 - COMPLPCT) / 100 * 6)),
    COMPLFL   = if_else(COMPLPCT >= 80, "Compliant", "Non-Compliant"),
    DCDT      = DSSTDTC,
    DPTN      = if_else(DPTFL == "Y", 1L, 0L)
  )

# Add AE term counts properly
ae_terms <- ae |>
  group_by(USUBJID) |>
  summarise(
    N_ALT_AE      = sum(AEDECOD == "ALT Increased"),
    N_NEURO_GI_AE = sum(AEDECOD %in% c("Headache","Nausea","Fatigue","Dizziness","Insomnia")),
    .groups = "drop"
  )
adsl <- adsl |>
  select(-N_ALT_AE, -N_NEURO_GI_AE) |>
  left_join(ae_terms, by = "USUBJID") |>
  replace_na(list(N_ALT_AE = 0L, N_NEURO_GI_AE = 0L))

write_csv(adsl, "data/adam/adsl.csv")
cat(sprintf("ADSL: %d subjects | Dropout rate: %.1f%%\n",
            nrow(adsl), mean(adsl$DPTFL == "Y") * 100))

# =============================================================================
# ADAE: ADVERSE EVENT ANALYSIS DATASET
# =============================================================================
adae <- ae |>
  left_join(adsl |> select(USUBJID, SITEID, TRT01P, TRT01PN, AGE, SEX, DPTFL, RFSTDTC),
            by = "USUBJID") |>
  mutate(
    DATASET = "ADAE",
    TRTEMFL = if_else(as.Date(AESTDTC) >= as.Date(RFSTDTC), "Y", "N")
  )

write_csv(adae, "data/adam/adae.csv")
cat(sprintf("ADAE: %d records written to data/adam/adae.csv\n", nrow(adae)))

cat("\nData generation complete. Files ready in data/sdtm/ and data/adam/\n")
cat("Next: Run R/train_model.R to train the dropout prediction model.\n")
