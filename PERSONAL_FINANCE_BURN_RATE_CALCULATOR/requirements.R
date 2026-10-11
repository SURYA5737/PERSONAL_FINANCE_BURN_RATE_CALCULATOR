# =============================================================================
# requirements.R  -  Installs the R packages needed by the app
# =============================================================================
# Run this file ONCE (it needs an internet connection only for this step):
#   In RStudio:  source("requirements.R")
#
# After the packages are installed, the app runs completely offline.

required_packages <- c(
  "shiny",           # web application framework
  "shinydashboard",  # dashboard layout (sidebar, boxes, value boxes)
  "ggplot2",         # charts
  "plotly",          # makes ggplot2 charts interactive
  "DT",              # interactive tables (search, sort, select)
  "scales"           # number formatting on chart axes (also installed with ggplot2)
)

installed <- rownames(installed.packages())
to_install <- setdiff(required_packages, installed)

if (length(to_install) > 0) {
  message("Installing missing packages: ", paste(to_install, collapse = ", "))
  install.packages(to_install, repos = "https://cloud.r-project.org")
} else {
  message("All required packages are already installed.")
}

# Final check
still_missing <- setdiff(required_packages, rownames(installed.packages()))
if (length(still_missing) > 0) {
  warning("These packages could NOT be installed: ",
          paste(still_missing, collapse = ", "),
          ". Check your internet connection and read the Troubleshooting section of README.md.")
} else {
  message("Success! You can now open app.R and click 'Run App'.")
}
