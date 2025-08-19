-- ============================================================================
-- YOUR ORIGINAL VIEWS - COLLATION FIXED VERSION
-- Same structure, just fixed for MySQL collation compatibility
-- ============================================================================

USE CustomerAnalyticsDB;

-- Drop existing views if they exist
DROP VIEW IF EXISTS v_customer_dashboard;
DROP VIEW IF EXISTS v_customer_summary;

-- ============================================================================
-- 1. MAIN CUSTOMER DASHBOARD VIEW 
-- ============================================================================

CREATE VIEW v_customer_dashboard AS
SELECT 
    o.`InvoiceNo` COLLATE utf8mb4_general_ci as InvoiceNo,
    o.`InvoiceDate`,
    DATE(o.`InvoiceDate`) as OrderDate,
    YEAR(o.`InvoiceDate`) as SalesYear,
    MONTH(o.`InvoiceDate`) as SalesMonth,
    MONTHNAME(o.`InvoiceDate`) COLLATE utf8mb4_general_ci as MonthName,
    DAYNAME(o.`InvoiceDate`) COLLATE utf8mb4_general_ci as DayOfWeek,
    
    c.`CustomerID`,
    c.`Country` COLLATE utf8mb4_general_ci as Country,
    
    p.`StockCode` COLLATE utf8mb4_general_ci as StockCode,
    p.`Description` COLLATE utf8mb4_general_ci as ProductDescription,
    
    od.`Quantity`,
    od.`UnitPrice`,
    -- Use calculated revenue instead of od.Revenue (may not exist)
    (od.`Quantity` * od.`UnitPrice`) as Revenue,
    
    -- Customer value categories 
    CASE 
        WHEN (od.`Quantity` * od.`UnitPrice`) > 100 THEN 'Premium Transaction'
        WHEN (od.`Quantity` * od.`UnitPrice`) > 50 THEN 'High Value Transaction'
        WHEN (od.`Quantity` * od.`UnitPrice`) > 20 THEN 'Medium Value Transaction'
        ELSE 'Low Value Transaction'
    END COLLATE utf8mb4_general_ci as TransactionCategory,
    
    -- Order size categories 
    CASE 
        WHEN od.`Quantity` > 20 THEN 'Bulk Purchase'
        WHEN od.`Quantity` > 10 THEN 'Large Order'
        WHEN od.`Quantity` > 5 THEN 'Medium Order'
        ELSE 'Small Order'
    END COLLATE utf8mb4_general_ci as OrderSize
    
FROM `Orders` o
JOIN `Customers` c ON o.`CustomerID` = c.`CustomerID`
JOIN `OrderDetails` od ON o.`InvoiceNo` = od.`InvoiceNo`
JOIN `Products` p ON od.`StockCode` = p.`StockCode`
WHERE od.`Quantity` > 0 AND od.`UnitPrice` > 0  
ORDER BY o.`InvoiceDate` DESC;

-- ============================================================================
-- 2. CUSTOMER SUMMARY VIEW
-- ============================================================================

CREATE VIEW v_customer_summary AS
SELECT 
    c.`CustomerID`,
    c.`Country` COLLATE utf8mb4_general_ci as Country,
    COUNT(DISTINCT o.`InvoiceNo`) as TotalOrders,
    COUNT(*) as TotalTransactions,  
    SUM(od.`Quantity` * od.`UnitPrice`) as TotalRevenue,
    AVG(od.`Quantity` * od.`UnitPrice`) as AvgTransactionValue,
    MIN(o.`InvoiceDate`) as FirstOrder,
    MAX(o.`InvoiceDate`) as LastOrder,
    DATEDIFF(MAX(o.`InvoiceDate`), MIN(o.`InvoiceDate`)) as CustomerLifetimeDays,
    COUNT(DISTINCT p.`StockCode`) as UniqueProductsPurchased,
    
    -- Customer value segmentation 
    CASE 
        WHEN SUM(od.`Quantity` * od.`UnitPrice`) >= 5000 THEN 'VIP Customer'
        WHEN SUM(od.`Quantity` * od.`UnitPrice`) >= 1000 THEN 'High Value'
        WHEN SUM(od.`Quantity` * od.`UnitPrice`) >= 500 THEN 'Medium Value'
        ELSE 'Low Value'
    END COLLATE utf8mb4_general_ci as CustomerSegment
    
FROM `Customers` c
JOIN `Orders` o ON c.`CustomerID` = o.`CustomerID`
JOIN `OrderDetails` od ON o.`InvoiceNo` = od.`InvoiceNo`
JOIN `Products` p ON od.`StockCode` = p.`StockCode`
WHERE od.`Quantity` > 0 AND od.`UnitPrice` > 0  -- Added safety filter
GROUP BY c.`CustomerID`, c.`Country`;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Test the views work properly
SELECT 'v_customer_dashboard' as view_name, COUNT(*) as record_count 
FROM v_customer_dashboard
UNION ALL
SELECT 'v_customer_summary', COUNT(*) 
FROM v_customer_summary;

-- Show sample data to verify structure
SELECT 'Customer Dashboard Sample' as sample_type;
SELECT * FROM v_customer_dashboard LIMIT 3;

SELECT 'Customer Summary Sample' as sample_type;
SELECT * FROM v_customer_summary LIMIT 3;

-- Enable local data loading
SET GLOBAL local_infile = 'ON';

SELECT 'Customer Analytics Database setup completed successfully!' as Status;