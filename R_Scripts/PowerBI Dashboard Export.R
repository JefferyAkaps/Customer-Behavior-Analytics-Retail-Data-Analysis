# ============================================================================
# TABLEAU DASHBOARD DATA EXPORT PIPELINE
# ============================================================================
#
# Description:
# This script creates professional-grade, analytics-ready datasets optimized
# for PowerBI dashboard development. Transforms customer analytics database
# into business-friendly Excel datasets with pre-calculated metrics, 
# segmentation logic, and executive-ready insights for stakeholder reporting.
# ============================================================================

# ============================================================================
# ENVIRONMENT SETUP AND PACKAGE LOADING
# ============================================================================

# Load required packages for data export and business intelligence
suppressPackageStartupMessages({
  library(RMySQL)      # MySQL database connectivity
  library(DBI)         # Database interface
  library(openxlsx)    # Professional Excel export capabilities
  library(dplyr)       # Advanced data manipulation
})

# ============================================================================
# CONFIGURATION AND SETUP
# ============================================================================

# Database connection parameters (CONFIGURE FOR YOUR ENVIRONMENT)
# For production: Use environment variables or secure config files
DB_USER <- Sys.getenv("DB_USER", "your_mysql_username")
DB_PASSWORD <- Sys.getenv("DB_PASSWORD", "your_mysql_password")
DB_NAME <- "CustomerAnalyticsDB"
DB_HOST <- Sys.getenv("DB_HOST", "localhost")
DB_PORT <- as.numeric(Sys.getenv("DB_PORT", "3306"))

# Export configuration
export_dir <- "~/Desktop/PowerBI_dashboard/"
main_file_name <- "customer_analytics_dashboard_data.xlsx"

# Create export directory with error handling
tryCatch({
  dir.create(export_dir, showWarnings = FALSE, recursive = TRUE)
  cat("✅ Export directory created:", export_dir, "\n")
}, error = function(e) {
  stop("❌ Failed to create export directory: ", e$message)
})

# ============================================================================
# DATABASE CONNECTION
# ============================================================================
cat("\nEstablishing database connection for data extraction...\n")

# Secure database connection with error handling
tryCatch({
  con <- dbConnect(
    MySQL(),
    user = DB_USER,
    password = DB_PASSWORD,
    dbname = DB_NAME,
    host = DB_HOST,
    port = DB_PORT
  )
  cat("✅ Database connection established successfully\n\n")
}, error = function(e) {
  stop("❌ Database connection failed: ", e$message)
})

# ============================================================================
# DATASET 1: EXECUTIVE SUMMARY METRICS
# ============================================================================
# Purpose: High-level KPIs for C-level executive dashboard
# Business Value: Immediate strategic insights and performance indicators
# ============================================================================
cat("Creating Executive Summary dataset...\n")

tryCatch({
  # Extract key business metrics with optimized queries
  total_customers <- dbGetQuery(con, "SELECT COUNT(*) as value FROM v_customer_summary")$value
  total_revenue <- dbGetQuery(con, "SELECT ROUND(SUM(TotalRevenue), 0) as value FROM v_customer_summary")$value
  avg_customer_value <- dbGetQuery(con, "SELECT ROUND(AVG(TotalRevenue), 0) as value FROM v_customer_summary")$value
  countries_served <- dbGetQuery(con, "SELECT COUNT(DISTINCT Country) as value FROM v_customer_summary")$value
  repeat_rate <- dbGetQuery(con, "SELECT ROUND(COUNT(CASE WHEN TotalOrders > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as value FROM v_customer_summary")$value
  
  # Create executive summary dataframe with business context
  executive_summary <- data.frame(
    Metric = c("Total Customers", "Total Revenue", "Average Customer Value", "Countries Served", "Repeat Customer Rate"),
    Value = c(total_customers, total_revenue, avg_customer_value, countries_served, repeat_rate),
    Unit = c("customers", "dollars", "dollars", "countries", "percent"),
    SortOrder = 1:5,
    Business_Context = c(
      "Active customer base size",
      "Total revenue generated", 
      "Customer lifetime value",
      "Geographic market reach",
      "Customer retention success"
    ),
    stringsAsFactors = FALSE
  )
  
  cat("✅ Executive Summary:", nrow(executive_summary), "key metrics\n")
  
}, error = function(e) {
  stop("❌ Executive Summary creation failed: ", e$message)
})

# ============================================================================
# DATASET 2: CUSTOMER SEGMENTATION ANALYSIS
# ============================================================================
# Purpose: Customer value segmentation for targeted marketing strategies
# Business Value: Precision targeting and resource allocation optimization
# ============================================================================
cat("Creating Customer Segmentation dataset...\n")

tryCatch({
  # Extract customer segmentation data with business metrics
  customer_segmentation <- dbGetQuery(con, "
    SELECT 
      CustomerSegment,
      COUNT(*) as CustomerCount,
      ROUND(AVG(TotalRevenue), 0) as AvgCustomerValue,
      ROUND(SUM(TotalRevenue), 0) as SegmentRevenue,
      ROUND(AVG(TotalOrders), 1) as AvgOrdersPerCustomer,
      ROUND(AVG(AvgTransactionValue), 0) as AvgTransactionValue
    FROM v_customer_summary
    GROUP BY CustomerSegment
    ORDER BY AvgCustomerValue DESC
  ")
  
  # Add business intelligence calculations in R for better control
  customer_segmentation$CustomerPercentage <- round(
    (customer_segmentation$CustomerCount / sum(customer_segmentation$CustomerCount)) * 100, 1
  )
  
  customer_segmentation$RevenuePercentage <- round(
    (customer_segmentation$SegmentRevenue / sum(customer_segmentation$SegmentRevenue)) * 100, 1
  )
  
  # Add professional color coding for PowerBI visualization
  customer_segmentation$SegmentColor <- case_when(
    customer_segmentation$CustomerSegment == 'VIP Customer' ~ '#1f77b4',
    customer_segmentation$CustomerSegment == 'High Value' ~ '#ff7f0e', 
    customer_segmentation$CustomerSegment == 'Medium Value' ~ '#2ca02c',
    TRUE ~ '#d62728'
  )
  
  # Add strategic recommendations
  customer_segmentation$Marketing_Strategy <- case_when(
    customer_segmentation$CustomerSegment == 'VIP Customer' ~ 'White-glove service, exclusive access',
    customer_segmentation$CustomerSegment == 'High Value' ~ 'Loyalty programs, premium offerings',
    customer_segmentation$CustomerSegment == 'Medium Value' ~ 'Engagement campaigns, upselling',
    TRUE ~ 'Reactivation campaigns, value optimization'
  )
  
  cat("✅ Customer Segmentation:", nrow(customer_segmentation), "segments\n")
  
}, error = function(e) {
  stop("❌ Customer Segmentation creation failed: ", e$message)
})

# ============================================================================
# DATASET 3: GEOGRAPHIC PERFORMANCE ANALYSIS
# ============================================================================
# Purpose: Market performance analysis for expansion and resource allocation
# Business Value: Geographic strategy optimization and market prioritization
# ============================================================================
cat("Creating Geographic Performance dataset...\n")

tryCatch({
  # Extract geographic performance metrics
  geographic_performance <- dbGetQuery(con, "
    SELECT 
      Country,
      COUNT(*) as TotalCustomers,
      ROUND(AVG(TotalOrders), 1) as AvgOrdersPerCustomer,
      ROUND(AVG(TotalRevenue), 0) as AvgRevenuePerCustomer,
      ROUND(SUM(TotalRevenue), 0) as CountryTotalRevenue,
      ROUND(AVG(CustomerLifetimeDays), 0) as AvgCustomerLifetimeDays,
      ROUND(AVG(UniqueProductsPurchased), 1) as AvgProductsPerCustomer
    FROM v_customer_summary
    GROUP BY Country
    HAVING TotalCustomers >= 5
    ORDER BY CountryTotalRevenue DESC
  ")
  
  # Add market classification logic in R
  geographic_performance$MarketSize <- case_when(
    geographic_performance$CountryTotalRevenue >= 1000000 ~ 'Major Market',
    geographic_performance$CountryTotalRevenue >= 100000 ~ 'Significant Market', 
    geographic_performance$CountryTotalRevenue >= 10000 ~ 'Emerging Market',
    TRUE ~ 'Small Market'
  )
  
  # Calculate VIP customer percentage by country (safe approach)
  geographic_performance$VIPCustomerPercentage <- 0  # Initialize
  
  for(i in 1:nrow(geographic_performance)) {
    country <- geographic_performance$Country[i]
    
    # Safe query with binary comparison to avoid collation issues
    country_customers <- dbGetQuery(con, paste0(
      "SELECT CustomerSegment FROM v_customer_summary WHERE Country = BINARY '", country, "'"
    ))
    
    if(nrow(country_customers) > 0) {
      vip_pct <- sum(country_customers$CustomerSegment == 'VIP Customer') / nrow(country_customers) * 100
      geographic_performance$VIPCustomerPercentage[i] <- round(vip_pct, 1)
    }
  }
  
  cat("✅ Geographic Performance:", nrow(geographic_performance), "countries\n")
  
}, error = function(e) {
  stop("❌ Geographic Performance creation failed: ", e$message)
})

# ============================================================================
# DATASET 4: CUSTOMER BEHAVIOR TRENDS ANALYSIS
# ============================================================================
# Purpose: Customer lifecycle and purchasing behavior insights
# Business Value: Customer journey optimization and retention strategies
# ============================================================================
cat("Creating Customer Behavior Trends dataset...\n")

tryCatch({
  # Extract customer behavior patterns
  customer_trends <- dbGetQuery(con, "
    SELECT 
      CASE 
        WHEN TotalOrders = 1 THEN 'One-time Buyer'
        WHEN TotalOrders <= 3 THEN 'Occasional (2-3 orders)'
        WHEN TotalOrders <= 10 THEN 'Regular (4-10 orders)'
        ELSE 'Frequent (10+ orders)'
      END as CustomerBehaviorType,
      COUNT(*) as CustomerCount,
      ROUND(AVG(TotalRevenue), 0) as AvgCustomerValue,
      ROUND(SUM(TotalRevenue), 0) as TypeRevenue,
      ROUND(AVG(AvgTransactionValue), 0) as AvgTransactionValue,
      ROUND(AVG(TotalOrders), 1) as AvgOrdersPerCustomer
    FROM v_customer_summary
    GROUP BY CustomerBehaviorType
    ORDER BY AvgCustomerValue DESC
  ")
  
  # Add percentage calculations and strategic insights
  customer_trends$CustomerPercentage <- round(
    (customer_trends$CustomerCount / sum(customer_trends$CustomerCount)) * 100, 1
  )
  
  customer_trends$Retention_Strategy <- case_when(
    customer_trends$CustomerBehaviorType == 'One-time Buyer' ~ 'Reactivation campaigns, onboarding optimization',
    customer_trends$CustomerBehaviorType == 'Occasional (2-3 orders)' ~ 'Engagement programs, purchase incentives',
    customer_trends$CustomerBehaviorType == 'Regular (4-10 orders)' ~ 'Loyalty programs, cross-selling',
    TRUE ~ 'VIP treatment, exclusive access, referral programs'
  )
  
  cat("✅ Customer Behavior:", nrow(customer_trends), "behavior types\n")
  
}, error = function(e) {
  stop("❌ Customer Behavior creation failed: ", e$message)
})

# ============================================================================
# DATASET 5: TOP PERFORMING CUSTOMERS
# ============================================================================
# Purpose: High-value customer identification for personalized marketing
# Business Value: VIP customer management and retention focus
# ============================================================================
cat("Creating Top Customers dataset...\n")

tryCatch({
  # Extract top customer profiles with comprehensive metrics
  top_customers <- dbGetQuery(con, "
    SELECT 
      CustomerID,
      Country,
      TotalOrders,
      ROUND(TotalRevenue, 0) as TotalRevenue,
      ROUND(AvgTransactionValue, 0) as AvgTransactionValue,
      CustomerSegment,
      UniqueProductsPurchased,
      CustomerLifetimeDays,
      FirstOrder,
      LastOrder
    FROM v_customer_summary
    ORDER BY TotalRevenue DESC
    LIMIT 50
  ")
  
  # Add customer lifecycle classifications
  top_customers$CustomerLifecycle <- case_when(
    top_customers$CustomerLifetimeDays == 0 ~ 'Single Day',
    top_customers$CustomerLifetimeDays <= 30 ~ 'Short Term (≤30 days)',
    top_customers$CustomerLifetimeDays <= 90 ~ 'Medium Term (31-90 days)',
    TRUE ~ 'Long Term (90+ days)'
  )
  
  # Add service level recommendations
  top_customers$Service_Level <- case_when(
    top_customers$TotalRevenue >= 10000 ~ 'Ultra-VIP: Dedicated account manager',
    top_customers$TotalRevenue >= 5000 ~ 'VIP: Premium support priority',
    top_customers$TotalRevenue >= 2500 ~ 'High-Value: Enhanced service level',
    TRUE ~ 'Valuable: Standard premium service'
  )
  
  cat("✅ Top Customers:", nrow(top_customers), "customers\n")
  
}, error = function(e) {
  stop("❌ Top Customers creation failed: ", e$message)
})

# ============================================================================
# PROFESSIONAL EXCEL EXPORT WITH BUSINESS FORMATTING
# ============================================================================
cat("\nExporting datasets to professional Excel workbooks...\n")

tryCatch({
  # Create main combined workbook with professional styling
  combined_workbook <- createWorkbook()
  
  # Define professional styling
  header_style <- createStyle(
    fontSize = 12, fontColour = "#FFFFFF", halign = "center",
    fgFill = "#4F81BD", border = "TopBottom", borderColour = "#4F81BD"
  )
  
  # Add worksheets with descriptive names
  addWorksheet(combined_workbook, "Executive Summary")
  addWorksheet(combined_workbook, "Customer Segmentation") 
  addWorksheet(combined_workbook, "Geographic Performance")
  addWorksheet(combined_workbook, "Customer Trends")
  addWorksheet(combined_workbook, "Top Customers")
  
  # Write data with professional formatting
  writeData(combined_workbook, "Executive Summary", executive_summary)
  writeData(combined_workbook, "Customer Segmentation", customer_segmentation)
  writeData(combined_workbook, "Geographic Performance", geographic_performance)
  writeData(combined_workbook, "Customer Trends", customer_trends)
  writeData(combined_workbook, "Top Customers", top_customers)
  
  # Apply header styling
  addStyle(combined_workbook, "Executive Summary", header_style, rows = 1, cols = 1:ncol(executive_summary))
  addStyle(combined_workbook, "Customer Segmentation", header_style, rows = 1, cols = 1:ncol(customer_segmentation))
  addStyle(combined_workbook, "Geographic Performance", header_style, rows = 1, cols = 1:ncol(geographic_performance))
  addStyle(combined_workbook, "Customer Trends", header_style, rows = 1, cols = 1:ncol(customer_trends))
  addStyle(combined_workbook, "Top Customers", header_style, rows = 1, cols = 1:ncol(top_customers))
  
  # Save main workbook
  saveWorkbook(combined_workbook, paste0(export_dir, main_file_name), overwrite = TRUE)
  cat("✅ Main workbook created:", main_file_name, "\n")
  
  # Export individual files for specialized analysis
  write.xlsx(executive_summary, paste0(export_dir, "executive_summary.xlsx"))
  write.xlsx(customer_segmentation, paste0(export_dir, "customer_segmentation.xlsx"))
  write.xlsx(geographic_performance, paste0(export_dir, "geographic_performance.xlsx"))
  write.xlsx(customer_trends, paste0(export_dir, "customer_behavior_trends.xlsx"))
  write.xlsx(top_customers, paste0(export_dir, "top_customers.xlsx"))
  
  cat("✅ Individual dataset files created successfully\n")
  
}, error = function(e) {
  stop("❌ Excel export failed: ", e$message)
})

# ============================================================================
# CLEANUP AND COMPLETION
# ============================================================================

# Secure database disconnection
tryCatch({
  dbDisconnect(con)
  cat("✅ Database connection closed successfully\n")
}, error = function(e) {
  cat("⚠️ Connection cleanup warning:", e$message, "\n")
})


