# Personal Finance Burn Rate Calculator

A beginner-friendly **R Shiny dashboard** that tracks income and expenses, calculates your
**monthly burn rate**, **available savings** and **financial runway**, and shows interactive
**ggplot2 charts**. All data is stored in plain **CSV files** - no database, no paid API and
no internet connection are needed once the packages are installed.

> Built as a B.Tech college project. The code is heavily commented so you can explain every part.

---

## 1. Project Introduction

Many students and young professionals do not know how long their savings would last if their
income stopped. This app answers that question with simple, transparent formulas:

* **Burn rate** - how much money you spend per month on average.
* **Runway** - for how many months your current savings can cover that spending.

The app comes with **realistic sample data** (6 months, April-September 2026) so that every page
shows meaningful results immediately. You can remove the sample data with one click and enter
your own.

## 2. Objectives

1. Record income and expenses in a simple, validated form.
2. Calculate net savings, monthly burn rate, available savings and financial runway correctly.
3. Visualise spending habits with clear, interactive charts.
4. Keep data permanently in CSV files so it survives restarting the application.
5. Handle bad input and special cases (zero expenses, too little data, missing files) safely.
6. Provide a clean, professional dashboard that is easy to use and to explain.

## 3. Features

| # | Feature | Where to find it |
|---|---------|------------------|
| 1 | Dashboard cards: total income, total expenses, current savings, monthly burn rate, estimated runway | **Dashboard** |
| 2 | Add, view, edit and delete income records | **Income** |
| 3 | Add, view, edit and delete expenses (Food, Education, Transport, Shopping, Bills, Entertainment, Others) | **Expenses** |
| 4 | Burn rate calculator with the amount spent each month | **Burn Rate & Savings** |
| 5 | Savings calculator (starting savings + income - expenses) | **Burn Rate & Savings** |
| 6 | Financial runway with handling for zero expenses / insufficient data / empty savings | **Dashboard**, **Burn Rate & Savings** |
| 7 | Four interactive charts: expense categories, monthly income vs expenses, savings trend, monthly burn rate | **Charts**, **Dashboard** |
| 8 | Transaction history table with type / category / date filters, search, multi-row delete, CSV download | **Transaction History** |
| 9 | CSV storage with safe handling of missing, empty or damaged files | automatic |
| 10 | Financial summary report (income, expenses, net savings, monthly spending) with a downloadable `.txt` report | **Financial Summary** |
| 11 | Global date filter, sidebar navigation, success/error messages, responsive layout | whole app |

## 4. Technologies Used

| Purpose | Technology |
|---------|-----------|
| Language | R (4.0 or newer recommended) |
| IDE | RStudio |
| User interface | `shiny` + `shinydashboard` |
| Charts | `ggplot2` (made interactive with `plotly`) |
| Tables | `DT` |
| Data storage | CSV files (`utils::read.csv` / `write.csv`) |
| Data analysis | R data frames and base R functions (no extra data packages) |

## 5. Folder Structure

```
PERSONAL_FINANCE_BURN_RATE_CALCULATOR/
├── app.R                  <- the Shiny app (user interface + server logic). Run this file.
├── PERSONAL_FINANCE_BURN_RATE_CALCULATOR.Rproj   <- double-click to open the project in RStudio
├── README.md              <- this documentation
├── requirements.R         <- installs the required packages
├── .gitignore
├── data/
│   ├── income.csv         <- income records  (sample data included)
│   ├── expenses.csv       <- expense records (sample data included)
│   └── settings.csv       <- starting savings (sample value: 15000)
├── R/
│   ├── config.R           <- constants: currency, categories, colours, disclaimer
│   ├── calculations.R     <- ALL formulas (burn rate, savings, runway, summaries)
│   ├── data_management.R  <- reading / writing CSV files, validation, add/edit/delete
│   └── charts.R           <- ggplot2 chart functions
└── screenshots/           <- put your own screenshots here for your project report
```

`config.R` and the `.Rproj` file were added to the structure you asked for: `config.R` keeps all
settings in one place and the `.Rproj` file makes RStudio start in the correct folder.

## 6. Required R Packages

| Package | Used for |
|---------|----------|
| `shiny` | web application framework |
| `shinydashboard` | sidebar, boxes and dashboard cards |
| `ggplot2` | charts |
| `plotly` | interactive (hover / zoom) charts |
| `DT` | searchable, sortable tables |
| `scales` | number formatting on chart axes |

## 7. Installation Instructions

1. Install **R** from <https://cran.r-project.org/> and **RStudio Desktop** from <https://posit.co/download/rstudio-desktop/>.
2. Extract `PERSONAL_FINANCE_BURN_RATE_CALCULATOR.zip` (right-click -> *Extract All...*).
   Do **not** run the app from inside the ZIP file.
3. Install the packages **once** (needs internet only for this step) - see the steps below.

## 8. How to Open and Run the Project in RStudio (Windows)

1. Open the extracted folder and **double-click `PERSONAL_FINANCE_BURN_RATE_CALCULATOR.Rproj`**.
   RStudio opens with the correct working folder.
   *(Alternative: in RStudio use **File -> Open File...**, choose `app.R`, then
   **Session -> Set Working Directory -> To Source File Location**.)*
2. In the **Console** (bottom-left) type the command below and press Enter. Wait until it says
   *"Success! You can now open app.R..."*

   ```r
   source("requirements.R")
   ```
3. In the **Files** pane click **`app.R`** to open it.
4. Click the green **▶ Run App** button at the top-right of the editor.
   *(Choose **Run External** in the dropdown next to the button if you prefer your web browser.)*
5. The dashboard opens with the sample data already loaded. To stop the app, click the red
   **stop** button in the Console, or press **Esc**.

> Use **Run App** (not "Source"). From the second run onward you only need steps 1, 3 and 4.

## 9. Adding, Editing and Deleting Transactions

**Add** (Income or Expenses page, form on the left)

1. Pick the **date**, the **source / category**, type the **amount** and an optional **note**.
2. Press **Add Income** / **Add Expense**. A green message confirms the save and the record
   appears in the table immediately. The record is saved to the CSV file straight away.
3. If the new date lies outside the current report period, the period is widened automatically.

**Edit**

1. Click a row in the table. Its values are copied into the *Edit or Delete Selected Record* box.
2. Change the values and press **Update**.

**Delete**

* *Income / Expenses pages:* click a row -> press **Delete** -> confirm.
* *Transaction History page:* tick one or more rows (hold **Ctrl** or **Shift** to select several)
  -> **Delete selected rows** -> confirm. Use the filters above the table to find records quickly.

**Using your own data instead of the sample data**

1. Open **Settings & Data** -> press **Remove sample data** (deletes only records whose note starts
   with `[SAMPLE]` and sets the starting savings to 0).
2. Enter your **starting savings** (money you had before your first record) and press *Save*.
3. Start adding your own income and expenses.

*(Advanced: you can also edit `data/income.csv` and `data/expenses.csv` in Excel/Notepad while the app is
closed. Keep the header row, use dates like `2026-10-05`, and use the allowed categories.)*

## 10. Explanation of the Formulas

| Value | Formula |
|-------|---------|
| **Net Savings** | Total Income - Total Expenses *(selected period)* |
| **Monthly Burn Rate** | Total Expenses in the selected period / Number of months in that period |
| **Available Savings** | Starting Savings + Total Income - Total Expenses *(up to the end of the period)* |
| **Financial Runway** | Available Savings / Monthly Burn Rate *(in months)* |

**How the number of months is counted.** Every calendar month touched by the selected period
counts by the fraction of it that is covered. `1 Apr - 30 Sep` is exactly **6.00** months;
`1 Apr - 15 Apr` is 15/30 = **0.50** months. This keeps the burn rate consistent for any date range.

**Available savings** is the balance at the *end* of the selected period, so it includes all
income and expenses recorded up to that date (even from before the period start). With the default
period (all data) it is exactly `Starting Savings + all income - all expenses`.

**Special cases for the runway** (no division by zero):

| Situation | What is shown |
|-----------|---------------|
| No expenses in the period (burn rate = 0) | "Not applicable" + explanation |
| Fewer than 3 expense records or less than 1 month | "Insufficient data" + explanation |
| Available savings <= 0 | "0 months" + warning |
| Otherwise | e.g. "4.4 months" |

> **Important:** the runway is an **estimate, not a financial guarantee**. It assumes your future
> spending and income stay the same as the average of the selected period.

## 11. Sample Output Description

With the included sample data (16 income and 90 expense records, 1 Apr - 30 Sep 2026, starting
savings Rs. 15,000) the **Dashboard** should show these values. They were calculated independently
from the CSV files:

| Dashboard card | Value |
|----------------|-------|
| Total Income | Rs. 116,300.00 |
| Total Expenses | Rs. 75,936.00 |
| Current Savings (available) | Rs. 55,364.00 |
| Monthly Burn Rate | Rs. 12,656.00 (75,936 / 6 months) |
| Estimated Financial Runway | 4.4 months (55,364 / 12,656 = 4.37) |
| Net Savings | Rs. 40,364.00 |

Spending by category: Food 43.9 %, Education 13.7 %, Shopping 13.4 %, Bills 9.9 %,
Transport 8.4 %, Entertainment 8.2 %, Others 2.4 %.

| Month | Income | Expenses | Net | Savings balance |
|-------|-------:|---------:|----:|----------------:|
| Apr 2026 | 15,500 | 11,818 | 3,682 | 18,682 |
| May 2026 | 20,200 | 11,137 | 9,063 | 27,745 |
| Jun 2026 | 13,800 | 10,198 | 3,602 | 31,347 |
| Jul 2026 | 29,500 | 12,148 | 17,352 | 48,699 |
| Aug 2026 | 22,500 | 19,467 | 3,033 | 51,732 |
| Sep 2026 | 14,800 | 11,168 | 3,632 | 55,364 |

August shows a spending spike (shopping and a weekend trip), which is visible in the charts.

**Pages:** *Dashboard* (5 cards, runway note, 2 charts) · *Income / Expenses* (form + table) ·
*Burn Rate & Savings* (step-by-step calculators and monthly spending table) · *Charts* (4 interactive
charts) · *Transaction History* (filters, search, delete, download) · *Financial Summary* (report tables)
· *Settings & Data* (starting savings, sample data, formulas).

## 12. Troubleshooting Common Errors

| Problem / message | Solution |
|-------------------|----------|
| `Missing R packages: ...` | Run `source("requirements.R")` in the Console, then run the app again. |
| `there is no package called 'xyz'` | `install.packages("xyz")`, or re-run `requirements.R`. |
| `Cannot find the 'R' folder` | Open the project through the `.Rproj` file, or use *Session -> Set Working Directory -> To Source File Location*. |
| Package installation fails | Check your internet connection / firewall. Choose a CRAN mirror when asked. Update R if the message says a package needs a newer R version. |
| "Could not save the data file" | The CSV is probably **open in Excel** (Windows locks open files). Close it and try again. |
| Charts or tables stay empty | Check the **date filter** in the sidebar and press **Show all data**. |
| The app shows no data at all | `data/` files may be missing. Start the app once - empty files are created automatically. Re-extract the ZIP to restore the sample data. |
| A warning about a CSV file with wrong columns | The app keeps a backup (`*.csv.bak`) and starts with empty data. Fix the header row to `id,date,source,amount,note` (income) or `id,date,category,amount,note` (expenses). |
| Want a different currency symbol | Change `CURRENCY` in `R/config.R` (for example `"$ "`). |
| Port already in use / app does not stop | Click the red stop button in the Console, or restart RStudio (*Session -> Restart R*). |
| Blank page in the RStudio viewer | Click **Open in Browser** at the top of the viewer window. |

## 13. Suggested Manual Test Checklist

Use this list to verify the app on your machine (and to demonstrate it in your viva):

1. Run the app - the dashboard shows the values from section 11.
2. Add an income and an expense - messages appear, cards and charts update, the CSV file changes.
3. Try an invalid entry (empty amount, negative amount) - a red error message appears.
4. Select a record, change the amount, press **Update** - the table and cards update.
5. Delete a record - confirmation dialog, then the record disappears.
6. Set the date filter to a month without expenses - runway shows *Not applicable*.
7. Close and re-run the app - your changes are still there (saved in CSV).
8. Rename `data/expenses.csv` temporarily and start the app - it starts without error and creates a new empty file.

## 14. Future Enhancements

* Budget limits per category with warnings when exceeded.
* Recurring transactions (rent, subscriptions, salary).
* Import bank statements (CSV / Excel).
* Multiple users with login, or multiple accounts / wallets.
* Forecasting future savings with a trend line and what-if scenarios (e.g. "cut food spending by 10 %").
* Export reports as PDF or Excel.
* Dark mode and more currencies.
* Unit tests for the formulas using the `testthat` package.

---

*Disclaimer: This project is for learning and personal tracking. The runway and other figures are
estimates and are not financial advice or a guarantee.*
