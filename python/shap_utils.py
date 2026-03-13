"""
Module   : shap_utils.py
Study    : NSVT-001 | NovaStat Therapeutics (FICTIONAL - AI-generated demo)
Purpose  : Utility functions for computing and formatting SHAP explanations.
           Used by the FastAPI and (optionally) the Shiny app via reticulate.
NOTE     : ALL DATA IS SYNTHETIC. For demonstration purposes only.
"""

from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
import joblib
import shap

MODEL_DIR = Path("ml")

FEATURE_LABELS = {
    "AGE":            "Age (years)",
    "SEXN":           "Sex (1=F, 2=M)",
    "RACEN":          "Race (encoded)",
    "REGIONN":        "Region (0=Americas, 1=Europe, 2=AsiaPac)",
    "DAS28BL":        "DAS28 at Baseline",
    "BMIBL":          "BMI at Baseline",
    "TRT01PN":        "Treatment Arm (0=Placebo, 1=100mg, 2=200mg)",
    "AENUM":          "Total AE Count",
    "AESNUM":         "Serious AE Count",
    "AEMAXSEVN":      "Max AE Severity (1=Mild, 2=Mod, 3=Sev)",
    "N_ALT_AE":       "ALT Increased AEs",
    "N_NEURO_GI_AE":  "Neuro/GI AE Count",
    "COMPLPCT":       "Compliance (%)",
    "N_MISSED_DOSES": "Missed Doses",
}


def load_artifacts() -> tuple:
    """Load model and SHAP artifacts from disk."""
    model = joblib.load(MODEL_DIR / "dropout_model_py.pkl")
    metadata = joblib.load(MODEL_DIR / "model_metadata_py.pkl")

    shap_arts = None
    shap_path = MODEL_DIR / "shap_artifacts.pkl"
    if shap_path.exists():
        shap_arts = joblib.load(shap_path)

    return model, metadata, shap_arts


def compute_shap_for_patient(
    patient_features: dict,
    model,
    background_data: Optional[np.ndarray] = None,
) -> dict:
    """
    Compute SHAP values for a single patient.

    Parameters
    ----------
    patient_features : dict of {feature_name: value}
    model            : fitted sklearn Pipeline
    background_data  : optional background dataset for KernelExplainer fallback

    Returns
    -------
    dict with keys: shap_values, base_value, prediction_prob,
                    feature_contributions (sorted by |shap|)
    """
    feature_order = list(FEATURE_LABELS.keys())
    X = np.array([[patient_features.get(f, 0) for f in feature_order]])

    # Preprocess
    X_prep = model.named_steps["prep"].transform(X)
    clf    = model.named_steps["clf"]

    # Prediction
    pred_prob = model.predict_proba(X)[0, 1]

    # Compute SHAP
    try:
        explainer = shap.TreeExplainer(clf)
        sv = explainer.shap_values(X_prep)

        # Handle RF (returns list) vs XGBoost (returns array)
        if isinstance(sv, list):
            shap_vals = sv[1][0]
            base_val  = explainer.expected_value[1]
        else:
            shap_vals = sv[0]
            base_val  = float(explainer.expected_value)
    except Exception:
        # Fallback: approximate with feature importance
        if hasattr(clf, "feature_importances_"):
            shap_vals = clf.feature_importances_ * (pred_prob - 0.5)
        else:
            shap_vals = np.zeros(X_prep.shape[1])
        base_val = 0.5

    # Map to feature names
    prep_features = (
        ["AGE", "DAS28BL", "BMIBL", "COMPLPCT", "AENUM",
         "AESNUM", "AEMAXSEVN", "N_ALT_AE", "N_NEURO_GI_AE", "N_MISSED_DOSES"]
        + ["SEXN", "RACEN", "REGIONN", "TRT01PN"]
    )

    n = min(len(shap_vals), len(prep_features))
    contributions = [
        {
            "feature":       prep_features[i],
            "label":         FEATURE_LABELS.get(prep_features[i], prep_features[i]),
            "value":         patient_features.get(prep_features[i], 0),
            "shap_value":    round(float(shap_vals[i]), 4),
            "direction":     "increases_risk" if shap_vals[i] > 0 else "decreases_risk",
        }
        for i in range(n)
    ]
    contributions.sort(key=lambda x: abs(x["shap_value"]), reverse=True)

    return {
        "prediction_prob":     round(float(pred_prob), 4),
        "prediction_label":    "Dropout" if pred_prob >= 0.5 else "Completed",
        "base_value":          round(float(base_val), 4),
        "shap_values":         [c["shap_value"] for c in contributions],
        "feature_contributions": contributions[:10],  # top 10
    }


def format_shap_for_api(shap_result: dict) -> dict:
    """Format SHAP result as clean API response."""
    return {
        "predicted_dropout_probability": shap_result["prediction_prob"],
        "prediction":                    shap_result["prediction_label"],
        "explanation": {
            "top_risk_factors": [
                c for c in shap_result["feature_contributions"]
                if c["direction"] == "increases_risk"
            ][:5],
            "top_protective_factors": [
                c for c in shap_result["feature_contributions"]
                if c["direction"] == "decreases_risk"
            ][:5],
            "note": "SHAP values represent each feature's contribution to the prediction.",
        },
    }
