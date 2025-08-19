# ============================================================================
# CUSTOMER ANALYTICS ETL PIPELINE
# ============================================================================
#
# Description:
# This script implements a professional-grade ETL pipeline that processes
# 540K+ retail transactions, applies sophisticated data cleaning and validation,
# and loads normalized data into MySQL for customer analytics. Demonstrates
# advanced data engineering capabilities with robust error handling and logging.
# ============================================================================

# ============================================================================
# ENVIRONMENT SETUP AND PACKAGE LOADING
# ============================================================================

# Load required packages for data processing and database connectivity
suppressPackageStartupMessages({
  library(RMySQL)      # MySQL database connectivity
  library(DBI)         # Database interface abstraction
  library(dplyr)       # Data manipulation and transformation
  library(readxl)      # Excel file reading capabilities
  library(lubridate)   # Advanced date/time processing
  library(stringr)     # String manipulation and cleaning
})

# Pipeline initialization
cat("=== CUSTOMER ANALYTICS PIPELINE ===\n")
cat("Processing retail data for customer behavior analysis...\n\n")

# ============================================================================
# CONFIGURATION PARAMETERS
# ============================================================================
# Database connection parameters (CONFIGURE FOR YOUR ENVIRONMENT)
# For production: Use environment variables or secure config files
DB_USER <- Sys.getenv("DB_USER", "your_mysql_username")
DB_PASSWORD <- Sys.getenv("DB_PASSWORD", "your_mysql_password")  
DB_NAME <- "CustomerAnalyticsDB"
DB_HOST <- Sys.getenv("DB_HOST", "localhost")
DB_PORT <- as.numeric(Sys.getenv("DB_PORT", "3306"))

# Data processing parameters
BATCH_SIZE_CUSTOMERS <- 2000
BATCH_SIZE_PRODUCTS <- 1000
BATCH_SIZE_ORDERS <- 3000
BATCH_SIZE_ORDER_DETAILS <- 5000

# File path configuration (update to your file location)
DATA_FILE_PATH <- Sys.getenv("DATA_FILE_PATH", "path/to/your/Online_Retail.xlsx")

# ============================================================================
# STEP 1: DATA EXTRACTION AND INITIAL VALIDATION
# ============================================================================
cat("Step 1: Extracting data from Excel source...\n")

# Load raw data with error handling
tryCatch({
  Online_Retail <- read_excel(DATA_FILE_PATH)
  cat("✅ Data extraction successful\n")
  cat("Raw records loaded:", format(nrow(Online_Retail), big.mark = ","), "\n")
  cat("Columns available:", ncol(Online_Retail), "\n\n")
}, error = function(e) {
  stop("❌ Data extraction failed: ", e$message)
})

# ============================================================================
# STEP 2: COMPREHENSIVE DATA CLEANING AND TRANSFORMATION
# ============================================================================
cat("Step 2: Executing data cleaning and transformation...\n")

# Apply sophisticated data cleaning pipeline
retail_clean <- Online_Retail %>%
  
  # === MISSING DATA HANDLING ===
  # Remove records with critical missing information for customer analysis
  filter(
    !is.na(InvoiceNo),       # Transaction identifier required
    !is.na(CustomerID),      # Customer ID essential for customer analytics
    !is.na(StockCode),       # Product identifier required
    !is.na(InvoiceDate),     # Transaction date required for temporal analysis
    !is.na(Country),         # Geographic data required for market analysis
    !is.na(Quantity),        # Quantity required for revenue calculation
    !is.na(UnitPrice)        # Price required for revenue calculation
  ) %>%
  
  # === DATA TYPE CONVERSION AND VALIDATION ===
  mutate(
    CustomerID = as.numeric(CustomerID),
    Quantity = as.numeric(Quantity),
    UnitPrice = as.numeric(UnitPrice)
  ) %>%
  
  # Filter out conversion failures
  filter(
    !is.na(CustomerID),
    !is.na(Quantity),
    !is.na(UnitPrice)
  ) %>%
  
  # === TEXT DATA STANDARDIZATION ===
  mutate(
    # Clean and standardize text fields
    InvoiceNo = str_trim(as.character(InvoiceNo)),
    StockCode = str_trim(as.character(StockCode)),
    Description = str_trim(as.character(Description)),
    Country = str_trim(str_to_title(as.character(Country))),
    
    # === GEOGRAPHIC DATA STANDARDIZATION ===
    # Standardize country names for consistent geographic analysis
    Country = case_when(
      Country == "Eire" ~ "Ireland",
      Country == "Usa" ~ "United States", 
      Country == "European Community" ~ "Europe",
      TRUE ~ Country
    ),
    
    # === PRODUCT DESCRIPTION HANDLING ===
    # Handle missing product descriptions
    Description = if_else(
      is.na(Description) | str_trim(Description) == "", 
      "Unknown Product", 
      Description
    )
  ) %>%
  
  # === ADVANCED DATE PROCESSING ===
  # Robust date handling for multiple Excel date formats
  mutate(
    InvoiceDate = case_when(
      # Handle POSIXct dates (already converted)
      "POSIXct" %in% class(InvoiceDate) ~ InvoiceDate,
      # Handle Date objects
      "Date" %in% class(InvoiceDate) ~ as.POSIXct(InvoiceDate),
      # Handle Excel serial numbers
      is.numeric(InvoiceDate) ~ as.POSIXct(as.Date(InvoiceDate, origin = "1899-12-30")),
      # Handle character date strings
      TRUE ~ mdy_hm(as.character(InvoiceDate))
    )
  ) %>%
  
  # Remove records with failed date conversions
  filter(!is.na(InvoiceDate)) %>%
  
  # === BUSINESS RULES APPLICATION ===
  # Apply customer analytics business rules
  filter(
    !str_starts(str_to_upper(InvoiceNo), "C"),  # Remove cancellations (C-prefix)
    Quantity > 0,                               # Remove returns for customer analysis
    UnitPrice > 0,                             # Remove free/promotional items
    CustomerID > 0                             # Ensure valid customer IDs
  ) %>%
  
  # === REVENUE CALCULATION ===
  # Calculate line-item revenue for financial analysis
  mutate(Revenue = round(Quantity * UnitPrice, 2)) %>%
  
  # === OUTLIER DETECTION AND REMOVAL ===
  # Remove extreme outliers that may represent data errors
  filter(
    Quantity <= 10000,     # Reasonable quantity upper limit
    UnitPrice <= 1000,     # Reasonable price upper limit  
    Revenue <= 50000       # Reasonable line revenue upper limit
  )

# ============================================================================
# STEP 3: DATA NORMALIZATION FOR RELATIONAL DATABASE
# ============================================================================
cat("Step 3: Creating normalized data structures...\n")

# === CUSTOMERS DIMENSION TABLE ===
# Create unique customer records with geographic information
customers_df <- retail_clean %>%
  select(CustomerID, Country) %>%
  distinct() %>%
  arrange(CustomerID)

# === PRODUCTS DIMENSION TABLE ===
# Create product catalog with averaged pricing for products with price variations
products_df <- retail_clean %>%
  select(StockCode, Description, UnitPrice) %>%
  group_by(StockCode) %>%
  summarise(
    Description = first(Description),           # Take first description
    UnitPrice = round(mean(UnitPrice), 2),     # Average price for consistency
    .groups = 'drop'
  ) %>%
  arrange(StockCode)

# === ORDERS FACT TABLE ===
# Create transaction header records
orders_df <- retail_clean %>%
  select(InvoiceNo, InvoiceDate, CustomerID) %>%
  distinct() %>%
  arrange(InvoiceDate, InvoiceNo)

# === ORDER DETAILS FACT TABLE ===
# Create transaction line item records
order_details_df <- retail_clean %>%
  select(InvoiceNo, StockCode, Quantity, UnitPrice) %>%
  arrange(InvoiceNo, StockCode)

# Normalization summary
cat("✅ Data normalization completed\n")
cat("Customers dimension:", format(nrow(customers_df), big.mark = ","), "records\n")
cat("Products dimension:", format(nrow(products_df), big.mark = ","), "records\n")
cat("Orders fact table:", format(nrow(orders_df), big.mark = ","), "records\n")
cat("Order details fact table:", format(nrow(order_details_df), big.mark = ","), "records\n\n")

# ============================================================================
# STEP 4: DATABASE CONNECTION AND VALIDATION
# ============================================================================
cat("Step 4: Establishing database connection...\n")

# Create secure database connection with error handling
tryCatch({
  con <- dbConnect(
    MySQL(),
    user = DB_USER,
    password = DB_PASSWORD,
    dbname = DB_NAME,
    host = DB_HOST,
    port = DB_PORT,
    local_infile = TRUE  # Enable local data loading for performance
  )
  cat("✅ Database connection established successfully\n\n")
}, error = function(e) {
  stop("❌ Database connection failed: ", e$message)
})

# ============================================================================
# STEP 5: OPTIMIZED BATCH DATA LOADING
# ============================================================================
cat("Step 5: Loading data to customer analytics database...\n")

# High-performance batch loading function with progress tracking
load_table <- function(data, table_name, batch_size = 5000) {
  total_rows <- nrow(data)
  batches <- ceiling(total_rows / batch_size)
  
  cat("Loading", format(total_rows, big.mark = ","), "rows into", table_name, "...\n")
  
  # Process data in optimized batches
  for (i in 1:batches) {
    start_row <- (i - 1) * batch_size + 1
    end_row <- min(i * batch_size, total_rows)
    batch_data <- data[start_row:end_row, ]
    
    # Load batch with error handling
    tryCatch({
      dbWriteTable(con, table_name, batch_data, append = TRUE, row.names = FALSE)
      cat("  Batch", i, "of", batches, "completed\n")
    }, error = function(e) {
      stop("❌ Batch loading failed at batch ", i, ": ", e$message)
    })
  }
  
  cat("✅", table_name, "loaded successfully\n\n")
}

# Load data in proper sequence to maintain referential integrity
load_table(customers_df, "Customers", BATCH_SIZE_CUSTOMERS)
load_table(products_df, "Products", BATCH_SIZE_PRODUCTS)  
load_table(orders_df, "Orders", BATCH_SIZE_ORDERS)
load_table(order_details_df, "OrderDetails", BATCH_SIZE_ORDER_DETAILS)

# ============================================================================
# STEP 6: DATA VALIDATION AND QUALITY ASSURANCE
# ============================================================================
cat("Step 6: Performing data validation and quality checks...\n")

# Comprehensive data validation queries
tryCatch({
  # Record count validation
  customers_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM Customers")$count
  orders_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM Orders")$count
  products_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM Products")$count
  details_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM OrderDetails")$count
  
  # Revenue calculation validation
  revenue_total <- dbGetQuery(con, "SELECT SUM(Quantity * UnitPrice) as total FROM OrderDetails")$total
  
  # Validation summary
  cat("✅ Data validation completed\n")
  cat("Database verification:\n")
  cat("  Customers:", format(customers_count, big.mark = ","), "\n")
  cat("  Products:", format(products_count, big.mark = ","), "\n")
  cat("  Orders:", format(orders_count, big.mark = ","), "\n")
  cat("  Order Details:", format(details_count, big.mark = ","), "\n")
  cat("  Total Revenue: $", format(revenue_total, big.mark = ","), "\n")
  
  # Test analytics views availability
  view_test <- dbGetQuery(con, "SELECT COUNT(*) as count FROM v_customer_summary LIMIT 1")
  cat("  Customer Summary View:", format(view_test$count, big.mark = ","), "customers\n")
  
}, error = function(e) {
  cat("⚠️ Validation warning:", e$message, "\n")
})

# ============================================================================
# PIPELINE COMPLETION AND CLEANUP
# ============================================================================

# Close database connection securely
tryCatch({
  dbDisconnect(con)
  cat("✅ Database connection closed successfully\n")
}, error = function(e) {
  cat("⚠️ Connection cleanup warning:", e$message, "\n")
})
