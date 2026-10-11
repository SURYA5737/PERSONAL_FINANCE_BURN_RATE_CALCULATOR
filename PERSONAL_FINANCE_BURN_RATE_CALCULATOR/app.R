# =============================================================================
#  PERSONAL FINANCE BURN RATE CALCULATOR
#  A Shiny dashboard written in R
# -----------------------------------------------------------------------------
#  HOW TO RUN (RStudio):
#    1. Open the project folder in RStudio (File > Open Project... and choose
#       PERSONAL_FINANCE_BURN_RATE_CALCULATOR.Rproj)
#    2. Run   source("requirements.R")   ONCE to install the packages
#    3. Open this file (app.R) and click the green "Run App" button
#
#  PROJECT FILES:
#    R/config.R           constants (currency, categories, colours)
#    R/calculations.R     all formulas (burn rate, savings, runway)
#    R/data_management.R  reading / writing the CSV files + validation
#    R/charts.R           ggplot2 charts
#    data/*.csv           your data (sample data is included)
# =============================================================================

# ---- 1. Make sure R is looking at the project folder ---------------------------
# "Run App" already does this. The code below only helps when app.R is started in
# some other way (for example by pressing Ctrl+Enter inside the file).
if (!file.exists(file.path("R", "config.R"))) {
  try({
    if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
      setwd(dirname(rstudioapi::getSourceEditorContext()$path))
    }
  }, silent = TRUE)
}
if (!file.exists(file.path("R", "config.R"))) {
  stop("Cannot find the 'R' folder. Open the project folder in RStudio ",
       "(open the .Rproj file) and run the app again.", call. = FALSE)
}

# ---- 2. Check and load packages ---------------------------------------------------
required_packages <- c("shiny", "shinydashboard", "ggplot2", "plotly", "DT", "scales")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace,
                                              logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop("Missing R packages: ", paste(missing_packages, collapse = ", "),
       ".\nRun  source(\"requirements.R\")  once to install them, then run the app again.",
       call. = FALSE)
}
suppressPackageStartupMessages({
  library(shiny)
  library(shinydashboard)
  library(ggplot2)
  library(plotly)
  library(DT)
})

# ---- 3. Load the project's own code --------------------------------------------------
# (Newer versions of Shiny also load the R/ folder automatically. Loading the
#  files again here is harmless and keeps older versions working too.)
for (f in c("config.R", "calculations.R", "data_management.R", "charts.R")) {
  source(file.path("R", f), local = FALSE)
}

# ---- 4. Prepare the data files and the first values for the UI ---------------------------
init_data_files()                         # creates missing CSV files safely
init_income   <- read_income()
init_expenses <- read_expenses()
init_balance  <- read_starting_balance()
init_period   <- default_period(init_income, init_expenses)

amount_label <- paste0("Amount (", trimws(CURRENCY), ")")

# =============================================================================
#  USER INTERFACE
# =============================================================================

# Small custom style sheet for a clean, modern look
app_css <- "
  .content-wrapper, .right-side { background-color: #f4f6f9; }
  .main-header .logo { font-weight: bold; }
  .box { border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.10); }
  .small-box { border-radius: 10px; box-shadow: 0 1px 4px rgba(0,0,0,0.15); }
  .small-box h3 { font-size: 28px; font-weight: bold; }
  .small-box p { font-size: 14px; }
  .sidebar-filters label { color: #b8c7ce; }
  .alert { border-radius: 8px; margin-bottom: 15px; }
  .btn { margin-right: 6px; margin-bottom: 4px; }
  table { font-size: 14px; }
  @media (max-width: 767px) { .small-box h3 { font-size: 22px; } }
"

# The four input fields shared by every 'add' and 'edit' form
transaction_inputs <- function(prefix, label_text, choices) {
  tagList(
    dateInput(paste0(prefix, "_date"), "Date", value = Sys.Date(), format = "yyyy-mm-dd"),
    selectInput(paste0(prefix, "_label"), label_text, choices = choices),
    numericInput(paste0(prefix, "_amount"), amount_label, value = NA, min = 0, step = 50),
    textInput(paste0(prefix, "_note"), "Note (optional)")
  )
}

# A complete Income or Expense page (form on the left, table on the right)
record_page_ui <- function(tab_name, prefix, kind_label, status, label_text, choices) {
  tabItem(
    tabName = tab_name,
    fluidRow(
      column(
        width = 4,
        box(title = paste("Add", kind_label), status = status, solidHeader = TRUE,
            width = NULL,
            transaction_inputs(paste0(prefix, "_add"), label_text, choices),
            actionButton(paste0(prefix, "_add_btn"), paste("Add", kind_label),
                         icon = icon("plus"), class = "btn-success")),
        box(title = "Edit or Delete Selected Record", status = "warning",
            solidHeader = TRUE, width = NULL,
            helpText("Click one row in the table to load it here. Change the values",
                     "and press Update, or press Delete to remove it."),
            transaction_inputs(paste0(prefix, "_edit"), label_text, choices),
            actionButton(paste0(prefix, "_update_btn"), "Update",
                         icon = icon("save"), class = "btn-primary"),
            actionButton(paste0(prefix, "_delete_btn"), "Delete",
                         icon = icon("trash"), class = "btn-danger"))
      ),
      column(
        width = 8,
        box(title = paste(kind_label, "Records (all dates)"), status = status,
            solidHeader = TRUE, width = NULL,
            DTOutput(paste0(prefix, "_table")))
      )
    )
  )
}

ui <- dashboardPage(
  skin = "blue",

  dashboardHeader(title = "Burn Rate Calculator", titleWidth = 260),

  # ---- Sidebar: navigation + global date filter ----
  dashboardSidebar(
    width = 260,
    sidebarMenu(
      id = "tabs",
      menuItem("Dashboard",           tabName = "dashboard", icon = icon("chart-pie")),
      menuItem("Income",              tabName = "income",    icon = icon("money-bill")),
      menuItem("Expenses",            tabName = "expenses",  icon = icon("shopping-cart")),
      menuItem("Burn Rate & Savings", tabName = "burn",      icon = icon("fire")),
      menuItem("Charts",              tabName = "charts",    icon = icon("chart-line")),
      menuItem("Transaction History", tabName = "history",   icon = icon("table")),
      menuItem("Financial Summary",   tabName = "summary",   icon = icon("file")),
      menuItem("Settings & Data",     tabName = "settings",  icon = icon("cog"))
    ),
    div(
      class = "sidebar-filters", style = "padding: 10px 15px;",
      tags$label("Report period (date filter)"),
      dateRangeInput("date_range", label = NULL,
                     start = init_period$start, end = init_period$end,
                     format = "yyyy-mm-dd", separator = " to "),
      actionButton("reset_period", "Show all data", icon = icon("redo"), width = "100%")
    )
  ),

  # ---- Body: one tabItem per page ----
  dashboardBody(
    tags$head(tags$style(HTML(app_css))),
    tabItems(

      # ===== Dashboard =====
      tabItem(
        tabName = "dashboard",
        uiOutput("sample_banner"),
        fluidRow(
          valueBoxOutput("box_income",   width = 4),
          valueBoxOutput("box_expenses", width = 4),
          valueBoxOutput("box_savings",  width = 4)
        ),
        fluidRow(
          valueBoxOutput("box_burn",   width = 6),
          valueBoxOutput("box_runway", width = 6)
        ),
        fluidRow(column(width = 12, uiOutput("runway_note"))),
        fluidRow(
          box(title = "Expenses by Category", status = "primary", solidHeader = TRUE,
              width = 6, plotlyOutput("dash_cat_chart", height = "320px")),
          box(title = "Monthly Income vs Expenses", status = "primary", solidHeader = TRUE,
              width = 6, plotlyOutput("dash_month_chart", height = "320px"))
        )
      ),

      # ===== Income =====
      record_page_ui("income", "inc", "Income", "success", "Source", INCOME_SOURCES),

      # ===== Expenses =====
      record_page_ui("expenses", "exp", "Expense", "danger", "Category", EXPENSE_CATEGORIES),

      # ===== Burn Rate & Savings =====
      tabItem(
        tabName = "burn",
        fluidRow(
          valueBoxOutput("burn_vb_rate",    width = 4),
          valueBoxOutput("burn_vb_savings", width = 4),
          valueBoxOutput("burn_vb_runway",  width = 4)
        ),
        fluidRow(
          box(title = "Burn Rate Calculator", status = "danger", solidHeader = TRUE,
              width = 6, tableOutput("burn_calc")),
          box(title = "Savings Calculator", status = "primary", solidHeader = TRUE,
              width = 6, tableOutput("savings_calc"))
        ),
        fluidRow(
          box(title = "Financial Runway", status = "warning", solidHeader = TRUE,
              width = 6, tableOutput("runway_calc"), uiOutput("burn_runway_note")),
          box(title = "Amount Spent Each Month", status = "danger", solidHeader = TRUE,
              width = 6, tableOutput("burn_monthly"))
        )
      ),

      # ===== Charts =====
      tabItem(
        tabName = "charts",
        fluidRow(
          box(title = "Expense Categories", status = "primary", solidHeader = TRUE,
              width = 6, plotlyOutput("chart_category", height = "340px")),
          box(title = "Monthly Income vs Expenses", status = "primary", solidHeader = TRUE,
              width = 6, plotlyOutput("chart_income_expense", height = "340px"))
        ),
        fluidRow(
          box(title = "Savings Trend", status = "success", solidHeader = TRUE,
              width = 6, plotlyOutput("chart_savings", height = "340px")),
          box(title = "Monthly Burn Rate", status = "danger", solidHeader = TRUE,
              width = 6, plotlyOutput("chart_burn", height = "340px"))
        )
      ),

      # ===== Transaction History =====
      tabItem(
        tabName = "history",
        fluidRow(
          box(title = "Filters", status = "primary", solidHeader = TRUE, width = 12,
              helpText("The date range is set in the left sidebar. Use the search box above",
                       "the table for free-text search."),
              fluidRow(
                column(3, selectInput("hist_type", "Transaction type",
                                      choices = c("All", "Income", "Expense"))),
                column(4, selectInput("hist_category", "Category / Source",
                                      choices = c("All", EXPENSE_CATEGORIES, INCOME_SOURCES))),
                column(5, div(style = "margin-top: 25px;",
                              actionButton("hist_delete_btn", "Delete selected rows",
                                           icon = icon("trash"), class = "btn-danger"),
                              downloadButton("hist_download", "Download CSV")))
              ))
        ),
        fluidRow(
          box(title = "Transactions (income and expenses)", status = "primary",
              solidHeader = TRUE, width = 12, DTOutput("hist_table"))
        )
      ),

      # ===== Financial Summary =====
      tabItem(
        tabName = "summary",
        fluidRow(
          box(title = "Financial Summary", status = "primary", solidHeader = TRUE,
              width = 6, tableOutput("sum_table")),
          box(title = "Spending by Category", status = "primary", solidHeader = TRUE,
              width = 6, tableOutput("sum_cat"))
        ),
        fluidRow(
          box(title = "Monthly Breakdown", status = "primary", solidHeader = TRUE,
              width = 8, tableOutput("sum_monthly")),
          box(title = "Report", status = "warning", solidHeader = TRUE, width = 4,
              uiOutput("sum_runway_note"),
              downloadButton("download_report", "Download report (.txt)"))
        )
      ),

      # ===== Settings & Data =====
      tabItem(
        tabName = "settings",
        fluidRow(
          box(title = "Starting Savings", status = "primary", solidHeader = TRUE, width = 6,
              p("The money you already had saved BEFORE your first recorded transaction.",
                "It is used to calculate your available savings."),
              numericInput("starting_balance", amount_label, value = init_balance,
                           min = 0, step = 100),
              actionButton("save_balance", "Save starting savings",
                           icon = icon("save"), class = "btn-primary")),
          box(title = "Sample Data", status = "warning", solidHeader = TRUE, width = 6,
              uiOutput("sample_status"),
              p("Sample records have a note that starts with [SAMPLE]. Removing them keeps",
                "every record you added yourself and sets the starting savings to 0."),
              actionButton("remove_sample", "Remove sample data",
                           icon = icon("trash"), class = "btn-warning"))
        ),
        fluidRow(
          box(title = "Data Files", status = "info", solidHeader = TRUE, width = 6,
              verbatimTextOutput("data_paths")),
          box(title = "About & Formulas", status = "info", solidHeader = TRUE, width = 6,
              tags$ul(
                tags$li(strong("Net Savings"), " = Total Income - Total Expenses"),
                tags$li(strong("Monthly Burn Rate"),
                        " = Total Expenses in the period / Months in the period"),
                tags$li(strong("Available Savings"),
                        " = Starting Savings + Income - Expenses (up to the period end)"),
                tags$li(strong("Financial Runway"),
                        " = Available Savings / Monthly Burn Rate (in months)")
              ),
              p(em(RUNWAY_DISCLAIMER)))
        )
      )
    )
  )
)

# =============================================================================
#  SERVER (the logic)
# =============================================================================
server <- function(input, output, session) {

  # ---- Data held in memory; the CSV files are the permanent copy ----------------
  rv <- reactiveValues(income = init_income,
                       expenses = init_expenses,
                       start_balance = init_balance)

  # Re-read everything from the CSV files (called after every change)
  refresh_data <- function() {
    rv$income        <- read_income()
    rv$expenses      <- read_expenses()
    rv$start_balance <- read_starting_balance()
  }

  # Show a green (success) or red (error) message
  notify <- function(res) {
    showNotification(res$message, type = if (isTRUE(res$ok)) "message" else "error",
                     duration = 6)
  }

  # Widen the date filter when a record outside the current period is saved
  expand_period_to <- function(d) {
    rng <- input$date_range
    d <- as.Date(d)
    if (is.null(rng) || length(rng) != 2 || any(is.na(rng)) || is.na(d)) return(FALSE)
    if (d < rng[1] || d > rng[2]) {
      updateDateRangeInput(session, "date_range",
                           start = min(rng[1], month_start(d)),
                           end   = max(rng[2], month_end(d)))
      return(TRUE)
    }
    FALSE
  }

  # ---- Date filter ---------------------------------------------------------------------------
  period <- reactive({
    rng <- input$date_range
    validate(need(!is.null(rng) && length(rng) == 2 && !any(is.na(rng)),
                  "Please choose a valid date range in the sidebar."))
    validate(need(rng[1] <= rng[2], "The start date must be on or before the end date."))
    validate(need(as.numeric(rng[2] - rng[1]) <= 3660,
                  "Please choose a period of 10 years or less."))
    list(start = rng[1], end = rng[2])
  })

  observeEvent(input$reset_period, {
    p <- default_period(rv$income, rv$expenses)
    updateDateRangeInput(session, "date_range", start = p$start, end = p$end)
  })

  # ---- Calculations (recalculated automatically when data or filter change) ------------
  summary_data <- reactive({
    p <- period()
    calc_summary(rv$income, rv$expenses, rv$start_balance, p$start, p$end)
  })

  monthly_data <- reactive({
    p <- period()
    monthly_summary(rv$income, rv$expenses, rv$start_balance, p$start, p$end)
  })

  category_data <- reactive({
    p <- period()
    category_totals(filter_by_date(rv$expenses, p$start, p$end))
  })

  # Turn a ggplot into an interactive plotly chart
  to_plotly <- function(p) {
    plotly::config(plotly::ggplotly(p), displaylogo = FALSE)
  }

  # Coloured message box that explains the runway result
  runway_alert <- function(s) {
    cls <- switch(s$runway_status,
                  ok = "alert-info", depleted = "alert-danger", "alert-warning")
    div(class = paste("alert", cls),
        icon("info-circle"), " ", s$runway_message,
        tags$br(), tags$small(RUNWAY_DISCLAIMER))
  }

  # ===========================================================================
  #  DASHBOARD
  # ===========================================================================
  output$sample_banner <- renderUI({
    if (has_sample_data(rv$income, rv$expenses)) {
      div(class = "alert alert-info",
          icon("info-circle"), strong(" Sample data is loaded. "),
          "The figures below are based on example transactions. Open 'Settings & Data'",
          "to remove them and start entering your own data.")
    }
  })

  output$box_income <- renderValueBox({
    s <- summary_data()
    valueBox(format_money(s$total_income), "Total Income (selected period)",
             icon = icon("money-bill"), color = "green")
  })
  output$box_expenses <- renderValueBox({
    s <- summary_data()
    valueBox(format_money(s$total_expenses), "Total Expenses (selected period)",
             icon = icon("shopping-cart"), color = "red")
  })
  output$box_savings <- renderValueBox({
    s <- summary_data()
    valueBox(format_money(s$available_savings), "Current Savings (available)",
             icon = icon("piggy-bank"), color = "blue")
  })
  output$box_burn <- renderValueBox({
    s <- summary_data()
    valueBox(format_money(s$burn_rate), "Monthly Burn Rate",
             icon = icon("fire"), color = "orange")
  })
  output$box_runway <- renderValueBox({
    s <- summary_data()
    valueBox(format_runway(s), "Estimated Financial Runway",
             icon = icon("hourglass-half"), color = "purple")
  })
  output$runway_note <- renderUI(runway_alert(summary_data()))

  output$dash_cat_chart   <- renderPlotly(to_plotly(plot_category_expenses(category_data())))
  output$dash_month_chart <- renderPlotly(to_plotly(plot_income_vs_expenses(monthly_data())))

  # ===========================================================================
  #  INCOME and EXPENSE pages (same logic, so one helper builds both)
  # ===========================================================================
  # type = "income" or "expense"; prefix = "inc" or "exp" (matches the UI ids)
  setup_record_page <- function(type, prefix) {
    is_income <- type == "income"
    label_col <- if (is_income) "source" else "category"
    get_data  <- function() if (is_income) rv$income else rv$expenses
    id_       <- function(suffix) paste0(prefix, "_", suffix)

    # The table, newest record first
    display_df <- reactive({
      df <- get_data()
      df[order(df$date, df$id, decreasing = TRUE), , drop = FALSE]
    })

    output[[id_("table")]] <- renderDT({
      df  <- display_df()
      tbl <- data.frame(ID = df$id, Date = df$date, Label = df[[label_col]],
                        Amount = df$amount, Note = df$note, stringsAsFactors = FALSE)
      names(tbl)[3] <- if (is_income) "Source" else "Category"
      datatable(tbl, rownames = FALSE, selection = "single",
                options = list(pageLength = 10, order = list(), scrollX = TRUE)) %>%
        formatCurrency("Amount", currency = CURRENCY, digits = 2)
    })

    # ID of the record that is selected in the table (NULL if none)
    selected_id <- reactive({
      sel <- input[[id_("table_rows_selected")]]
      if (length(sel) != 1) return(NULL)
      display_df()$id[sel]
    })

    # Selecting a row fills the edit form
    observeEvent(input[[id_("table_rows_selected")]], {
      sid <- selected_id()
      if (is.null(sid)) return()
      df  <- get_data()
      rec <- df[df$id == sid, , drop = FALSE]
      if (nrow(rec) != 1) return()
      updateDateInput(session, id_("edit_date"), value = rec$date)
      updateSelectInput(session, id_("edit_label"), selected = rec[[label_col]])
      updateNumericInput(session, id_("edit_amount"), value = rec$amount)
      updateTextInput(session, id_("edit_note"), value = rec$note)
    })

    # ADD
    observeEvent(input[[id_("add_btn")]], {
      res <- add_record(type, input[[id_("add_date")]], input[[id_("add_label")]],
                        input[[id_("add_amount")]], input[[id_("add_note")]])
      if (res$ok) {
        refresh_data()
        if (expand_period_to(input[[id_("add_date")]])) {
          res$message <- paste(res$message,
                               "The report period was widened to include the new date.")
        }
        updateNumericInput(session, id_("add_amount"), value = NA)
        updateTextInput(session, id_("add_note"), value = "")
      }
      notify(res)
    })

    # UPDATE
    observeEvent(input[[id_("update_btn")]], {
      sid <- selected_id()
      if (is.null(sid)) {
        notify(list(ok = FALSE, message = "Please click a row in the table first."))
        return()
      }
      res <- update_record(type, sid, input[[id_("edit_date")]], input[[id_("edit_label")]],
                           input[[id_("edit_amount")]], input[[id_("edit_note")]])
      if (res$ok) {
        refresh_data()
        if (expand_period_to(input[[id_("edit_date")]])) {
          res$message <- paste(res$message,
                               "The report period was widened to include the new date.")
        }
      }
      notify(res)
    })

    # DELETE (asks for confirmation first)
    observeEvent(input[[id_("delete_btn")]], {
      if (is.null(selected_id())) {
        notify(list(ok = FALSE, message = "Please click a row in the table first."))
        return()
      }
      showModal(modalDialog(
        title = "Confirm delete",
        "Are you sure you want to delete the selected record? This cannot be undone.",
        footer = tagList(modalButton("Cancel"),
                         actionButton(id_("confirm_delete"), "Delete", class = "btn-danger")),
        easyClose = TRUE))
    })

    observeEvent(input[[id_("confirm_delete")]], {
      removeModal()
      sid <- selected_id()
      if (is.null(sid)) return()
      res <- delete_records(type, sid)
      if (res$ok) refresh_data()
      notify(res)
    })
  }

  setup_record_page("income",  "inc")
  setup_record_page("expense", "exp")

  # ===========================================================================
  #  BURN RATE & SAVINGS page
  # ===========================================================================
  output$burn_vb_rate <- renderValueBox({
    s <- summary_data()
    valueBox(format_money(s$burn_rate), "Monthly Burn Rate",
             icon = icon("fire"), color = "orange")
  })
  output$burn_vb_savings <- renderValueBox({
    s <- summary_data()
    valueBox(format_money(s$available_savings), "Available Savings",
             icon = icon("piggy-bank"), color = "blue")
  })
  output$burn_vb_runway <- renderValueBox({
    s <- summary_data()
    valueBox(format_runway(s), "Estimated Runway",
             icon = icon("hourglass-half"), color = "purple")
  })

  output$burn_calc <- renderTable({
    s <- summary_data()
    data.frame(
      Step = c("Report period", "Months in period", "Total expenses",
               "Monthly burn rate"),
      Calculation = c("Start date to end date",
                      "Calendar months covered",
                      paste("Sum of", s$n_expenses, "expense records"),
                      "Total expenses / Months"),
      Result = c(paste(format(s$start), "to", format(s$end)),
                 sprintf("%.2f", s$months),
                 format_money(s$total_expenses),
                 format_money(s$burn_rate)),
      stringsAsFactors = FALSE)
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", align = "llr")

  output$savings_calc <- renderTable({
    s <- summary_data()
    data.frame(
      Step = c("Starting savings", "+ Total income", "- Total expenses",
               "= Available savings", "Net savings (this period)"),
      Calculation = c("Saved before the first record",
                      paste("All income up to", format(s$end)),
                      paste("All expenses up to", format(s$end)),
                      "Starting + Income - Expenses",
                      "Income - Expenses in the period"),
      Result = c(format_money(s$starting_balance),
                 format_money(s$income_to_date),
                 format_money(s$expenses_to_date),
                 format_money(s$available_savings),
                 format_money(s$net_savings)),
      stringsAsFactors = FALSE)
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", align = "llr")

  output$runway_calc <- renderTable({
    s <- summary_data()
    data.frame(
      Step = c("Available savings", "Monthly burn rate", "Financial runway"),
      Calculation = c("From the Savings Calculator", "From the Burn Rate Calculator",
                      "Available savings / Burn rate"),
      Result = c(format_money(s$available_savings), format_money(s$burn_rate),
                 format_runway(s)),
      stringsAsFactors = FALSE)
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", align = "llr")

  output$burn_runway_note <- renderUI(runway_alert(summary_data()))

  output$burn_monthly <- renderTable({
    ms <- monthly_data()
    s  <- summary_data()
    validate(need(nrow(ms) > 0, "No data for the selected period."))
    diff <- ms$expenses - s$burn_rate
    data.frame(
      Month = c(ms$month_label, "AVERAGE (burn rate)"),
      `Amount Spent` = c(format_money(ms$expenses), format_money(s$burn_rate)),
      `Vs Average` = c(ifelse(diff >= 0, paste0("+", format_money(diff)), format_money(diff)), ""),
      check.names = FALSE, stringsAsFactors = FALSE)
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", align = "lrr")

  # ===========================================================================
  #  CHARTS page
  # ===========================================================================
  output$chart_category       <- renderPlotly(to_plotly(plot_category_expenses(category_data())))
  output$chart_income_expense <- renderPlotly(to_plotly(plot_income_vs_expenses(monthly_data())))
  output$chart_savings        <- renderPlotly(to_plotly(plot_savings_trend(monthly_data())))
  output$chart_burn <- renderPlotly({
    to_plotly(plot_monthly_burn(monthly_data(), summary_data()$burn_rate))
  })

  # ===========================================================================
  #  TRANSACTION HISTORY page
  # ===========================================================================
  history_data <- reactive({
    p  <- period()
    df <- combine_transactions(filter_by_date(rv$income,   p$start, p$end),
                               filter_by_date(rv$expenses, p$start, p$end))
    if (input$hist_type != "All") {
      df <- df[df$type == input$hist_type, , drop = FALSE]
    }
    if (input$hist_category != "All") {
      df <- df[df$category == input$hist_category, , drop = FALSE]
    }
    df
  })

  output$hist_table <- renderDT({
    df <- history_data()
    shown <- data.frame(Type = df$type, ID = df$id, Date = df$date,
                        `Category / Source` = df$category, Amount = df$amount,
                        Note = df$note, check.names = FALSE, stringsAsFactors = FALSE)
    datatable(shown, rownames = FALSE, selection = "multiple",
              options = list(pageLength = 15, order = list(), scrollX = TRUE)) %>%
      formatCurrency("Amount", currency = CURRENCY, digits = 2) %>%
      formatStyle("Type",
                  color = styleEqual(c("Income", "Expense"), c(COLOR_INCOME, COLOR_EXPENSE)),
                  fontWeight = "bold")
  })

  observeEvent(input$hist_delete_btn, {
    sel <- input$hist_table_rows_selected
    if (length(sel) == 0) {
      notify(list(ok = FALSE, message = "Select one or more rows in the table first."))
      return()
    }
    showModal(modalDialog(
      title = "Confirm delete",
      paste0("Delete ", length(sel), " selected record(s)? This cannot be undone."),
      footer = tagList(modalButton("Cancel"),
                       actionButton("hist_confirm_delete", "Delete", class = "btn-danger")),
      easyClose = TRUE))
  })

  observeEvent(input$hist_confirm_delete, {
    removeModal()
    sel <- input$hist_table_rows_selected
    df  <- history_data()
    if (length(sel) == 0 || any(sel > nrow(df))) return()

    chosen   <- df[sel, , drop = FALSE]
    messages <- character(0)
    all_ok   <- TRUE
    for (tp in c("Income", "Expense")) {
      ids <- chosen$id[chosen$type == tp]
      if (length(ids) > 0) {
        res <- delete_records(tolower(tp), ids)
        if (!res$ok) all_ok <- FALSE
        messages <- c(messages, res$message)
      }
    }
    refresh_data()
    notify(list(ok = all_ok, message = paste(messages, collapse = " ")))
  })

  output$hist_download <- downloadHandler(
    filename = function() paste0("transactions_", format(Sys.Date(), "%Y%m%d"), ".csv"),
    content = function(file) {
      df <- history_data()
      df$date <- format(df$date, "%Y-%m-%d")
      utils::write.csv(df, file, row.names = FALSE)
    }
  )

  # ===========================================================================
  #  FINANCIAL SUMMARY page
  # ===========================================================================
  output$sum_table <- renderTable({
    summary_table(summary_data())
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", align = "ll")

  output$sum_cat <- renderTable({
    cat_df <- category_data()
    data.frame(Category = cat_df$category,
               Amount = format_money(cat_df$amount),
               Share = sprintf("%.1f%%", cat_df$percent),
               stringsAsFactors = FALSE)
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", align = "llr")

  output$sum_monthly <- renderTable({
    ms <- monthly_data()
    validate(need(nrow(ms) > 0, "No data for the selected period."))
    data.frame(Month = ms$month_label,
               Income = format_money(ms$income),
               Expenses = format_money(ms$expenses),
               `Net Savings` = format_money(ms$net),
               `Savings Balance` = format_money(ms$savings),
               check.names = FALSE, stringsAsFactors = FALSE)
  }, striped = TRUE, hover = TRUE, bordered = TRUE, width = "100%", align = "lrrrr")

  output$sum_runway_note <- renderUI(runway_alert(summary_data()))

  output$download_report <- downloadHandler(
    filename = function() paste0("financial_summary_", format(Sys.Date(), "%Y%m%d"), ".txt"),
    content = function(file) {
      writeLines(build_report_text(summary_data(), category_data()), file)
    }
  )

  # ===========================================================================
  #  SETTINGS & DATA page
  # ===========================================================================
  output$sample_status <- renderUI({
    if (has_sample_data(rv$income, rv$expenses)) {
      div(class = "alert alert-info", "Sample data is currently loaded.")
    } else {
      div(class = "alert alert-success", "No sample data found. You are using your own data.")
    }
  })

  output$data_paths <- renderText({
    paste0("Data folder:\n  ", normalizePath(DATA_DIR, mustWork = FALSE),
           "\n\nFiles:\n  income.csv\n  expenses.csv\n  settings.csv",
           "\n\nRecords saved:\n  ", nrow(rv$income), " income records\n  ",
           nrow(rv$expenses), " expense records")
  })

  observeEvent(input$save_balance, {
    res <- save_starting_balance(input$starting_balance)
    if (res$ok) refresh_data()
    notify(res)
  })

  observeEvent(input$remove_sample, {
    showModal(modalDialog(
      title = "Remove sample data?",
      "All records tagged [SAMPLE] will be deleted and the starting savings will be set to 0. Your own records are kept.",
      footer = tagList(modalButton("Cancel"),
                       actionButton("confirm_remove_sample", "Remove", class = "btn-warning")),
      easyClose = TRUE))
  })

  observeEvent(input$confirm_remove_sample, {
    removeModal()
    res <- remove_sample_data()
    if (res$ok) {
      refresh_data()
      updateNumericInput(session, "starting_balance", value = 0)
      p <- default_period(rv$income, rv$expenses)
      updateDateRangeInput(session, "date_range", start = p$start, end = p$end)
    }
    notify(res)
  })
}

shinyApp(ui, server)
