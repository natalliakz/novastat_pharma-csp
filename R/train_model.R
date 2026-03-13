# =============================================================================
# SCRIPT   : train_model.R
# STUDY    : NSVT-001 | NovaStat Therapeutics (FICTIONAL - AI-generated demo)
# PURPOSE  : Train patient dropout prediction model using tidymodels
#            Random Forest + XGBoost; saves model for Shiny app and vetiver
# NOTE     : ALL DATA IS SYNTHETIC. For demonstration purposes only.
# =============================================================================

library(tidymodels)
library(tidyverse)
library(vip)
library(vetiver)

set.seed(42)

# --- Load data ---
adsl_path <- "data/adam/adsl.csv"
if (!file.exists(adsl_path)) {
  stop("ADSL not found. Run sas/generate_sdtm.sas then sas/create_adam.sas first.")
}
adsl <- read_csv(adsl_path, show_col_types = FALSE)

message(sprintf("Loaded ADSL: %d subjects | Dropout rate: %.1f%%",
                nrow(adsl), mean(adsl$DPTFL == "Y") * 100))

# =============================================================================
# FEATURE SELECTION
# ML features matching clinical predictors used in pharma dropout studies
# =============================================================================

model_data <- adsl |>
  filter(ITTFL == "Y") |>
  select(
    # Target
    DPTFL,
    # Demographics
    AGE, SEXN, RACEN, REGIONN,
    # Disease characteristics
    DAS28BL, BMIBL, TRT01PN,
    # AE burden (primary drivers of dropout)
    AENUM, AESNUM, AEMAXSEVN, N_ALT_AE, N_NEURO_GI_AE,
    # Compliance
    COMPLPCT, N_MISSED_DOSES
  ) |>
  mutate(
    DPTFL   = factor(DPTFL, levels = c("N", "Y")),
    SEXN    = factor(SEXN),
    RACEN   = factor(RACEN),
    REGIONN = factor(REGIONN),
    TRT01PN = factor(TRT01PN)
  ) |>
  drop_na()

message(sprintf("Model dataset: %d subjects | %d features", nrow(model_data), ncol(model_data) - 1))

# =============================================================================
# TRAIN / TEST SPLIT (70/30, stratified by outcome)
# =============================================================================

split  <- initial_split(model_data, prop = 0.70, strata = DPTFL)
train  <- training(split)
test   <- testing(split)

message(sprintf("Train: %d | Test: %d | Train dropout rate: %.1f%%",
                nrow(train), nrow(test), mean(train$DPTFL == "Y") * 100))

# 5-fold CV for model selection
folds <- vfold_cv(train, v = 5, strata = DPTFL)

# =============================================================================
# PREPROCESSING RECIPE
# =============================================================================

rec <- recipe(DPTFL ~ ., data = train) |>
  step_impute_median(all_numeric_predictors()) |>
  step_normalize(AGE, DAS28BL, BMIBL, COMPLPCT, AENUM, AESNUM, AEMAXSEVN,
                 N_ALT_AE, N_NEURO_GI_AE, N_MISSED_DOSES) |>
  step_dummy(SEXN, RACEN, REGIONN, TRT01PN, one_hot = FALSE)

# =============================================================================
# MODEL 1: RANDOM FOREST
# =============================================================================

rf_spec <- rand_forest(
  mtry  = tune(),
  trees = 500,
  min_n = tune()
) |>
  set_engine("ranger", importance = "impurity", seed = 42) |>
  set_mode("classification")

rf_wf <- workflow() |>
  add_recipe(rec) |>
  add_model(rf_spec)

rf_grid <- grid_regular(
  mtry(range = c(2, 8)),
  min_n(range = c(5, 25)),
  levels = 3
)

message("Tuning Random Forest (5-fold CV)...")
rf_res <- tune_grid(
  rf_wf,
  resamples = folds,
  grid      = rf_grid,
  metrics   = metric_set(roc_auc, accuracy, f_meas),
  control   = control_grid(save_pred = TRUE, verbose = FALSE)
)

rf_best <- select_best(rf_res, metric = "roc_auc")
message(sprintf("Best RF: mtry=%d, min_n=%d", rf_best$mtry, rf_best$min_n))

rf_final_wf <- finalize_workflow(rf_wf, rf_best)
rf_fit      <- last_fit(rf_final_wf, split)

# =============================================================================
# MODEL 2: XGBOOST
# =============================================================================

xgb_spec <- boost_tree(
  trees          = tune(),
  tree_depth     = tune(),
  learn_rate     = tune(),
  loss_reduction = tune()
) |>
  set_engine("xgboost", seed = 42) |>
  set_mode("classification")

xgb_wf <- workflow() |>
  add_recipe(rec) |>
  add_model(xgb_spec)

xgb_grid <- grid_latin_hypercube(
  trees(range = c(100, 500)),
  tree_depth(range = c(3, 7)),
  learn_rate(range = c(-3, -1)),
  loss_reduction(range = c(-5, 0)),
  size = 15
)

message("Tuning XGBoost (5-fold CV)...")
xgb_res <- tune_grid(
  xgb_wf,
  resamples = folds,
  grid      = xgb_grid,
  metrics   = metric_set(roc_auc, accuracy, f_meas),
  control   = control_grid(save_pred = TRUE, verbose = FALSE)
)

xgb_best    <- select_best(xgb_res, metric = "roc_auc")
xgb_final_wf <- finalize_workflow(xgb_wf, xgb_best)
xgb_fit     <- last_fit(xgb_final_wf, split)

# =============================================================================
# COMPARE MODELS ON TEST SET
# =============================================================================

rf_metrics  <- collect_metrics(rf_fit)
xgb_metrics <- collect_metrics(xgb_fit)

comparison <- bind_rows(
  rf_metrics  |> mutate(model = "Random Forest"),
  xgb_metrics |> mutate(model = "XGBoost")
) |>
  select(model, .metric, .estimate) |>
  pivot_wider(names_from = .metric, values_from = .estimate)

message("\n--- Model Comparison (Test Set) ---")
print(comparison)

# Select best model by ROC AUC
best_model_name <- comparison |>
  slice_max(roc_auc) |>
  pull(model)

best_fit <- if (best_model_name == "XGBoost") xgb_fit else rf_fit
best_wf  <- if (best_model_name == "XGBoost") xgb_final_wf else rf_final_wf

message(sprintf("\nBest model: %s (AUC = %.3f)",
                best_model_name,
                comparison |> slice_max(roc_auc) |> pull(roc_auc)))

# =============================================================================
# FIT FINAL MODEL ON FULL TRAINING DATA
# =============================================================================

final_model <- fit(best_wf, data = train)

# =============================================================================
# VARIABLE IMPORTANCE
# =============================================================================

if (best_model_name == "Random Forest") {
  vip_plot <- final_model |>
    extract_fit_parsnip() |>
    vip(num_features = 12, geom = "col", aesthetics = list(fill = "#1B4F8A")) +
    labs(title = "Random Forest - Variable Importance",
         subtitle = "NSVT-001 Patient Dropout Prediction") +
    theme_minimal()
} else {
  vip_plot <- final_model |>
    extract_fit_parsnip() |>
    vip(num_features = 12, geom = "col", aesthetics = list(fill = "#1B4F8A")) +
    labs(title = "XGBoost - Variable Importance",
         subtitle = "NSVT-001 Patient Dropout Prediction") +
    theme_minimal()
}
print(vip_plot)

# =============================================================================
# SAVE MODEL (vetiver for Posit Connect deployment)
# =============================================================================

dir.create("ml", showWarnings = FALSE)

# Save as vetiver model
v_model <- vetiver_model(
  model   = final_model,
  model_name = "nsvt001-dropout-model",
  description = paste(best_model_name, "model for NSVT-001 patient dropout prediction"),
  metadata = list(
    study    = "NSVT-001",
    sponsor  = "NovaStat Therapeutics",
    drug     = "NST-4892",
    target   = "Patient dropout (DPTFL=Y)",
    auc      = comparison |> slice_max(roc_auc) |> pull(roc_auc),
    features = names(select(model_data, -DPTFL)),
    disclaimer = "SYNTHETIC DATA - AI-generated for demonstration only"
  )
)

saveRDS(final_model, "ml/dropout_model.rds")
saveRDS(v_model,     "ml/vetiver_model.rds")
saveRDS(comparison,  "ml/model_comparison.rds")
saveRDS(split,       "ml/train_test_split.rds")
saveRDS(rec |> prep(), "ml/recipe.rds")

message(sprintf("\nModel saved to ml/dropout_model.rds"))
message(sprintf("Vetiver model saved to ml/vetiver_model.rds"))

# =============================================================================
# ROC CURVE
# =============================================================================

roc_data <- collect_predictions(best_fit)
roc_auc_val <- roc_auc(roc_data, truth = DPTFL, .pred_Y, event_level = "second")$.estimate

roc_curve(roc_data, truth = DPTFL, .pred_Y) |>
  autoplot() +
  labs(
    title    = paste(best_model_name, "- ROC Curve (Test Set)"),
    subtitle = sprintf("AUC = %.3f | Study NSVT-001 - Patient Dropout Prediction", roc_auc_val)
  ) +
  theme_minimal()

message(sprintf("\nTraining complete. Final model AUC: %.3f", roc_auc_val))
message("Run R/app.R to launch the interactive dashboard.")
