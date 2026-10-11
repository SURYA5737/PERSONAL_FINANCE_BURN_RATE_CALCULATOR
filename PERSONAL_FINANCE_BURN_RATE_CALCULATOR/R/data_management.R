# =============================================================================
# data_management.R  -  Reading, validating and saving data in CSV files
# =============================================================================
# Files used (inside the data/ folder):
#   income.csv    columns: id, date, source,   amount, note
#   expenses.csv  columns: id, date, category, amount, note
#   settings.csv  column : starting_balance
#
# Every function that changes data returns list(ok = TRUE/FALSE, message = "...")
# so the app can show a clear success or error message.

INCOME_COLS  <- c("id", "date", "source", "amount", "note")
EXPENSE_COLS <- c("id", "date", "category", "amount", "note")

SAVE_ERROR_MSG <- paste(
  "Could not save the data file. If the CSV file is open in Excel, close it",
  "and try again. Also check that the 'data' folder is writable.")

# ---- Empty tables -------------------------------------------------------------------

empty_income <- function() {
  data.frame(id = integer(0), date = as.Date(character(0)),
             source = character(0), amount = numeric(0),
             note = character(0), stringsAsFactors = FALSE)
}

empty_expenses <- function() {
  data.frame(id = integer(0), date = as.Date(character(0)),
             category = character(0), amount = numeric(0),
             note = character(0), stringsAsFactors = FALSE)
}

# ---- Low-level CSV helpers --------------------------------------------------------------

# Write a data frame to CSV. Returns TRUE on success and FALSE on any problem
# (for example when the file is locked by Excel on Windows).
safe_write_csv <- function(df, path) {
  tryCatch({
    if (!dir.exists(dirname(path))) dir.create(dirname(path), recursive = TRUE)
    out <- df
    if ("date" %in% names(out)) out$date <- format(out$date, "%Y-%m-%d")
    utils::write.csv(out, path, row.names = FALSE, fileEncoding = "UTF-8")
    TRUE
  },
  error   = function(e) FALSE,
  warning = function(w) FALSE)
}

# Read a transaction CSV. Missing file, empty file, wrong columns or bad rows
# never crash the app: you simply get an empty (or cleaned) table back.
read_transactions <- function(path, required_cols, empty_fn) {
  if (!file.exists(path)) return(empty_fn())

  df <- tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character",
                    na.strings = c("NA", ""), encoding = "UTF-8"),
    error = function(e) NULL)

  if (is.null(df) || !all(required_cols %in% names(df))) {
    # Keep a backup copy so a damaged file is never lost by accident
    if (file.size(path) > 0) {
      try(file.copy(path, paste0(path, ".bak"), overwrite = TRUE), silent = TRUE)
    }
    warning("File '", path, "' is empty or has wrong columns. Using empty data. ",
            "A backup was saved as '", basename(path), ".bak'.", call. = FALSE)
    return(empty_fn())
  }

  df <- df[, required_cols, drop = FALSE]
  df$id     <- suppressWarnings(as.integer(df$id))
  df$date   <- as.Date(df$date, format = "%Y-%m-%d")
  df$amount <- suppressWarnings(as.numeric(df$amount))
  df$note[is.na(df$note)] <- ""

  # Drop rows that cannot be used (missing id, bad date or bad amount)
  keep <- !is.na(df$id) & !is.na(df$date) & !is.na(df$amount)
  df <- df[keep, , drop = FALSE]
  df <- df[order(df$date, df$id), , drop = FALSE]
  rownames(df) <- NULL
  df
}

read_income <- function() {
  df <- read_transactions(INCOME_FILE, INCOME_COLS, empty_income)
  df$source[is.na(df$source)] <- "Other Income"
  df
}

read_expenses <- function() {
  df <- read_transactions(EXPENSES_FILE, EXPENSE_COLS, empty_expenses)
  # Unknown or missing categories are counted under "Others"
  df$category[is.na(df$category) | !(df$category %in% EXPENSE_CATEGORIES)] <- "Others"
  df
}

# Next free record id
next_id <- function(df) {
  if (nrow(df) == 0) 1L else as.integer(max(df$id) + 1L)
}

# ---- Starting balance (settings.csv) -----------------------------------------------------

read_starting_balance <- function() {
  if (!file.exists(SETTINGS_FILE)) return(0)
  df <- tryCatch(utils::read.csv(SETTINGS_FILE, stringsAsFactors = FALSE),
                 error = function(e) NULL)
  if (is.null(df) || nrow(df) == 0 || !("starting_balance" %in% names(df))) return(0)
  val <- suppressWarnings(as.numeric(df$starting_balance[1]))
  if (is.na(val)) 0 else val
}

save_starting_balance <- function(value) {
  if (is.null(value) || length(value) != 1 || is.na(value) || !is.finite(value)) {
    return(list(ok = FALSE, message = "Starting savings must be a number."))
  }
  if (value < 0) {
    return(list(ok = FALSE, message = "Starting savings cannot be negative."))
  }
  if (value > 1e9) {
    return(list(ok = FALSE, message = "Starting savings is too large."))
  }
  if (!safe_write_csv(data.frame(starting_balance = round(value, 2)), SETTINGS_FILE)) {
    return(list(ok = FALSE, message = SAVE_ERROR_MSG))
  }
  list(ok = TRUE, message = "Starting savings saved.")
}

# ---- Create missing files ----------------------------------------------------------------------

# Called once when the app starts. Missing files are created with only a header
# row, so a fresh copy of the project (or a deleted CSV) never causes an error.
init_data_files <- function() {
  if (!dir.exists(DATA_DIR)) dir.create(DATA_DIR, recursive = TRUE)
  if (!file.exists(INCOME_FILE))   safe_write_csv(empty_income(), INCOME_FILE)
  if (!file.exists(EXPENSES_FILE)) safe_write_csv(empty_expenses(), EXPENSES_FILE)
  if (!file.exists(SETTINGS_FILE)) safe_write_csv(data.frame(starting_balance = 0), SETTINGS_FILE)
  invisible(TRUE)
}

# ---- Validation ---------------------------------------------------------------------------------------

# Returns NULL when everything is valid, otherwise a text describing the problem.
validate_transaction <- function(date, label, amount, choices, label_name) {
  if (is.null(date) || length(date) != 1 || is.na(date)) {
    return("Please select a valid date.")
  }
  d <- as.Date(date)
  if (d < as.Date("1990-01-01") || d > as.Date("2100-12-31")) {
    return("The date must be between 1990 and 2100.")
  }
  if (is.null(label) || length(label) != 1 || !(label %in% choices)) {
    return(paste("Please choose a valid", label_name, "from the list."))
  }
  if (is.null(amount) || length(amount) != 1 || is.na(amount) || !is.finite(amount)) {
    return("Please enter the amount as a number.")
  }
  if (amount <= 0) {
    return("The amount must be greater than zero.")
  }
  if (amount > 1e9) {
    return("The amount is too large.")
  }
  NULL
}

# Remove line breaks, trim spaces and limit the length of a note
clean_note <- function(note) {
  if (is.null(note) || length(note) != 1 || is.na(note)) return("")
  note <- gsub("[\r\n]+", " ", trimws(as.character(note)))
  substr(note, 1, 200)
}

# Settings that differ between income and expense records
record_config <- function(type) {
  if (type == "income") {
    list(file = INCOME_FILE, label_col = "source", choices = INCOME_SOURCES,
         label_name = "income source", reader = read_income)
  } else {
    list(file = EXPENSES_FILE, label_col = "category", choices = EXPENSE_CATEGORIES,
         label_name = "expense category", reader = read_expenses)
  }
}

# ---- Add / update / delete (type is "income" or "expense") ---------------------------------------------

add_record <- function(type, date, label, amount, note = "") {
  cfg <- record_config(type)
  err <- validate_transaction(date, label, amount, cfg$choices, cfg$label_name)
  if (!is.null(err)) return(list(ok = FALSE, message = err))

  df <- cfg$reader()
  new_row <- data.frame(id = next_id(df), date = as.Date(date), label = label,
                        amount = round(amount, 2), note = clean_note(note),
                        stringsAsFactors = FALSE)
  names(new_row)[3] <- cfg$label_col
  df <- rbind(df, new_row)

  if (!safe_write_csv(df, cfg$file)) return(list(ok = FALSE, message = SAVE_ERROR_MSG))
  list(ok = TRUE, message = paste0(
    if (type == "income") "Income" else "Expense", " record added successfully."))
}

update_record <- function(type, id, date, label, amount, note = "") {
  cfg <- record_config(type)
  err <- validate_transaction(date, label, amount, cfg$choices, cfg$label_name)
  if (!is.null(err)) return(list(ok = FALSE, message = err))

  df  <- cfg$reader()
  idx <- which(df$id == id)
  if (length(idx) != 1) {
    return(list(ok = FALSE, message = "That record could not be found. Please select it again."))
  }
  df$date[idx]            <- as.Date(date)
  df[[cfg$label_col]][idx] <- label
  df$amount[idx]          <- round(amount, 2)
  df$note[idx]            <- clean_note(note)

  if (!safe_write_csv(df, cfg$file)) return(list(ok = FALSE, message = SAVE_ERROR_MSG))
  list(ok = TRUE, message = "Record updated successfully.")
}

delete_records <- function(type, ids) {
  cfg <- record_config(type)
  if (length(ids) == 0) {
    return(list(ok = FALSE, message = "No record selected."))
  }
  df   <- cfg$reader()
  keep <- !(df$id %in% ids)
  n_deleted <- sum(!keep)
  if (n_deleted == 0) {
    return(list(ok = FALSE, message = "Nothing was deleted (record not found)."))
  }
  if (!safe_write_csv(df[keep, , drop = FALSE], cfg$file)) {
    return(list(ok = FALSE, message = SAVE_ERROR_MSG))
  }
  list(ok = TRUE, message = sprintf("%d record(s) deleted.", n_deleted))
}

# ---- Sample data ---------------------------------------------------------------------------------------------

# TRUE if any record still carries the [SAMPLE] tag
has_sample_data <- function(income, expenses) {
  any(startsWith(income$note, SAMPLE_TAG)) || any(startsWith(expenses$note, SAMPLE_TAG))
}

# Delete only the sample records (your own records stay) and set the starting
# savings back to 0.
remove_sample_data <- function() {
  inc <- read_income()
  exp <- read_expenses()
  ok1 <- safe_write_csv(inc[!startsWith(inc$note, SAMPLE_TAG), , drop = FALSE], INCOME_FILE)
  ok2 <- safe_write_csv(exp[!startsWith(exp$note, SAMPLE_TAG), , drop = FALSE], EXPENSES_FILE)
  ok3 <- safe_write_csv(data.frame(starting_balance = 0), SETTINGS_FILE)
  if (!(ok1 && ok2 && ok3)) return(list(ok = FALSE, message = SAVE_ERROR_MSG))
  list(ok = TRUE, message = "Sample data removed. The app is now ready for your own data.")
}
