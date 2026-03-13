# =============================================================================
# SCRIPT   : app.R
# STUDY    : NSVT-001 | NovaStat Therapeutics (FICTIONAL - AI-generated demo)
# PURPOSE  : Interactive Clinical Intelligence Hub - Shiny application
#            Features: Site filtering, dropout predictions, SHAP explainability,
#            and Natural Language Query (NLQ) via ellmer
# NOTE     : ALL DATA IS SYNTHETIC. For demonstration purposes only.
# =============================================================================

library(shiny)
library(bslib)
library(tidyverse)
library(tidymodels)
library(shapviz)
library(DT)
library(plotly)
library(ellmer)

# Set working directory to project root (handles running app.R from R/ subdir)
if (basename(getwd()) == "R") setwd("..")

# =============================================================================
# DATA & MODEL LOADING
# =============================================================================

load_data <- function() {
  adsl_path <- "data/adam/adsl.csv"
  if (!file.exists(adsl_path)) {
    stop("ADSL not found. Run generate_sdtm.sas and create_adam.sas first.")
  }
  read_csv(adsl_path, show_col_types = FALSE) |>
    mutate(
      DPTFL   = factor(DPTFL, levels = c("N", "Y")),
      SEXN    = factor(SEXN),
      RACEN   = factor(RACEN),
      REGIONN = factor(REGIONN),
      TRT01PN = factor(TRT01PN)
    )
}

load_model <- function() {
  model_path <- "ml/dropout_model.rds"
  if (!file.exists(model_path)) {
    message("Model not found - run R/train_model.R first.")
    return(NULL)
  }
  readRDS(model_path)
}

adsl         <- load_data()
dropout_model <- load_model()
has_model    <- !is.null(dropout_model)

# Feature columns used in model
model_features <- c(
  "AGE", "SEXN", "RACEN", "REGIONN", "DAS28BL", "BMIBL", "TRT01PN",
  "AENUM", "AESNUM", "AEMAXSEVN", "N_ALT_AE", "N_NEURO_GI_AE",
  "COMPLPCT", "N_MISSED_DOSES"
)

# =============================================================================
# HELPER: Generate predictions for a site
# =============================================================================

predict_site <- function(data, model) {
  if (is.null(model)) return(data |> mutate(dropout_prob = NA_real_))

  pred_df <- data |>
    select(all_of(model_features)) |>
    mutate(
      SEXN    = factor(SEXN),
      RACEN   = factor(RACEN),
      REGIONN = factor(REGIONN),
      TRT01PN = factor(TRT01PN)
    )

  probs <- predict(model, pred_df, type = "prob")$.pred_Y
  data |> mutate(dropout_prob = round(probs * 100, 1))
}

# Risk tier labels
risk_tier <- function(prob) {
  case_when(
    is.na(prob)  ~ "Unknown",
    prob >= 60   ~ "High Risk",
    prob >= 35   ~ "Moderate Risk",
    TRUE         ~ "Low Risk"
  )
}

risk_color <- function(tier) {
  c("High Risk" = "#C0392B", "Moderate Risk" = "#E87722",
    "Low Risk" = "#2D8653", "Unknown" = "#4A5568")[tier]
}

# =============================================================================
# UI
# =============================================================================

ui <- page_navbar(
  title = "NovaStat Clinical Intelligence Hub",
  theme = bs_theme(brand = "_brand.yml"),
  fillable = TRUE,

  # Disclaimer banner
  header = div(
    style = "background:#FFF3CD; border-bottom:1px solid #E87722;
             padding:6px 16px; font-size:0.82em; color:#7D5A00;",
    icon("triangle-exclamation"),
    strong("DEMO:"),
    "This project contains synthetic data and analysis created for demonstration purposes only.",
    "All data is AI-generated for NSVT-001, a fictional NovaStat Therapeutics clinical trial."
  ),

  # --- PANEL 1: Site Overview ---
  nav_panel(
    title = "Site Overview",
    icon  = icon("hospital"),

    layout_sidebar(
      sidebar = sidebar(
        width = 280,
        title = "Filters",

        selectInput("sel_site", "Clinical Site",
                    choices  = c("All Sites", sort(unique(adsl$SITEID))),
                    selected = "All Sites"),

        selectInput("sel_trt", "Treatment Arm",
                    choices  = c("All Arms", sort(unique(adsl$TRT01P))),
                    selected = "All Arms"),

        selectInput("sel_region", "Region",
                    choices  = c("All Regions", sort(unique(adsl$REGION))),
                    selected = "All Regions"),

        hr(),
        actionButton("btn_predict", "Run Predictions",
                     class = "btn-primary w-100",
                     icon  = icon("play")),
        br(), br(),
        helpText("Predictions use the trained Random Forest / XGBoost model.",
                 "Probabilities represent estimated dropout risk per patient.")
      ),

      # KPI cards
      layout_columns(
        col_widths = c(3, 3, 3, 3),
        value_box(title = "Total Subjects",   value = textOutput("kpi_total"),
                  showcase = icon("users"),     theme = "primary"),
        value_box(title = "Dropout Rate",     value = textOutput("kpi_dropout"),
                  showcase = icon("door-open"), theme = "warning"),
        value_box(title = "Mean Compliance",  value = textOutput("kpi_comp"),
                  showcase = icon("pills"),     theme = "success"),
        value_box(title = "Mean AE Count",    value = textOutput("kpi_ae"),
                  showcase = icon("virus"),     theme = "danger")
      ),

      br(),
      layout_columns(
        col_widths = c(6, 6),
        card(
          card_header("Dropout Rate by Site"),
          plotlyOutput("plot_site_dropout", height = "280px")
        ),
        card(
          card_header("Compliance Distribution by Treatment"),
          plotlyOutput("plot_compliance", height = "280px")
        )
      )
    )
  ),

  # --- PANEL 2: Patient Risk ---
  nav_panel(
    title = "Patient Risk",
    icon  = icon("person-circle-exclamation"),

    layout_sidebar(
      sidebar = sidebar(
        width = 280,
        title = "Risk Filters",
        checkboxGroupInput("chk_risk", "Risk Tier",
                           choices  = c("High Risk", "Moderate Risk", "Low Risk"),
                           selected = c("High Risk", "Moderate Risk", "Low Risk")),
        hr(),
        downloadButton("dl_risk_table", "Export Risk Table",
                       class = "btn-outline-primary w-100")
      ),

      card(
        card_header("At-Risk Patient Table"),
        DTOutput("tbl_patients")
      )
    )
  ),

  # --- PANEL 3: SHAP Explainability ---
  nav_panel(
    title = "Model Explainability",
    icon  = icon("magnifying-glass-chart"),

    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Feature Importance (Global)"),
        plotOutput("plot_shap_global", height = "380px")
      ),
      card(
        card_header("Patient-Level Explanation (SHAP Waterfall)"),
        layout_sidebar(
          sidebar = sidebar(
            width = 220,
            selectInput("sel_patient", "Select Patient",
                        choices = adsl$USUBJID)
          ),
          plotOutput("plot_shap_patient", height = "340px")
        )
      )
    )
  ),

  # --- PANEL 4: Natural Language Query ---
  nav_panel(
    title = "AI Query",
    icon  = icon("robot"),

    layout_columns(
      col_widths = c(5, 7),

      card(
        card_header("Natural Language Query (powered by ellmer)"),
        p("Ask questions about the trial data in plain English."),
        textAreaInput("nlq_input", NULL,
                      placeholder = "Which sites in Europe have the highest dropout rate?",
                      rows = 3),
        actionButton("btn_nlq", "Ask", class = "btn-primary",
                     icon = icon("paper-plane")),
        hr(),
        strong("Example queries:"),
        tags$ul(
          tags$li("Which sites have the highest predicted dropout rate?"),
          tags$li("What is the AE profile of high-risk patients?"),
          tags$li("Compare compliance between the 100mg and 200mg arms."),
          tags$li("Which patients are most at risk in Germany?")
        )
      ),

      card(
        card_header("Response"),
        uiOutput("nlq_response"),
        hr(),
        plotlyOutput("nlq_plot", height = "280px")
      )
    )
  ),

  # --- PANEL 5: SAS Log & Audit ---
  nav_panel(
    title = "Audit Trail",
    icon  = icon("shield-halved"),

    card(
      card_header("Data Provenance & GxP Audit"),
      layout_columns(
        col_widths = c(6, 6),
        card(
          card_header("CDISC Pipeline", class = "bg-light"),
          tags$ul(
            tags$li(icon("check-circle", style = "color:green"), " DM generated: ",
                    code("sas/generate_sdtm.sas")),
            tags$li(icon("check-circle", style = "color:green"), " AE, EX, VS, DS generated"),
            tags$li(icon("check-circle", style = "color:green"), " ADSL created: ",
                    code("sas/create_adam.sas")),
            tags$li(icon("check-circle", style = "color:green"), " CDISC validated: ",
                    code("sas/cdisc_validation.sas")),
            tags$li(icon("check-circle", style = "color:green"), " TFLs generated: ",
                    code("sas/tfl/")),
            tags$li(icon("check-circle", style = "color:green"), " ML model trained: ",
                    code("R/train_model.R")),
          )
        ),
        card(
          card_header("Model Metadata", class = "bg-light"),
          verbatimTextOutput("txt_model_meta")
        )
      ),
      card(
        card_header("Model Performance (Test Set)"),
        tableOutput("tbl_model_perf")
      )
    )
  )
)

# =============================================================================
# SERVER
# =============================================================================

server <- function(input, output, session) {

  # --- Reactive: Filtered data ---
  filtered_data <- reactive({
    d <- adsl
    if (input$sel_site != "All Sites")     d <- d |> filter(SITEID == input$sel_site)
    if (input$sel_trt  != "All Arms")      d <- d |> filter(TRT01P == input$sel_trt)
    if (input$sel_region != "All Regions") d <- d |> filter(REGION == input$sel_region)
    d
  })

  # --- Reactive: Predictions (computed on button click) ---
  predicted_data <- eventReactive(input$btn_predict, {
    withProgress(message = "Running predictions...", {
      d <- filtered_data()
      if (has_model) {
        predict_site(d, dropout_model) |>
          mutate(risk_tier = risk_tier(dropout_prob))
      } else {
        d |> mutate(dropout_prob = NA_real_, risk_tier = "Unknown")
      }
    })
  }, ignoreNULL = FALSE)

  # --- KPIs ---
  output$kpi_total   <- renderText(nrow(filtered_data()))
  output$kpi_dropout <- renderText(sprintf("%.1f%%", mean(filtered_data()$DPTFL == "Y") * 100))
  output$kpi_comp    <- renderText(sprintf("%.0f%%", mean(filtered_data()$COMPLPCT, na.rm = TRUE)))
  output$kpi_ae      <- renderText(sprintf("%.1f", mean(filtered_data()$AENUM, na.rm = TRUE)))

  # --- Plot: Site dropout ---
  output$plot_site_dropout <- renderPlotly({
    site_sum <- filtered_data() |>
      group_by(SITEID, COUNTRY) |>
      summarise(n = n(), dropout = mean(DPTFL == "Y") * 100, .groups = "drop")

    p <- ggplot(site_sum, aes(x = reorder(SITEID, -dropout), y = dropout,
                               fill = COUNTRY,
                               text = paste0("Site: ", SITEID, "\nCountry: ", COUNTRY,
                                             "\nDropout: ", round(dropout, 1), "%\nN: ", n))) +
      geom_col(alpha = 0.85) +
      geom_hline(yintercept = 25, linetype = "dashed", color = "#C0392B", linewidth = 0.8) +
      labs(x = "Site", y = "Dropout Rate (%)", fill = "Country") +
      theme_minimal() +
      theme(legend.position = "bottom")

    ggplotly(p, tooltip = "text")
  })

  # --- Plot: Compliance ---
  output$plot_compliance <- renderPlotly({
    p <- ggplot(filtered_data(), aes(x = COMPLPCT, fill = TRT01P)) +
      geom_histogram(binwidth = 5, alpha = 0.75, position = "identity") +
      geom_vline(xintercept = 80, linetype = "dashed", color = "#1B4F8A") +
      labs(x = "Compliance (%)", y = "Count", fill = "Arm") +
      annotate("text", x = 78, y = Inf, label = "80% threshold",
               hjust = 1, vjust = 2, size = 3, color = "#1B4F8A") +
      theme_minimal()
    ggplotly(p)
  })

  # --- Patient risk table ---
  output$tbl_patients <- renderDT({
    d <- predicted_data() |>
      filter(risk_tier %in% input$chk_risk) |>
      arrange(desc(dropout_prob)) |>
      mutate(COMPLPCT    = round(COMPLPCT, 1),
             dropout_prob = round(dropout_prob * 100, 1)) |>
      select(USUBJID, SITEID, TRT01P, AGE, SEX, AENUM, AEMAXSEVN,
             COMPLPCT, dropout_prob, risk_tier) |>
      rename(
        `Subject ID`    = USUBJID,
        Site            = SITEID,
        Treatment       = TRT01P,
        Age             = AGE,
        Sex             = SEX,
        `N AEs`         = AENUM,
        `Max Sev (N)`   = AEMAXSEVN,
        `Compliance %`  = COMPLPCT,
        `Dropout Prob %` = dropout_prob,
        `Risk Tier`     = risk_tier
      )

    datatable(
      d,
      rownames  = FALSE,
      filter    = "top",
      options   = list(pageLength = 15, scrollX = TRUE),
      class     = "cell-border stripe"
    ) |>
      formatStyle("Risk Tier",
                  backgroundColor = styleEqual(
                    c("High Risk", "Moderate Risk", "Low Risk"),
                    c("#FADBD8",   "#FDEBD0",       "#D5F5E3")
                  ))
  })

  # --- Download ---
  output$dl_risk_table <- downloadHandler(
    filename = function() paste0("nsvt001-risk-report-", Sys.Date(), ".csv"),
    content  = function(file) {
      predicted_data() |>
        select(USUBJID, SITEID, TRT01P, AGE, SEX, AENUM, AEMAXSEVN,
               COMPLPCT, dropout_prob, risk_tier) |>
        write_csv(file)
    }
  )

  # --- SHAP Global ---
  output$plot_shap_global <- renderPlot({
    req(has_model)
    withProgress(message = "Computing SHAP values...", {
      sample_data <- adsl |>
        select(all_of(model_features)) |>
        mutate(
          SEXN = factor(SEXN), RACEN = factor(RACEN),
          REGIONN = factor(REGIONN), TRT01PN = factor(TRT01PN)
        ) |>
        slice_sample(n = min(80, nrow(adsl)))

      fitted_engine <- extract_fit_engine(dropout_model)

      # Use vip for global importance when SHAP not available
      tryCatch({
        shap <- shapviz(fitted_engine, X_pred = as.matrix(sample_data |>
          mutate(across(where(is.factor), as.integer))))
        sv_importance(shap, kind = "beeswarm") +
          labs(title = "SHAP Feature Impact (Global)")
      }, error = function(e) {
        # Fallback: variable importance bar chart
        dropout_model |>
          extract_fit_parsnip() |>
          vip::vip(num_features = 12, aesthetics = list(fill = "#1B4F8A")) +
          labs(title = "Variable Importance (Model)",
               subtitle = "SHAP requires xgboost engine; showing RF importance")
      })
    })
  })

  # --- SHAP Patient Waterfall ---
  output$plot_shap_patient <- renderPlot({
    req(has_model, input$sel_patient)
    withProgress(message = "Computing patient SHAP...", {
      patient <- adsl |>
        filter(USUBJID == input$sel_patient) |>
        select(all_of(model_features)) |>
        mutate(
          SEXN = factor(SEXN), RACEN = factor(RACEN),
          REGIONN = factor(REGIONN), TRT01PN = factor(TRT01PN)
        )

      pred_prob <- predict(dropout_model, patient, type = "prob")$.pred_Y

      # Feature importance breakdown for this patient
      feat_vals <- patient |>
        pivot_longer(everything(), names_to = "Feature", values_to = "Value") |>
        mutate(Value = as.numeric(as.character(Value)))

      # Approximate contribution using marginal means
      baseline_p <- mean(predict(dropout_model, adsl |>
        select(all_of(model_features)) |>
        mutate(SEXN = factor(SEXN), RACEN = factor(RACEN),
               REGIONN = factor(REGIONN), TRT01PN = factor(TRT01PN)),
        type = "prob")$.pred_Y)

      ggplot(feat_vals, aes(x = reorder(Feature, abs(Value)), y = Value)) +
        geom_col(fill = ifelse(pred_prob > 0.5, "#C0392B", "#2D8653"), alpha = 0.8) +
        coord_flip() +
        labs(
          title = paste("Patient:", input$sel_patient),
          subtitle = sprintf("Predicted dropout probability: %.1f%%", pred_prob * 100),
          x = NULL, y = "Feature Value"
        ) +
        theme_minimal()
    })
  })

  # --- NLQ via ellmer ---
  nlq_result <- eventReactive(input$btn_nlq, {
    req(input$nlq_input)
    withProgress(message = "Querying AI...", {

      # Build context summary
      site_summary <- adsl |>
        group_by(SITEID, REGION, COUNTRY) |>
        summarise(
          n          = n(),
          dropout_rt = round(mean(DPTFL == "Y") * 100, 1),
          mean_ae    = round(mean(AENUM), 1),
          mean_comp  = round(mean(COMPLPCT), 1),
          .groups    = "drop"
        )

      context <- paste0(
        "NSVT-001 Clinical Trial (NovaStat Therapeutics, NST-4892 RA study). ",
        "NOTE: ALL DATA IS AI-GENERATED SYNTHETIC DATA FOR DEMONSTRATION ONLY.\n\n",
        "Summary by site:\n",
        paste(capture.output(print(as.data.frame(site_summary))), collapse = "\n")
      )

      # ellmer chat (requires API key in env)
      tryCatch({
        chat <- chat_anthropic(
          system_prompt = paste0(
            "You are a clinical data analyst at NovaStat Therapeutics. ",
            "Answer questions about the NSVT-001 clinical trial data concisely. ",
            "Always remind the user this is synthetic demonstration data.\n\n",
            "Data context:\n", context
          )
        )
        response <- chat$chat(input$nlq_input)
        list(text = response, data = site_summary, error = NULL)
      }, error = function(e) {
        list(
          text  = paste("AI query unavailable. Set ANTHROPIC_API_KEY env var to enable NLQ.\n\n",
                        "Manual answer: Review the Site Overview tab for site-level dropout data."),
          data  = site_summary,
          error = conditionMessage(e)
        )
      })
    })
  })

  output$nlq_response <- renderUI({
    res <- nlq_result()
    div(
      style = "padding:12px; background:#F7F9FC; border-radius:6px; min-height:80px;",
      p(res$text)
    )
  })

  output$nlq_plot <- renderPlotly({
    res <- nlq_result()
    req(!is.null(res$data))

    p <- ggplot(res$data, aes(x = reorder(SITEID, -dropout_rt), y = dropout_rt,
                               fill = REGION,
                               text = paste0("Site: ", SITEID, " (", COUNTRY, ")",
                                             "\nDropout: ", dropout_rt, "%",
                                             "\nMean AEs: ", mean_ae,
                                             "\nCompliance: ", mean_comp, "%"))) +
      geom_col(alpha = 0.85) +
      labs(x = "Site", y = "Dropout Rate (%)", fill = "Region",
           title = "Dropout Rate by Site") +
      theme_minimal()

    ggplotly(p, tooltip = "text")
  })

  # --- Audit trail ---
  output$txt_model_meta <- renderText({
    if (!has_model) return("Model not yet trained. Run R/train_model.R.")
    comp <- if (file.exists("ml/model_comparison.rds")) readRDS("ml/model_comparison.rds") else NULL
    if (is.null(comp)) return("Model loaded. Run train_model.R to see comparison metrics.")
    best <- comp |> slice_max(roc_auc)
    paste0(
      "Study:        NSVT-001\n",
      "Sponsor:      NovaStat Therapeutics\n",
      "Drug:         NST-4892\n",
      "Target:       Patient Dropout (DPTFL=Y)\n",
      "Best Model:   ", best$model, "\n",
      "ROC AUC:      ", round(best$roc_auc, 3), "\n",
      "Accuracy:     ", round(best$accuracy, 3), "\n",
      "Framework:    tidymodels (R)\n",
      "Deployed via: vetiver + Posit Connect\n",
      "\nDISCLAIMER: Synthetic data only."
    )
  })

  output$tbl_model_perf <- renderTable({
    if (!file.exists("ml/model_comparison.rds")) {
      data.frame(Note = "Run R/train_model.R to generate model comparison.")
    } else {
      readRDS("ml/model_comparison.rds") |>
        mutate(across(where(is.numeric), ~round(., 3)))
    }
  })
}

shinyApp(ui, server)
