# =============================================================================
# config.R  -  Shared settings and constants for the whole application
# =============================================================================
# Change values here (for example the currency symbol or the categories) and
# the whole app will pick them up automatically.

APP_TITLE <- "Personal Finance Burn Rate Calculator"

# Text shown in front of money values. Plain text is used on purpose so it
# displays correctly on every Windows / Mac / Linux computer.
CURRENCY <- "Rs. "

# ---- File locations (relative to the project folder) ------------------------
DATA_DIR      <- "data"
INCOME_FILE   <- file.path(DATA_DIR, "income.csv")
EXPENSES_FILE <- file.path(DATA_DIR, "expenses.csv")
SETTINGS_FILE <- file.path(DATA_DIR, "settings.csv")

# Every sample record has a note starting with this tag, so the app can tell
# sample data apart from your own data (see "Settings & Data" page).
SAMPLE_TAG <- "[SAMPLE]"

# ---- Allowed values for the input forms --------------------------------------
EXPENSE_CATEGORIES <- c("Food", "Education", "Transport", "Shopping",
                        "Bills", "Entertainment", "Others")
INCOME_SOURCES     <- c("Pocket Money", "Scholarship", "Part-Time Job",
                        "Freelance", "Gift", "Other Income")

# ---- Rules for the runway estimate -------------------------------------------
# A runway is only calculated when there is "enough" data to make it sensible.
MIN_EXPENSE_RECORDS <- 3   # at least this many expense records in the period
MIN_MONTHS          <- 1   # at least this many months in the period

# ---- Colours used in charts ---------------------------------------------------
COLOR_INCOME  <- "#27ae60"
COLOR_EXPENSE <- "#e74c3c"
COLOR_SAVINGS <- "#2980b9"
CATEGORY_COLORS <- c(
  Food          = "#e67e22",
  Education     = "#3498db",
  Transport     = "#1abc9c",
  Shopping      = "#9b59b6",
  Bills         = "#e74c3c",
  Entertainment = "#f1c40f",
  Others        = "#7f8c8d"
)

# ---- Disclaimer shown next to every runway figure ----------------------------
RUNWAY_DISCLAIMER <- paste(
  "The financial runway is only an ESTIMATE. It assumes your future spending",
  "and income will stay the same as your average in the selected period.",
  "It is not a financial guarantee or financial advice."
)
