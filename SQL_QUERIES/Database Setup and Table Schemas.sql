-- ============================================================================
-- CUSTOMER ANALYTICS DATABASE SETUP
-- Creates normalized schema optimized for customer behavior analysis
-- ============================================================================

-- Create database with consistent collation
DROP DATABASE IF EXISTS CustomerAnalyticsDB;
CREATE DATABASE CustomerAnalyticsDB 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_general_ci;

USE CustomerAnalyticsDB;

-- ============================================================================
-- CREATE NORMALIZED TABLES WITH CONSISTENT COLLATION
-- ============================================================================

-- Customers table
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    Country VARCHAR(100) NOT NULL COLLATE utf8mb4_general_ci,
    INDEX idx_customers_country (Country)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Products table
CREATE TABLE Products (
    StockCode VARCHAR(20) PRIMARY KEY COLLATE utf8mb4_general_ci,
    Description TEXT NOT NULL COLLATE utf8mb4_general_ci,
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Orders table
CREATE TABLE Orders (
    InvoiceNo VARCHAR(20) PRIMARY KEY COLLATE utf8mb4_general_ci,
    InvoiceDate DATETIME NOT NULL,
    CustomerID INT NOT NULL,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    INDEX idx_orders_date (InvoiceDate),
    INDEX idx_orders_customer (CustomerID)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- OrderDetails table with automatic revenue calculation
CREATE TABLE OrderDetails (
    OrderDetailID INT AUTO_INCREMENT PRIMARY KEY,
    InvoiceNo VARCHAR(20) NOT NULL COLLATE utf8mb4_general_ci,
    StockCode VARCHAR(20) NOT NULL COLLATE utf8mb4_general_ci,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
    Revenue DECIMAL(12,2) GENERATED ALWAYS AS (Quantity * UnitPrice) STORED,
    FOREIGN KEY (InvoiceNo) REFERENCES Orders(InvoiceNo),
    FOREIGN KEY (StockCode) REFERENCES Products(StockCode),
    INDEX idx_orderdetails_invoice (InvoiceNo),
    INDEX idx_orderdetails_product (StockCode)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;


