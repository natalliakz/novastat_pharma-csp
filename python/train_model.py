"""
Script   : train_model.py
Study    : NSVT-001 | NovaStat Therapeutics (FICTIONAL - AI-generated demo)
Purpose  : Train patient dropout prediction model using scikit-learn and XGBoost.
           Computes SHAP values; saves model and artifacts for FastAPI.
NOTE     : ALL DATA IS SYNTHETIC. For demonstration purposes only.
"""

import sys
import os
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns
import shap
import joblib

from sklearn.model_selection import train_test_split, GridSearchCV, StratifiedKFold
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.impute import SimpleImputer
from sklearn.compose import ColumnTransformer
from sklearn.metrics import (
    roc_auc_score, accuracy_score, f1_score,
    classification_report, roc_curve, ConfusionMatrixDisplay
)
from xgboost import XGBClassifier

warnings.filterwarnings("ignore")

# ============================================================
# CONFIG
# ============================================================

RANDOM_STATE = 42
MODEL_DIR    = Path("ml")
DATA_PATH    = Path("data/adam/adsl.csv")

FEATURE_COLS = [
    "AGE", "SEXN", "RACEN", "REGIONN",
    "DAS28BL", "BMIBL", "TRT01PN",
    "AENUM", "AESNUM", "AEMAXSEVN", "N_ALT_AE", "N_NEURO_GI_AE",
    "COMPLPCT", "N_MISSED_DOSES"
]
TARGET_COL = "DPTN"   # 1=dropout, 0=completed

NUMERIC_FEATURES     = ["AGE", "DAS28BL", "BMIBL", "COMPLPCT", "AENUM",
                         "AESNUM", "AEMAXSEVN", "N_ALT_AE", "N_NEURO_GI_AE", "N_MISSED_DOSES"]
CATEGORICAL_FEATURES = ["SEXN", "RACEN", "REGIONN", "TRT01PN"]

# ============================================================
# LOAD DATA
# ============================================================

print("=" * 60)
print("NovaStat NSVT-001 - Python ML Training")
print("NOTE: All data is AI-generated - for demonstration only")
print("=" * 60)

if not DATA_PATH.exists():
    sys.exit(
        f"ERROR: {DATA_PATH} not found.\n"
        "Run sas/generate_sdtm.sas and sas/create_adam.sas first."
    )

df = pd.read_csv(DATA_PATH)
print(f"\nLoaded ADSL: {len(df)} subjects | "
      f"Dropout rate: {df['DPTFL'].eq('Y').mean()*100:.1f}%")

# Prepare model data
model_df = (
    df[df["ITTFL"] == "Y"]
    .assign(DPTN=lambda x: (x["DPTFL"] == "Y").astype(int))
    [FEATURE_COLS + [TARGET_COL]]
    .dropna()
)
print(f"Model dataset: {len(model_df)} subjects | "
      f"Dropout rate: {model_df[TARGET_COL].mean()*100:.1f}%")

X = model_df[FEATURE_COLS]
y = model_df[TARGET_COL]

# ============================================================
# TRAIN / TEST SPLIT
# ============================================================

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.30, random_state=RANDOM_STATE, stratify=y
)
print(f"\nTrain: {len(X_train)} | Test: {len(X_test)} | "
      f"Train dropout rate: {y_train.mean()*100:.1f}%")

# ============================================================
# PREPROCESSING PIPELINE
# ============================================================

numeric_pipeline = Pipeline([
    ("imputer", SimpleImputer(strategy="median")),
    ("scaler",  StandardScaler()),
])

categorical_pipeline = Pipeline([
    ("imputer", SimpleImputer(strategy="most_frequent")),
])

preprocessor = ColumnTransformer([
    ("num", numeric_pipeline,     NUMERIC_FEATURES),
    ("cat", categorical_pipeline, CATEGORICAL_FEATURES),
])

cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE)

# ============================================================
# MODEL 1: RANDOM FOREST
# ============================================================

print("\nTraining Random Forest (GridSearch CV=5)...")
rf_pipe = Pipeline([
    ("prep", preprocessor),
    ("clf",  RandomForestClassifier(random_state=RANDOM_STATE, n_jobs=-1, class_weight="balanced"))
])

rf_grid = GridSearchCV(
    rf_pipe,
    param_grid={"clf__n_estimators": [200, 400], "clf__max_depth": [4, 6, None],
                "clf__min_samples_leaf": [5, 10]},
    cv=cv, scoring="roc_auc", n_jobs=-1, verbose=0
)
rf_grid.fit(X_train, y_train)

rf_best  = rf_grid.best_estimator_
rf_probs = rf_best.predict_proba(X_test)[:, 1]
rf_preds = rf_best.predict(X_test)

rf_metrics = {
    "model":    "Random Forest",
    "roc_auc":  round(roc_auc_score(y_test, rf_probs), 4),
    "accuracy": round(accuracy_score(y_test, rf_preds), 4),
    "f1":       round(f1_score(y_test, rf_preds), 4),
}
print(f"  RF  AUC={rf_metrics['roc_auc']:.3f} | ACC={rf_metrics['accuracy']:.3f} | "
      f"F1={rf_metrics['f1']:.3f}")

# ============================================================
# MODEL 2: XGBOOST
# ============================================================

print("\nTraining XGBoost (GridSearch CV=5)...")
xgb_pipe = Pipeline([
    ("prep", preprocessor),
    ("clf",  XGBClassifier(random_state=RANDOM_STATE, eval_metric="logloss",
                           use_label_encoder=False, n_jobs=-1))
])

xgb_grid = GridSearchCV(
    xgb_pipe,
    param_grid={"clf__n_estimators": [200, 400], "clf__max_depth": [3, 5, 7],
                "clf__learning_rate": [0.05, 0.1], "clf__subsample": [0.8, 1.0]},
    cv=cv, scoring="roc_auc", n_jobs=-1, verbose=0
)
xgb_grid.fit(X_train, y_train)

xgb_best  = xgb_grid.best_estimator_
xgb_probs = xgb_best.predict_proba(X_test)[:, 1]
xgb_preds = xgb_best.predict(X_test)

xgb_metrics = {
    "model":    "XGBoost",
    "roc_auc":  round(roc_auc_score(y_test, xgb_probs), 4),
    "accuracy": round(accuracy_score(y_test, xgb_preds), 4),
    "f1":       round(f1_score(y_test, xgb_preds), 4),
}
print(f"  XGB AUC={xgb_metrics['roc_auc']:.3f} | ACC={xgb_metrics['accuracy']:.3f} | "
      f"F1={xgb_metrics['f1']:.3f}")

# ============================================================
# SELECT BEST MODEL
# ============================================================

best_metrics = max([rf_metrics, xgb_metrics], key=lambda m: m["roc_auc"])
best_model   = rf_best if best_metrics["model"] == "Random Forest" else xgb_best
best_probs   = rf_probs if best_metrics["model"] == "Random Forest" else xgb_probs

print(f"\nBest model: {best_metrics['model']} (AUC = {best_metrics['roc_auc']:.3f})")

# ============================================================
# SHAP VALUES (on test set sample)
# ============================================================

print("\nComputing SHAP values...")

# Get preprocessed test data for SHAP
X_test_prep = best_model.named_steps["prep"].transform(X_test)
feature_names_out = (
    NUMERIC_FEATURES
    + CATEGORICAL_FEATURES  # after passthrough
)

try:
    if best_metrics["model"] == "XGBoost":
        explainer    = shap.TreeExplainer(best_model.named_steps["clf"])
        shap_values  = explainer.shap_values(X_test_prep)
        expected_val = explainer.expected_value
    else:
        explainer    = shap.TreeExplainer(best_model.named_steps["clf"])
        shap_values  = explainer.shap_values(X_test_prep)[1]  # class 1 (dropout)
        expected_val = explainer.expected_value[1]

    shap_computed = True
    print("  SHAP values computed successfully.")
except Exception as e:
    shap_computed = False
    shap_values   = None
    expected_val  = None
    print(f"  SHAP skipped: {e}")

# ============================================================
# SAVE ARTIFACTS
# ============================================================

MODEL_DIR.mkdir(exist_ok=True)

joblib.dump(best_model,   MODEL_DIR / "dropout_model_py.pkl")
joblib.dump(preprocessor, MODEL_DIR / "preprocessor.pkl")

# Save metadata
metadata = {
    "study":        "NSVT-001",
    "sponsor":      "NovaStat Therapeutics",
    "drug":         "NST-4892",
    "target":       "Patient dropout (DPTN=1)",
    "best_model":   best_metrics["model"],
    "roc_auc":      best_metrics["roc_auc"],
    "accuracy":     best_metrics["accuracy"],
    "f1":           best_metrics["f1"],
    "features":     FEATURE_COLS,
    "n_train":      len(X_train),
    "n_test":       len(X_test),
    "rf_metrics":   rf_metrics,
    "xgb_metrics":  xgb_metrics,
    "disclaimer":   "SYNTHETIC DATA - AI-generated for demonstration only",
}
joblib.dump(metadata, MODEL_DIR / "model_metadata_py.pkl")

if shap_computed:
    joblib.dump({
        "shap_values":   shap_values,
        "expected_value": expected_val,
        "feature_names": feature_names_out,
        "X_test_prep":   X_test_prep,
    }, MODEL_DIR / "shap_artifacts.pkl")
    print(f"SHAP artifacts saved to {MODEL_DIR}/shap_artifacts.pkl")

print(f"\nModel saved to {MODEL_DIR}/dropout_model_py.pkl")

# ============================================================
# PRINT CLASSIFICATION REPORT
# ============================================================

print(f"\n--- {best_metrics['model']} Classification Report (Test Set) ---")
print(classification_report(
    y_test, best_model.predict(X_test),
    target_names=["Completed", "Dropout"]
))

print("Training complete.")
print("Start the API with: cd novastat_pharma-csp && uv run uvicorn python.api:app --reload")
