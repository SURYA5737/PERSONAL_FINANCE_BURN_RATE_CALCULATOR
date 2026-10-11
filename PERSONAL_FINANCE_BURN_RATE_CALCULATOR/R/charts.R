# =============================================================================
# charts.R  -  ggplot2 chart functions
# =============================================================================
# Each function receives a data frame and returns a ggplot object. app.R turns
# them into interactive charts with plotly::ggplotly(). When there is nothing to
# draw, a friendly "No data" picture is returned instead of an error.

suppressPackageStartupMessages(library(ggplot2))

# Common look for all charts
theme_finance <- function() {
  theme_minimal(base_size = 13) +
    theme(plot.title = element_text(face = "bold"),
          legend.position = "bottom",
          panel.grid.minor = element_blank())
}

# Y-axis title that mentions the currency
amount_axis_title <- function() {
  paste0("Amount (", trimws(CURRENCY), ")")
}

# Placeholder chart used when there is no data
empty_plot <- function(msg = "No data available for the selected period") {
  ggplot() +
    annotate("text", x = 0, y = 0, label = msg, size = 5, colour = "grey40") +
    theme_void()
}

# 1. Expenses by category (horizontal bars, largest on top)
plot_category_expenses <- function(cat_df) {
  d <- cat_df[cat_df$amount > 0, , drop = FALSE]
  if (nrow(d) == 0) return(empty_plot("No expenses in the selected period"))

  d$category <- factor(d$category, levels = rev(d$category))
  ggplot(d, aes(x = category, y = amount, fill = category)) +
    geom_col(width = 0.7) +
    coord_flip() +
    scale_fill_manual(values = CATEGORY_COLORS, guide = "none") +
    scale_y_continuous(labels = scales::comma) +
    labs(title = "Expenses by Category", x = NULL, y = amount_axis_title()) +
    theme_finance()
}

# 2. Monthly income versus expenses (grouped bars)
plot_income_vs_expenses <- function(ms) {
  if (nrow(ms) == 0 || (sum(ms$income) == 0 && sum(ms$expenses) == 0)) {
    return(empty_plot())
  }
  long <- rbind(
    data.frame(month_label = ms$month_label, type = "Income",
               amount = ms$income, stringsAsFactors = FALSE),
    data.frame(month_label = ms$month_label, type = "Expenses",
               amount = ms$expenses, stringsAsFactors = FALSE))
  long$month_label <- factor(long$month_label, levels = ms$month_label)

  ggplot(long, aes(x = month_label, y = amount, fill = type)) +
    geom_col(position = "dodge", width = 0.7) +
    scale_fill_manual(values = c(Income = COLOR_INCOME, Expenses = COLOR_EXPENSE),
                      name = NULL) +
    scale_y_continuous(labels = scales::comma) +
    labs(title = "Monthly Income vs Expenses", x = NULL, y = amount_axis_title()) +
    theme_finance()
}

# 3. Savings trend: running savings balance at the end of each month
plot_savings_trend <- function(ms) {
  if (nrow(ms) == 0) return(empty_plot())
  ms$month_label <- factor(ms$month_label, levels = ms$month_label)

  ggplot(ms, aes(x = month_label, y = savings, group = 1)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
    geom_line(colour = COLOR_SAVINGS, linewidth = 1.1) +
    geom_point(colour = COLOR_SAVINGS, size = 3) +
    scale_y_continuous(labels = scales::comma) +
    labs(title = "Savings Trend (balance at end of each month)",
         x = NULL, y = amount_axis_title()) +
    theme_finance()
}

# 4. Monthly spending with the average burn rate as a dashed line
plot_monthly_burn <- function(ms, burn_rate) {
  if (nrow(ms) == 0 || sum(ms$expenses) == 0) {
    return(empty_plot("No expenses in the selected period"))
  }
  ms$month_label <- factor(ms$month_label, levels = ms$month_label)

  ggplot(ms, aes(x = month_label, y = expenses)) +
    geom_col(fill = COLOR_EXPENSE, alpha = 0.8, width = 0.7) +
    geom_hline(yintercept = burn_rate, linetype = "dashed", colour = "grey20") +
    scale_y_continuous(labels = scales::comma) +
    labs(title = paste0("Monthly Spending vs Average Burn Rate (",
                        format_money(burn_rate, 0), ")"),
         x = NULL, y = amount_axis_title()) +
    theme_finance()
}
