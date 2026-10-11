# =============================================================================
# calculations.R  -  All finance formulas live here (no Shiny code)
# =============================================================================
# Keeping the maths separate from the user interface makes it easy to read,
# explain in a viva, and test on its own.
#
# FORMULAS USED
#   Net Savings        = Total Income - Total Expenses            (selected period)
#   Monthly Burn Rate  = Total Expenses (selected period) / Months in the period
#   Available Savings  = Starting Savings + Income - Expenses     (up to period end)
#   Financial Runway   = Available Savings / Monthly Burn Rate    (in months)

# ---- Small helpers -------------------------------------------------------------

# Format numbers as money text, e.g. 12345.5 -> "Rs. 12,345.50"
format_money <- function(x, digits = 2) {
  out <- paste0(ifelse(x < 0, "-", ""), CURRENCY,
                formatC(abs(x), format = "f", digits = digits, big.mark = ","))
  out[is.na(x)] <- "N/A"
  out
}

# First day of the month that contains date d (single date)
month_start <- function(d) {
  as.Date(format(d, "%Y-%m-01"))
}

# Last day of the month that contains date d (single date)
month_end <- function(d) {
  ms <- month_start(d)
  next_month_start <- seq(ms, by = "month", length.out = 2)[2]
  next_month_start - 1
}

# Keep only the rows whose date is between start and end (both inclusive)
filter_by_date <- function(df, start, end) {
  df[df$date >= start & df$date <= end, , drop = FALSE]
}

# ---- Number of months in a period -------------------------------------------------
# Every calendar month touched by the period counts by the FRACTION of that
# month that is covered. Examples:
#   1 Apr - 30 Sep  -> exactly 6.00 months
#   1 Apr - 15 Apr  -> 15/30 = 0.50 months
# This keeps the burn rate consistent for any date range the user picks.
count_months <- function(start, end) {
  start <- as.Date(start)
  end   <- as.Date(end)
  if (is.na(start) || is.na(end) || start > end) return(0)

  month_starts <- seq(month_start(start), month_start(end), by = "month")
  total <- 0
  for (i in seq_along(month_starts)) {
    ms <- month_starts[i]
    me <- month_end(ms)
    overlap_start <- max(start, ms)
    overlap_end   <- min(end, me)
    days_covered  <- as.numeric(overlap_end - overlap_start) + 1
    days_in_month <- as.numeric(me - ms) + 1
    total <- total + days_covered / days_in_month
  }
  round(total, 6)
}

# Default report period: from the first day of the earliest month in the data to
# the last day of the latest month. If there is no data, use the current month.
default_period <- function(income, expenses) {
  all_dates <- c(income$date, expenses$date)
  if (length(all_dates) == 0) {
    today <- Sys.Date()
    return(list(start = month_start(today), end = month_end(today)))
  }
  list(start = month_start(min(all_dates)), end = month_end(max(all_dates)))
}

# ---- Financial runway ---------------------------------------------------------------
# Returns a list with: runway (number or NA), runway_status, runway_message.
# It never divides by zero:
#   no_expenses  - burn rate is 0, so a runway cannot be calculated
#   insufficient - too little data for a trustworthy estimate
#   depleted     - savings are zero or negative, so the runway is 0 months
#   ok           - runway = available savings / burn rate
calc_runway <- function(available_savings, burn_rate, n_expense_records, months) {
  if (n_expense_records == 0 || burn_rate <= 0) {
    return(list(
      runway = NA_real_, runway_status = "no_expenses",
      runway_message = paste(
        "No expenses were recorded in the selected period, so the burn rate is",
        "zero and the runway cannot be calculated (at zero spending your",
        "savings would not be used up).")))
  }
  if (n_expense_records < MIN_EXPENSE_RECORDS || months < MIN_MONTHS) {
    return(list(
      runway = NA_real_, runway_status = "insufficient",
      runway_message = sprintf(
        paste("Insufficient data: at least %d expense records and %d month of",
              "data are needed for a reliable runway estimate."),
        MIN_EXPENSE_RECORDS, MIN_MONTHS)))
  }
  if (available_savings <= 0) {
    return(list(
      runway = 0, runway_status = "depleted",
      runway_message = paste(
        "Your available savings are zero or negative, so the estimated",
        "runway is 0 months.")))
  }
  runway <- available_savings / burn_rate
  list(
    runway = runway, runway_status = "ok",
    runway_message = sprintf(
      "At your average spending of %s per month, your available savings of %s would last about %.1f months.",
      format_money(burn_rate), format_money(available_savings), runway))
}

# Runway as short text for a dashboard card
format_runway <- function(s) {
  switch(s$runway_status,
         ok           = sprintf("%.1f months", s$runway),
         depleted     = "0 months",
         no_expenses  = "Not applicable",
         insufficient = "Insufficient data",
         "N/A")
}

# ---- Main summary ---------------------------------------------------------------------
# Calculates every headline number for the selected period [start, end].
calc_summary <- function(income, expenses, starting_balance, start, end) {
  inc_p <- filter_by_date(income, start, end)
  exp_p <- filter_by_date(expenses, start, end)

  total_income   <- sum(inc_p$amount)
  total_expenses <- sum(exp_p$amount)
  net_savings    <- total_income - total_expenses

  months    <- count_months(start, end)
  burn_rate <- if (months > 0) total_expenses / months else 0

  # Available savings = balance at the END of the selected period. It includes
  # all income and expenses recorded up to that date (also before the start
  # date) so the balance is always correct, whatever period is selected.
  income_to_date   <- sum(income$amount[income$date <= end])
  expenses_to_date <- sum(expenses$amount[expenses$date <= end])
  available_savings <- starting_balance + income_to_date - expenses_to_date

  runway <- calc_runway(available_savings, burn_rate, nrow(exp_p), months)

  c(list(
    start = start, end = end, months = months,
    total_income = total_income, total_expenses = total_expenses,
    net_savings = net_savings, burn_rate = burn_rate,
    starting_balance = starting_balance,
    income_to_date = income_to_date, expenses_to_date = expenses_to_date,
    available_savings = available_savings,
    n_income = nrow(inc_p), n_expenses = nrow(exp_p)
  ), runway)
}

# ---- Tables used by charts and reports ---------------------------------------------------

# Total spent per category, with the percentage of all spending
category_totals <- function(expenses) {
  totals <- vapply(EXPENSE_CATEGORIES,
                   function(cat) sum(expenses$amount[expenses$category == cat]),
                   numeric(1))
  out <- data.frame(category = EXPENSE_CATEGORIES,
                    amount = as.numeric(totals),
                    stringsAsFactors = FALSE)
  grand_total <- sum(out$amount)
  out$percent <- if (grand_total > 0) round(100 * out$amount / grand_total, 1) else 0
  out[order(-out$amount), , drop = FALSE]
}

empty_monthly <- function() {
  data.frame(month = as.Date(character(0)), month_label = character(0),
             income = numeric(0), expenses = numeric(0),
             net = numeric(0), savings = numeric(0),
             stringsAsFactors = FALSE)
}

# One row per calendar month in the period: income, expenses, net and the
# running savings balance at the end of that month.
monthly_summary <- function(income, expenses, starting_balance, start, end) {
  if (is.na(start) || is.na(end) || start > end) return(empty_monthly())

  months <- seq(month_start(start), month_start(end), by = "month")
  keys   <- format(months, "%Y-%m")

  inc_p <- filter_by_date(income, start, end)
  exp_p <- filter_by_date(expenses, start, end)
  inc_keys <- format(inc_p$date, "%Y-%m")
  exp_keys <- format(exp_p$date, "%Y-%m")

  inc_tot <- as.numeric(vapply(keys, function(k) sum(inc_p$amount[inc_keys == k]), numeric(1)))
  exp_tot <- as.numeric(vapply(keys, function(k) sum(exp_p$amount[exp_keys == k]), numeric(1)))

  # Balance just before the period starts
  opening <- starting_balance +
    sum(income$amount[income$date < start]) -
    sum(expenses$amount[expenses$date < start])

  net <- inc_tot - exp_tot
  data.frame(month = months,
             month_label = format(months, "%b %Y"),
             income = inc_tot, expenses = exp_tot, net = net,
             savings = opening + cumsum(net),
             stringsAsFactors = FALSE)
}

# Income and expenses in one table (used by the Transaction History page)
combine_transactions <- function(income, expenses) {
  inc <- data.frame(type = rep("Income", nrow(income)), id = income$id,
                    date = income$date, category = income$source,
                    amount = income$amount, note = income$note,
                    stringsAsFactors = FALSE)
  exp <- data.frame(type = rep("Expense", nrow(expenses)), id = expenses$id,
                    date = expenses$date, category = expenses$category,
                    amount = expenses$amount, note = expenses$note,
                    stringsAsFactors = FALSE)
  all_tx <- rbind(inc, exp)
  all_tx[order(all_tx$date, all_tx$id, decreasing = TRUE), , drop = FALSE]
}

# ---- Text tables for the Summary page and the downloadable report ---------------------------

summary_table <- function(s) {
  savings_rate <- if (s$total_income > 0) {
    sprintf("%.1f%%", 100 * s$net_savings / s$total_income)
  } else {
    "N/A"
  }
  data.frame(
    Metric = c("Report period", "Months in period", "Total income",
               "Total expenses", "Net savings (income - expenses)",
               "Savings rate (net savings / income)",
               "Monthly burn rate (average monthly spending)",
               "Starting savings", "Available savings",
               "Estimated financial runway",
               "Number of income records", "Number of expense records"),
    Value = c(paste(format(s$start), "to", format(s$end)),
              sprintf("%.2f", s$months),
              format_money(s$total_income),
              format_money(s$total_expenses),
              format_money(s$net_savings),
              savings_rate,
              format_money(s$burn_rate),
              format_money(s$starting_balance),
              format_money(s$available_savings),
              format_runway(s),
              as.character(s$n_income), as.character(s$n_expenses)),
    stringsAsFactors = FALSE)
}

# Plain-text report that the user can download
build_report_text <- function(s, cat_df) {
  tbl <- summary_table(s)
  lines <- c(
    toupper(APP_TITLE),
    "FINANCIAL SUMMARY REPORT",
    paste("Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M")),
    strrep("=", 60),
    paste0(format(tbl$Metric, width = 46), " : ", tbl$Value),
    strrep("-", 60),
    "SPENDING BY CATEGORY",
    paste0(format(cat_df$category, width = 16),
           format(format_money(cat_df$amount), width = 18, justify = "right"),
           format(sprintf("%.1f%%", cat_df$percent), width = 9, justify = "right")),
    strrep("-", 60),
    "Runway note:", s$runway_message,
    "",
    RUNWAY_DISCLAIMER
  )
  lines
}
