# NovaStat Clinical Intelligence Platform

A demonstration project showcasing Posit's data science tools for pharmaceutical Clinical Statistical Programming (CSP). This project simulates a Phase 3 clinical trial (NSVT-001) for rheumatoid arthritis treatment, featuring SAS data pipelines, machine learning predictions, interactive dashboards, and RESTful APIs.

## Project Overview

**Fictional Company**: NovaStat Therapeutics
**Study**: NSVT-001 (NST-4892 Phase 3 RA Trial)
**Language**: R (primary) + Python (API)

This demonstration includes:

- **SDTM/ADaM Data Generation**: SAS scripts (via Altair SLC) for CDISC-compliant clinical trial data
- **Machine Learning**: Patient dropout prediction using Random Forest/XGBoost
- **Interactive Dashboard**: R Shiny application for clinical site monitoring and risk assessment
- **REST API**: FastAPI service for programmatic access to dropout predictions
- **Validation Report**: Quarto document for GxP audit trail and environment traceability

## Project Structure

```
novastat_pharma-csp/
├── data/
│   ├── adam/                    # ADaM analysis datasets (ADSL, ADAE)
│   └── sdtm/                    # SDTM domain datasets (DM, AE, EX, DS)
├── ml/                          # Trained ML models and artifacts
├── python/
│   ├── api.py                   # FastAPI prediction service
│   ├── train_model.py           # Python model training script
│   └── shap_utils.py            # SHAP explainability utilities
├── quarto/
│   └── validation_report.qmd    # GxP validation and audit report
├── R/
│   ├── app.R                    # Shiny Clinical Intelligence Hub
│   ├── train_model.R            # R model training (tidymodels)
│   ├── bridge.R                 # SAS-R data bridge utilities
│   └── generate_data_fallback.R # R-based data generation fallback
├── sas/
│   ├── generate_sdtm.sas        # SDTM domain generation
│   ├── create_adam.sas          # ADaM derivation
│   ├── cdisc_validation.sas     # CDISC compliance checks
│   └── tfl/                     # Tables, Figures, Listings
├── _brand.yml                   # Brand configuration for theming
├── renv.lock                    # R package versions (reproducibility)
├── pyproject.toml               # Python dependencies
└── uv.lock                      # Python lockfile
```

## Getting Started

### Prerequisites

- R 4.4+ with `renv`
- Python 3.11+ with `uv`
- Quarto CLI
- (Optional) Altair SLC for SAS execution

### Installation

1. **Clone and navigate to the project**:
   ```bash
   cd novastat_pharma-csp
   ```

2. **Restore R environment**:
   ```r
   renv::restore()
   ```

3. **Set up Python environment**:
   ```bash
   uv sync
   ```

### Generate Synthetic Data

If data files don't exist, generate them using one of these methods:

**Option A: SAS via Altair SLC** (recommended for full demo):
```sas
%include "sas/generate_sdtm.sas";
%include "sas/create_adam.sas";
```

**Option B: R fallback** (if SAS is unavailable):
```r
source("R/generate_data_fallback.R")
```

### Train ML Models

**R (tidymodels)**:
```r
source("R/train_model.R")
```

**Python (scikit-learn)**:
```bash
uv run python python/train_model.py
```

## Running the Applications

### Shiny Dashboard

```r
shiny::runApp("R/app.R")
```

The Clinical Intelligence Hub provides:
- Site-level KPI monitoring
- Patient dropout risk predictions
- SHAP-based model explainability
- Natural language query (powered by ellmer)

### FastAPI Service

```bash
uv run uvicorn python.api:app --reload --host 0.0.0.0 --port 8000
```

Access the API documentation at `http://localhost:8000/docs`

### Validation Report

```bash
quarto render quarto/validation_report.qmd
```

## Customizing with Brand.yml

The `_brand.yml` file controls visual theming across Shiny apps and Quarto documents. Modify colors, fonts, and styling to match your organization:

```yaml
color:
  primary: "#1B4F8A"
  secondary: "#4A5568"
  # ... customize as needed

typography:
  base:
    family: Source Sans Pro
```

Both the Shiny app and Quarto report automatically apply these brand settings.

## Extending This Project

Use this demonstration as a foundation for your own clinical analytics projects:

1. **Replace synthetic data** with your actual trial data (following CDISC standards)
2. **Customize the ML model** features for your specific dropout predictors
3. **Extend the API** with additional endpoints (e.g., efficacy predictions, safety signals)
4. **Add new dashboard panels** for trial-specific KPIs
5. **Integrate with Posit Connect** for enterprise deployment

## Important Disclaimer

**This project contains synthetic data and analysis created for demonstration purposes only.**

All data, insights, business scenarios, and analytics presented in this demonstration project have been artificially generated using AI. The data does not represent actual business information, performance metrics, customer data, or operational statistics.

### Key Points:

- **Synthetic Data**: All datasets are computer-generated and designed to illustrate analytical capabilities
- **Illustrative Analysis**: Insights and recommendations are examples of the types of analysis possible with Posit tools
- **No Actual Business Data**: No real business information or data was used or accessed in creating this demonstration
- **Educational Purpose**: This project serves as a technical demonstration of data science workflows and reporting capabilities
- **AI-Generated Content**: Analysis, commentary, and business scenarios were created by AI for illustration purposes
- **No Real-World Implications**: The scenarios and insights presented should not be interpreted as actual business advice or strategies

This demonstration showcases how Posit's data science platform and open-source tools can be applied to the pharmaceutical industry. The synthetic data and analysis provide a foundation for understanding the potential value of implementing similar analytical workflows with actual business data.

For questions about adapting these techniques to your real business scenarios, please contact your Posit representative.

---

*This demonstration was created using Posit's commercial data science tools and open-source packages. All synthetic data and analysis are provided for evaluation purposes only.*
