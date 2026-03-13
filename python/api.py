"""
Script   : api.py
Study    : NSVT-001 | NovaStat Therapeutics (FICTIONAL - AI-generated demo)
Purpose  : FastAPI REST API for patient dropout prediction.
           Exposes model predictions and SHAP explanations.
NOTE     : ALL DATA IS SYNTHETIC. For demonstration purposes only.
Run with : uv run uvicorn python.api:app --reload --host 0.0.0.0 --port 8000
"""

import os
import sys
from pathlib import Path
from datetime import datetime
from typing import Optional

import numpy as np
import pandas as pd
import joblib
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, validator

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))
from python.shap_utils import compute_shap_for_patient, format_shap_for_api, FEATURE_LABELS

# ============================================================
# FASTAPI APP
# ============================================================

app = FastAPI(
    title="NovaStat Clinical Intelligence API",
    description=(
        "**Patient Dropout Prediction API** for Study NSVT-001 "
        "(NovaStat Therapeutics, NST-4892 Phase 3 RA Trial).\n\n"
        "> **IMPORTANT**: This project contains synthetic data and analysis "
        "created for demonstration purposes only. All data is AI-generated. "
        "This is a fictional NovaStat Therapeutics demonstration — not real clinical data."
    ),
    version="1.0.0",
    contact={"name": "NovaStat Data Science", "email": "data-science@novastat-demo.com"},
    license_info={"name": "Internal Use Only"},
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# ============================================================
# LOAD MODEL AT STARTUP
# ============================================================

MODEL_DIR = Path("ml")
model     = None
metadata  = None

def load_model():
    global model, metadata
    model_path = MODEL_DIR / "dropout_model_py.pkl"
    meta_path  = MODEL_DIR / "model_metadata_py.pkl"

    if not model_path.exists():
        return False
    model    = joblib.load(model_path)
    metadata = joblib.load(meta_path) if meta_path.exists() else {}
    return True

model_loaded = load_model()

# ============================================================
# REQUEST / RESPONSE SCHEMAS
# ============================================================

class PatientFeatures(BaseModel):
    """Input features for a single patient dropout prediction."""

    AGE:            float = Field(..., ge=18, le=85,  description="Age in years",         example=52)
    SEXN:           int   = Field(..., ge=1,  le=2,   description="Sex: 1=Female, 2=Male", example=1)
    RACEN:          int   = Field(..., ge=1,  le=4,   description="Race code 1-4",         example=1)
    REGIONN:        int   = Field(..., ge=0,  le=2,   description="Region: 0=Americas, 1=Europe, 2=AsiaPac", example=0)
    DAS28BL:        float = Field(..., ge=2,  le=9.4, description="DAS28 score at baseline", example=5.8)
    BMIBL:          float = Field(..., ge=16, le=45,  description="BMI at baseline (kg/m2)", example=26.3)
    TRT01PN:        int   = Field(..., ge=0,  le=2,   description="Treatment: 0=Placebo, 1=100mg, 2=200mg", example=2)
    AENUM:          int   = Field(..., ge=0,  le=20,  description="Total adverse event count", example=4)
    AESNUM:         int   = Field(..., ge=0,  le=10,  description="Serious AE count",       example=1)
    AEMAXSEVN:      int   = Field(..., ge=0,  le=3,   description="Max AE severity: 0=None, 1=Mild, 2=Mod, 3=Severe", example=3)
    N_ALT_AE:       int   = Field(0,   ge=0,  le=5,   description="Count of ALT Increased AEs", example=1)
    N_NEURO_GI_AE:  int   = Field(0,   ge=0,  le=8,   description="Count of neuro/GI AEs",  example=2)
    COMPLPCT:       float = Field(..., ge=0,  le=100, description="Compliance % (doses taken)", example=71.0)
    N_MISSED_DOSES: int   = Field(0,   ge=0,  le=12,  description="Number of missed doses",   example=2)

    model_config = {
        "json_schema_extra": {
            "example": {
                "AGE": 58, "SEXN": 1, "RACEN": 1, "REGIONN": 1,
                "DAS28BL": 6.2, "BMIBL": 28.1, "TRT01PN": 2,
                "AENUM": 5, "AESNUM": 1, "AEMAXSEVN": 3,
                "N_ALT_AE": 1, "N_NEURO_GI_AE": 2,
                "COMPLPCT": 68.0, "N_MISSED_DOSES": 3,
            }
        }
    }


class BatchPredictionRequest(BaseModel):
    """Batch prediction for multiple patients."""
    patients: list[PatientFeatures] = Field(..., max_items=500)


class PredictionResponse(BaseModel):
    """Single-patient prediction response."""
    usubjid:            Optional[str]
    dropout_probability: float
    dropout_predicted:  bool
    risk_tier:          str
    explanation:        Optional[dict]
    disclaimer:         str = "Synthetic demonstration data only. Not for clinical use."


class HealthResponse(BaseModel):
    status:      str
    model_loaded: bool
    study:       str
    timestamp:   str


# ============================================================
# HELPER: risk tier
# ============================================================

def risk_tier(prob: float) -> str:
    if prob >= 0.60:  return "High Risk"
    if prob >= 0.35:  return "Moderate Risk"
    return "Low Risk"


# ============================================================
# ENDPOINTS
# ============================================================

@app.get("/health", response_model=HealthResponse, tags=["System"])
def health_check():
    """API health and model status check."""
    return HealthResponse(
        status       = "healthy" if model_loaded else "model_not_loaded",
        model_loaded = model_loaded,
        study        = "NSVT-001 (NovaStat Therapeutics - SYNTHETIC DATA)",
        timestamp    = datetime.utcnow().isoformat() + "Z",
    )


@app.get("/data", tags=["Data"])
def get_sample_data():
    """
    Return a sample of the ADSL dataset for exploration.
    Requires data/adam/adsl.csv to be generated first.
    """
    adsl_path = Path("data/adam/adsl.csv")
    if not adsl_path.exists():
        raise HTTPException(
            status_code=404,
            detail="ADSL not found. Run sas/generate_sdtm.sas and sas/create_adam.sas first."
        )

    df = pd.read_csv(adsl_path)
    sample = df.head(20).to_dict(orient="records")

    return {
        "study":        "NSVT-001",
        "disclaimer":   "Synthetic AI-generated data. Not real clinical data.",
        "n_subjects":   len(df),
        "dropout_rate": round(df["DPTFL"].eq("Y").mean() * 100, 1),
        "columns":      list(df.columns),
        "sample":       sample,
    }


@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
def predict_single(patient: PatientFeatures, explain: bool = True):
    """
    Predict dropout probability for a single patient.
    Set `explain=true` to include SHAP feature contributions.
    """
    if not model_loaded:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Run python/train_model.py first."
        )

    features = patient.dict()
    X = pd.DataFrame([features])

    try:
        prob = float(model.predict_proba(X)[0, 1])
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {e}")

    explanation = None
    if explain:
        try:
            shap_result = compute_shap_for_patient(features, model)
            explanation = format_shap_for_api(shap_result)["explanation"]
        except Exception:
            explanation = {"note": "SHAP explanation unavailable for this model type."}

    return PredictionResponse(
        usubjid             = None,
        dropout_probability = round(prob, 4),
        dropout_predicted   = prob >= 0.50,
        risk_tier           = risk_tier(prob),
        explanation         = explanation,
    )


@app.post("/predict/batch", tags=["Prediction"])
def predict_batch(request: BatchPredictionRequest):
    """
    Batch prediction for up to 500 patients.
    Returns dropout probabilities and risk tiers (no SHAP for batch).
    """
    if not model_loaded:
        raise HTTPException(status_code=503, detail="Model not loaded.")

    records = [p.dict() for p in request.patients]
    X = pd.DataFrame(records)

    try:
        probs = model.predict_proba(X)[:, 1]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Batch prediction failed: {e}")

    results = [
        {
            "index":               i,
            "dropout_probability": round(float(p), 4),
            "dropout_predicted":   float(p) >= 0.50,
            "risk_tier":           risk_tier(float(p)),
        }
        for i, p in enumerate(probs)
    ]

    return {
        "n_patients":       len(results),
        "n_high_risk":      sum(r["risk_tier"] == "High Risk" for r in results),
        "n_moderate_risk":  sum(r["risk_tier"] == "Moderate Risk" for r in results),
        "n_low_risk":       sum(r["risk_tier"] == "Low Risk" for r in results),
        "mean_dropout_prob": round(float(probs.mean()), 4),
        "predictions":      results,
        "disclaimer":       "Synthetic demonstration data only.",
    }


@app.get("/model-info", tags=["System"])
def model_info():
    """Return model metadata, performance metrics, and feature descriptions."""
    if not model_loaded:
        raise HTTPException(status_code=503, detail="Model not loaded.")

    return {
        "study":       metadata.get("study", "NSVT-001"),
        "sponsor":     metadata.get("sponsor", "NovaStat Therapeutics"),
        "drug":        metadata.get("drug", "NST-4892"),
        "target":      metadata.get("target", "Patient dropout"),
        "best_model":  metadata.get("best_model"),
        "performance": {
            "roc_auc":  metadata.get("roc_auc"),
            "accuracy": metadata.get("accuracy"),
            "f1_score": metadata.get("f1"),
        },
        "model_comparison": {
            "random_forest": metadata.get("rf_metrics"),
            "xgboost":       metadata.get("xgb_metrics"),
        },
        "features": {
            k: v for k, v in FEATURE_LABELS.items()
        },
        "training_set_size": metadata.get("n_train"),
        "test_set_size":     metadata.get("n_test"),
        "disclaimer":        metadata.get("disclaimer",
                               "SYNTHETIC DATA - AI-generated for demonstration only"),
    }
