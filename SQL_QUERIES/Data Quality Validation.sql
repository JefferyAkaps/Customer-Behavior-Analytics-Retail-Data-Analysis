-- ============================================================================
-- CUSTOMER ANALYTICS DATABASE - DATA QUALITY INSPECTION QUERIES
-- Comprehensive validation before analysis
-- ============================================================================

USE CustomerAnalyticsDB;
-- ============================================================================
-- 1. BASIC DATA OVERVIEW & COUNTS
-- ============================================================================

-- Database overview
SELECT 
    'Database Overview' as Check_Type,
    (SELECT COUNT(*) FROM Customers) as Total_Customers,
    (SELECT COUNT(*) FROM Products) as Total_Products,
    (SELECT COUNT(*) FROM Orders) as Total_Orders,
    (SELECT COUNT(*) FROM OrderDetails) as Total_OrderDetails,
    (SELECT ROUND(SUM(Revenue), 2) FROM OrderDetails) as Total_Revenue;

-- Table sizes and basic statistics
SELECT 
    table_name,
    table_rows as Estimated_Rows,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) as Size_MB
FROM information_schema.tables 
WHERE table_schema = 'CustomerAnalyticsDB'
ORDER BY table_rows DESC;

-- ============================================================================
-- 2. DATA COMPLETENESS & NULL VALUE ANALYSIS
-- ============================================================================
SELECT 
    'Customers Data Completeness' as Analysis,
    COUNT(*) as Total_Records,
    COUNT(`CustomerID`) as CustomerID_Count,
    COUNT(`Country`) as Country_Count,
    COUNT(*) - COUNT(`Country`) as Missing_Countries,
    ROUND((COUNT(`Country`) / COUNT(*)) * 100, 2) as Country_Completeness_Pct
FROM Customers;

-- Products table completeness  
SELECT 
    'Products Data Completeness' as Analysis,
    COUNT(*) as Total_Products,
    COUNT(`StockCode`) as StockCode_Count,
    COUNT(`Description`) as Description_Count,
    COUNT(*) - COUNT(`Description`) as Missing_Descriptions,
    COUNT(`UnitPrice`) as UnitPrice_Count,
    ROUND((COUNT(`Description`) / COUNT(*)) * 100, 2) as Description_Completeness_Pct
FROM `Products`;


-- Orders table completeness
SELECT 
    'Orders Data Completeness' as Analysis,
    COUNT(*) as Total_Orders,
    COUNT(`InvoiceNo`) as InvoiceNo_Count,
    COUNT(`InvoiceDate`) as InvoiceDate_Count,
    COUNT(`CustomerID`) as CustomerID_Count,
    COUNT(*) - COUNT(`CustomerID`) as Missing_CustomerIDs
FROM `Orders`;

-- OrderDetails completeness
SELECT 
    'OrderDetails Data Completeness' as Analysis,
    COUNT(*) as Total_Details,
    COUNT(`InvoiceNo`) as InvoiceNo_Count,
    COUNT(`StockCode`) as StockCode_Count,
    COUNT(`Quantity`) as Quantity_Count,
    COUNT(`UnitPrice`) as UnitPrice_Count,
    -- Note: Revenue column may not exist, so we'll calculate it
    COUNT(CASE WHEN (`Quantity` * `UnitPrice`) IS NOT NULL THEN 1 END) as Revenue_Count
FROM `OrderDetails`;

-- ============================================================================
-- 3. DUPLICATE DETECTION WITH BACKTICKS
-- ============================================================================

-- Check for duplicate customers
SELECT 
    'Duplicate Customer Check' as Check_Type,
    COUNT(*) as Total_Customers,
    COUNT(DISTINCT `CustomerID`) as Unique_Customers,
    COUNT(*) - COUNT(DISTINCT `CustomerID`) as Duplicate_Count
FROM `Customers`;

-- Check for duplicate products
SELECT 
    'Duplicate Product Check' as Check_Type,
    COUNT(*) as Total_Products,
    COUNT(DISTINCT `StockCode`) as Unique_Products,
    COUNT(*) - COUNT(DISTINCT `StockCode`) as Duplicate_Count
FROM `Products`;

-- Check for duplicate orders
SELECT 
    'Duplicate Order Check' as Check_Type,
    COUNT(*) as Total_Orders,
    COUNT(DISTINCT `InvoiceNo`) as Unique_Orders,
    COUNT(*) - COUNT(DISTINCT `InvoiceNo`) as Duplicate_Count
FROM `Orders`;

-- Find actual duplicate OrderDetails (same invoice + product)
SELECT 
    'Duplicate OrderDetail Check' as Check_Type,
    COUNT(*) as Total_OrderDetails,
    COUNT(DISTINCT CONCAT(`InvoiceNo`, '-', `StockCode`)) as Unique_Combinations,
    COUNT(*) - COUNT(DISTINCT CONCAT(`InvoiceNo`, '-', `StockCode`)) as Potential_Duplicates
FROM `OrderDetails`;

-- Show actual duplicate order details if any
SELECT 
    `InvoiceNo`, 
    `StockCode`, 
    COUNT(*) as Duplicate_Count,
    GROUP_CONCAT(`Quantity`) as Quantities,
    GROUP_CONCAT(`UnitPrice`) as UnitPrices
FROM `OrderDetails` 
GROUP BY `InvoiceNo`, `StockCode` 
HAVING COUNT(*) > 1
LIMIT 10;

-- ============================================================================
-- 4. REFERENTIAL INTEGRITY CHECKS
-- ============================================================================

-- Orders without corresponding customers
SELECT 
    'Orphaned Orders Check' as Check_Type,
    COUNT(*) as Orders_Without_Customers
FROM Orders o
LEFT JOIN Customers c ON o.CustomerID = c.CustomerID
WHERE c.CustomerID IS NULL;

-- OrderDetails without corresponding orders
SELECT 
    'Orphaned OrderDetails Check' as Check_Type,
    COUNT(*) as Details_Without_Orders
FROM OrderDetails od
LEFT JOIN Orders o ON od.InvoiceNo = o.InvoiceNo
WHERE o.InvoiceNo IS NULL;

-- OrderDetails without corresponding products
SELECT 
    'Orphaned OrderDetails Check' as Check_Type,
    COUNT(*) as Details_Without_Products
FROM OrderDetails od
LEFT JOIN Products p ON od.StockCode = p.StockCode
WHERE p.StockCode IS NULL;

-- List missing product codes (if any)
SELECT DISTINCT 
    od.StockCode,
    COUNT(*) as Usage_Count
FROM OrderDetails od
LEFT JOIN Products p ON od.StockCode = p.StockCode
WHERE p.StockCode IS NULL
GROUP BY od.StockCode
LIMIT 20;

SELECT 
    COUNT(*) as Total_Records,
    COUNT(DISTINCT CONCAT(`InvoiceNo`, '-', `StockCode`, '-', `Quantity`, '-', `UnitPrice`)) as Unique_Records
FROM `OrderDetails`;



-- ============================================================================
-- 5. FINAL DATA QUALITY SUMMARY
-- ============================================================================

-- Comprehensive quality score
SELECT 
    'DATA QUALITY SUMMARY' as Final_Report,
    CASE 
        WHEN (SELECT COUNT(*) FROM Customers WHERE CustomerID IS NULL) = 0 THEN '✅'
        ELSE '❌'
    END as Customer_IDs_Valid,
    CASE 
        WHEN (SELECT COUNT(*) FROM Orders o LEFT JOIN Customers c ON o.CustomerID = c.CustomerID WHERE c.CustomerID IS NULL) = 0 THEN '✅'
        ELSE '❌'
    END as Referential_Integrity,
    CASE 
        WHEN (SELECT COUNT(*) FROM OrderDetails WHERE Quantity <= 0 OR UnitPrice <= 0) = 0 THEN '✅'
        ELSE '❌'
    END as Business_Rules_Valid,
    CASE 
        WHEN (SELECT COUNT(*) FROM OrderDetails WHERE ABS(Revenue - (Quantity * UnitPrice)) > 0.01) = 0 THEN '✅'
        ELSE '❌'
    END as Calculations_Accurate,
    ROUND(((SELECT COUNT(*) FROM OrderDetails) / (SELECT COUNT(*) FROM OrderDetails) * 100), 2) as Data_Completeness_Pct;
    
   