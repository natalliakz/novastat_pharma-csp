# NovaStat CSP Demo - Posit Internal Guide

**Customer/Prospect**: Pharmaceutical / Life Sciences (Clinical Statistical Programming)
**Demo Duration**: 20-30 minutes
**Last Updated**: March 2026

## Quick Start (5 minutes)

```bash
# 1. Navigate to project
cd novastat_pharma-csp

# 2. Restore R packages
Rscript -e "renv::restore()"

# 3. Sync Python environment
uv sync

# 4. Verify data exists (should see CSV files)
ls data/adam/ data/sdtm/

# 5. Launch Shiny app
Rscript -e "shiny::runApp('R/app.R')"
```

## Industry Context

**Clinical Statistical Programming (CSP)** teams in pharma are responsible for:
- Generating analysis datasets from raw clinical trial data (SDTM → ADaM)
- Producing Tables, Figures, and Listings (TFLs) for regulatory submissions
- Ensuring reproducibility and audit trails for FDA/EMA compliance
- Supporting biostatistics with validated analytical environments

**Key Pain Points** this demo addresses:
1. SAS-centric workflows limiting collaboration with data scientists
2. Lack of interactive exploration tools for clinical monitors
3. Manual, error-prone processes for identifying at-risk patients
4. No ML-powered predictive capabilities for trial operations

## Data Overview

This demo simulates **Study NSVT-001**, a Phase 3 trial for NST-4892 (rheumatoid arthritis treatment):

| Dataset | Description | Key Variables |
|---------|-------------|---------------|
| `data/sdtm/dm.csv` | Demographics | USUBJID, AGE, SEX, RACE, COUNTRY |
| `data/sdtm/ae.csv` | Adverse Events | AEDECOD, AESEV, AESER |
| `data/sdtm/ex.csv` | Exposure | EXTRT, EXDOSE, EXSTDTC |
| `data/sdtm/ds.csv` | Disposition | DSDECOD (COMPLETED, DISCONTINUED) |
| `data/adam/adsl.csv` | Subject-Level Analysis | TRT01P, DPTFL (dropout flag), DAS28BL |
| `data/adam/adae.csv` | AE Analysis | AOCCFL, AESEVN |

**Note**: All data is synthetic and AI-generated. ~500 subjects across 12 sites in 4 countries.

## Demo Script

### Opening (2 min)

> "Today I'll show you how Posit tools can modernize your CSP workflows. We've built a demo for a fictional Phase 3 RA trial that showcases three key capabilities: SAS integration, ML-powered patient monitoring, and interactive clinical dashboards."

### Part 1: Shiny Clinical Intelligence Hub (10 min)

Launch the app: `shiny::runApp('R/app.R')`

**Tab 1 - Site Overview**:
- Show KPI cards (total subjects, dropout rate, compliance, AE count)
- Filter by site/treatment arm to show real-time updates
- Highlight: "Clinical operations teams can monitor site performance without requesting custom reports"

**Tab 2 - Patient Risk**:
- Click "Run Predictions" to score patients
- Show risk tier filtering (High/Moderate/Low)
- Export capability for site management follow-up
- Highlight: "ML model identifies patients at risk of dropout before it happens"

**Tab 3 - Model Explainability**:
- Show global feature importance (SHAP)
- Select a high-risk patient for individual explanation
- Highlight: "Regulatory teams can audit WHY a prediction was made"

**Tab 4 - AI Query** (if ellmer configured):
- Type: "Which sites in Germany have dropout rates above 30%?"
- Highlight: "Natural language interface democratizes data access"

### Part 2: Validation Report (5 min)

Open `quarto/validation_report.html` in browser.

Key talking points:
- "This Quarto report provides the audit trail regulators require"
- Show CDISC validation checks table (all PASS)
- Show environment snapshot (package versions)
- "Everything needed for 21 CFR Part 11 compliance documentation"

### Part 3: API for Integration (3 min)

Start API: `uv run uvicorn python.api:app --reload --port 8000`

Open `http://localhost:8000/docs`:
- Show Swagger documentation (auto-generated)
- Demo `/predict` endpoint with sample patient
- "Your CTMS or EDC systems can call this API directly"

### Closing (2 min)

> "What we've shown today is a complete analytical platform that:
> 1. Integrates with your existing SAS workflows
> 2. Adds ML capabilities without replacing your validated processes
> 3. Provides interactive tools for clinical operations
> 4. Maintains the audit trails your regulatory teams need
>
> This is built on Posit Workbench, deployed to Posit Connect, with dependencies managed by Posit Package Manager."

## Key Talking Points

**For IT/Infrastructure**:
- renv.lock + uv.lock ensure reproducibility across environments
- Posit Package Manager can serve validated package snapshots
- Everything deploys to Posit Connect with one click

**For Biostatistics**:
- tidymodels workflow mirrors familiar SAS PROC modeling
- SHAP explanations support FDA requests for model interpretability
- Quarto replaces manual Word/PDF report generation

**For Clinical Operations**:
- Real-time dashboards vs. static monthly reports
- Proactive patient intervention based on ML predictions
- Self-service site filtering without programmer support

**For Regulatory/Quality**:
- Full environment traceability in validation report
- Immutable deployment versions on Posit Connect
- Audit-ready documentation generated automatically

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "renv out of sync" warning | Run `renv::restore()` |
| Missing data files | Run `source("R/generate_data_fallback.R")` |
| Model not found | Run `source("R/train_model.R")` |
| Python API won't start | Run `uv sync` then retry |
| Quarto render fails | Ensure `renv::restore()` completed |
| ellmer/AI Query not working | Requires API key configuration (see ellmer docs) |

## Pre-Demo Checklist

- [ ] `renv::restore()` completed successfully
- [ ] `uv sync` completed successfully
- [ ] Data files exist in `data/adam/` and `data/sdtm/`
- [ ] ML models exist in `ml/` directory
- [ ] Shiny app launches without errors
- [ ] Quarto report renders (HTML exists in `quarto/`)
- [ ] (Optional) API starts on port 8000

## Files to Have Open

1. Shiny app running in browser
2. `quarto/validation_report.html` in browser tab
3. Terminal ready for API launch
4. `_brand.yml` in editor (to show customization)

## Next Steps / Call to Action

After the demo, suggest:

1. **Proof of Concept**: "Let's set up a PoC with one of your actual studies"
2. **Workbench Trial**: "Your team can try Posit Workbench with SLC integration"
3. **Connect Demo**: "I can show you how this deploys to Posit Connect for your organization"
4. **Package Manager**: "We can set up validated package repositories for your CSP team"

## Contact

For demo issues or enhancement requests, contact the Posit Solutions Engineering team.
