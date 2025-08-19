-- ============================================================================
-- CUSTOMER BEHAVIOR ANALYSIS QUERIES
-- SQL queries to analyze customer purchasing patterns and generate insights
-- ============================================================================

USE CustomerAnalyticsDB;

-- ============================================================================
-- MAIN GOAL: CUSTOMER SEGMENTATION ANALYSIS
-- ============================================================================

-- Identify high-value customer segments with detailed analysis
SELECT 
    CustomerSegment,
    COUNT(*) as CustomerCount,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM v_customer_summary)), 2) as CustomerPercentage,
    ROUND(AVG(TotalRevenue), 2) as AvgCustomerValue,
    ROUND(SUM(TotalRevenue), 2) as SegmentRevenue,
    ROUND((SUM(TotalRevenue) * 100.0 / (SELECT SUM(TotalRevenue) FROM v_customer_summary)), 2) as RevenuePercentage,
    ROUND(AVG(TotalOrders), 1) as AvgOrdersPerCustomer,
    ROUND(AVG(AvgTransactionValue), 2) as AvgTransactionValue
FROM v_customer_summary
GROUP BY CustomerSegment
ORDER BY AvgCustomerValue DESC;

-- ============================================================================
-- QUESTION 1: TOP 20 HIGHEST-SPENDING CUSTOMERS
-- ============================================================================

-- Identify VIP customers for targeted marketing campaigns
SELECT 
    CustomerID,
    Country,
    TotalOrders,
    TotalTransactions,
    ROUND(TotalRevenue, 2) as TotalSpent,
    ROUND(AvgTransactionValue, 2) as AvgTransactionValue,
    CustomerSegment,
    UniqueProductsPurchased,
    CASE 
        WHEN CustomerLifetimeDays = 0 THEN 'Single Day Customer'
        WHEN CustomerLifetimeDays <= 30 THEN 'Short Term (≤30 days)'
        WHEN CustomerLifetimeDays <= 90 THEN 'Medium Term (31-90 days)'
        ELSE 'Long Term (90+ days)'
    END as CustomerLifecycle,
    FirstOrder,
    LastOrder
FROM v_customer_summary
ORDER BY TotalRevenue DESC
LIMIT 20;

-- ============================================================================
-- QUESTION 2: CUSTOMER ORDER FREQUENCY ANALYSIS
-- ============================================================================

-- Analyze customer purchase behavior patterns
SELECT 
    CASE 
        WHEN TotalOrders = 1 THEN 'One-time Buyer'
        WHEN TotalOrders <= 3 THEN 'Occasional Buyer (2-3 orders)'
        WHEN TotalOrders <= 10 THEN 'Regular Customer (4-10 orders)'
        ELSE 'Frequent Customer (10+ orders)'
    END as CustomerType,
    COUNT(*) as NumberOfCustomers,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM v_customer_summary)), 2) as CustomerPercentage,
    ROUND(AVG(TotalRevenue), 2) as AvgCustomerValue,
    ROUND(SUM(TotalRevenue), 2) as TypeRevenue,
    ROUND(AVG(AvgTransactionValue), 2) as AvgTransactionValue,
    ROUND(AVG(TotalOrders), 1) as AvgOrdersPerCustomer
FROM v_customer_summary
GROUP BY CustomerType
ORDER BY AvgCustomerValue DESC;

-- ============================================================================
-- QUESTION 3: CUSTOMER LOYALTY BY COUNTRY
-- ============================================================================

-- Identify most loyal customers by geographic region
SELECT 
    Country,
    COUNT(*) as TotalCustomers,
    ROUND(AVG(TotalOrders), 2) as AvgOrdersPerCustomer,
    ROUND(AVG(TotalRevenue), 2) as AvgRevenuePerCustomer,
    ROUND(SUM(TotalRevenue), 2) as CountryTotalRevenue,
    ROUND(AVG(CustomerLifetimeDays), 1) as AvgCustomerLifetimeDays,
    ROUND(AVG(UniqueProductsPurchased), 1) as AvgProductsPerCustomer,
    
    -- Customer segment distribution
    ROUND(SUM(CASE WHEN CustomerSegment = 'VIP Customer' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as VIPCustomerPercentage,
    ROUND(SUM(CASE WHEN CustomerSegment IN ('VIP Customer', 'High Value') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as HighValuePercentage
    
FROM v_customer_summary
GROUP BY Country
HAVING TotalCustomers >= 10  
ORDER BY AvgOrdersPerCustomer DESC;

-- ============================================================================
-- QUESTION 4: TIME BETWEEN PURCHASES ANALYSIS
-- ============================================================================

-- Analyze customer purchase frequency and timing patterns
SELECT 
    Country,
    COUNT(*) as RepeatCustomers,
    ROUND(AVG(CustomerLifetimeDays), 1) as AvgDaysBetweenFirstAndLast,
    ROUND(AVG(CustomerLifetimeDays / NULLIF(TotalOrders - 1, 0)), 1) as AvgDaysBetweenOrders,
    ROUND(AVG(TotalRevenue), 2) as AvgCustomerValue,
    
    -- Purchase frequency categories
    ROUND(SUM(CASE WHEN CustomerLifetimeDays <= 7 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as WeeklyCustomersPercentage,
    ROUND(SUM(CASE WHEN CustomerLifetimeDays BETWEEN 8 AND 30 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as MonthlyCustomersPercentage,
    ROUND(SUM(CASE WHEN CustomerLifetimeDays > 30 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as LongTermCustomersPercentage
    
FROM v_customer_summary
WHERE TotalOrders > 1  -- Only repeat customers
GROUP BY Country
HAVING RepeatCustomers >= 5
ORDER BY AvgDaysBetweenOrders;


-- ============================================================================
-- EXECUTIVE SUMMARY QUERY
-- ============================================================================

-- Key metrics for executive dashboard
SELECT 
    'Customer Analytics Summary' as Metric,
    CONCAT(
        'Total Customers: ', FORMAT((SELECT COUNT(*) FROM v_customer_summary), 0), 
        ' | Total Revenue: $', FORMAT((SELECT SUM(TotalRevenue) FROM v_customer_summary), 0),
        ' | Avg Customer Value: $', FORMAT((SELECT AVG(TotalRevenue) FROM v_customer_summary), 0),
        ' | VIP Customers: ', (SELECT COUNT(*) FROM v_customer_summary WHERE CustomerSegment = 'VIP Customer'),
        ' (', FORMAT((SELECT COUNT(*) FROM v_customer_summary WHERE CustomerSegment = 'VIP Customer') * 100.0 / 
                    (SELECT COUNT(*) FROM v_customer_summary), 1), '%)',
        ' | Countries: ', (SELECT COUNT(DISTINCT Country) FROM v_customer_summary),
        ' | Repeat Customer Rate: ', FORMAT((SELECT COUNT(*) FROM v_customer_summary WHERE TotalOrders > 1) * 100.0 / 
                                           (SELECT COUNT(*) FROM v_customer_summary), 1), '%'
    ) as Value;