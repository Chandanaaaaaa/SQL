-- Retrieve data from CustomerRFM database
USE CustomerRFM;
GO

-- Retrieve all columns from the project table for initial data inspection
select * from project;

-- 1. Check for the overall data volume and time span
-- This query provides a comprehensive summary of the dataset including counts and date ranges
SELECT 
    COUNT(*) AS TotalRows,
    COUNT(DISTINCT InvoiceNo) AS TotalInvoices,
    COUNT(DISTINCT CustomerID) AS TotalCustomers,
    COUNT(DISTINCT StockCode) AS TotalProducts,
    COUNT(DISTINCT Country) AS TotalCountries,
    MIN(CAST(InvoiceDate AS DATE)) AS EarliestDate,
    MAX(CAST(InvoiceDate AS DATE)) AS LatestDate,
    DATEDIFF(DAY, MIN(CAST(InvoiceDate AS DATE)), MAX(CAST(InvoiceDate AS DATE))) AS DateRangeInDays
FROM 
    project;

-- 2. Check for missing values in key columns
-- This helps identify data quality issues before further analysis
SELECT
    SUM(CASE WHEN InvoiceNo IS NULL THEN 1 ELSE 0 END) AS NullInvoiceNo,
    SUM(CASE WHEN StockCode IS NULL THEN 1 ELSE 0 END) AS NullStockCode,
    SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END) AS NullDescription,
    SUM(CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END) AS NullQuantity,
    SUM(CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END) AS NullInvoiceDate,
    SUM(CASE WHEN UnitPrice IS NULL THEN 1 ELSE 0 END) AS NullUnitPrice,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS NullCustomerID,
    SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END) AS NullCountry,
    SUM(CASE WHEN Total_Sales IS NULL THEN 1 ELSE 0 END) AS NullTotalSales
FROM 
    project;

-- 3. Check transaction distribution over time (monthly)
-- This query analyzes sales trends by month to identify seasonality and growth patterns
SELECT 
    YEAR(CAST(InvoiceDate AS DATE)) AS Year,
    MONTH(CAST(InvoiceDate AS DATE)) AS Month,
    COUNT(DISTINCT InvoiceNo) AS InvoiceCount,
    COUNT(DISTINCT CustomerID) AS CustomerCount,
    SUM([Total_Sales]) AS TotalRevenue
FROM 
    project
WHERE 
    CustomerID IS NOT NULL
GROUP BY 
    YEAR(CAST(InvoiceDate AS DATE)),
    MONTH(CAST(InvoiceDate AS DATE))
ORDER BY 
    Year, Month;

-- 4. Top Countries by Sales and Customer Count
-- This helps identify the most valuable geographic markets
SELECT 
    Country,
    COUNT(DISTINCT InvoiceNo) AS InvoiceCount,
    COUNT(DISTINCT CustomerID) AS CustomerCount,
    SUM([Total_Sales]) AS TotalRevenue,
    AVG([Total_Sales]) AS AvgOrderValue
FROM 
    project
WHERE 
    CustomerID IS NOT NULL AND
    Quantity > 0
GROUP BY 
    Country
ORDER BY 
    TotalRevenue DESC;

-- 5. Customer purchase behavior summary
-- This provides overall metrics for customer behavior across the entire dataset
SELECT
    COUNT(DISTINCT CustomerID) AS TotalCustomers,
    AVG(InvoiceCount) AS AvgInvoicesPerCustomer,
    AVG(TotalSpent) AS AvgSpentPerCustomer,
    MIN(FirstPurchaseDate) AS EarliestFirstPurchase,
    MAX(LastPurchaseDate) AS LatestLastPurchase
FROM (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS InvoiceCount,
        SUM([Total_Sales]) AS TotalSpent,
        MIN(CAST(InvoiceDate AS DATE)) AS FirstPurchaseDate,
        MAX(CAST(InvoiceDate AS DATE)) AS LastPurchaseDate
    FROM 
        project
    WHERE 
        CustomerID IS NOT NULL AND
        Quantity > 0
    GROUP BY 
        CustomerID
) AS CustomerSummary;

-- 6. Calculate raw RFM values for each customer
-- Recency: days since last purchase, Frequency: number of purchases, Monetary: total spend
WITH RecencyCTE AS (
    SELECT 
        CustomerID,
        DATEDIFF(DAY, MAX(CAST(InvoiceDate AS DATE)), CAST(GETDATE() AS DATE)) AS Recency
    FROM project
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
),
FrequencyCTE AS (
    SELECT 
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS Frequency
    FROM project
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
),
MonetaryCTE AS (
    SELECT 
        CustomerID,
        SUM(Total_Sales) AS Monetary
    FROM project
    WHERE CustomerID IS NOT NULL AND Quantity > 0
    GROUP BY CustomerID
)
SELECT 
    R.CustomerID,
    R.Recency,
    F.Frequency,
    M.Monetary
FROM 
    RecencyCTE R
JOIN 
    FrequencyCTE F ON R.CustomerID = F.CustomerID
JOIN 
    MonetaryCTE M ON R.CustomerID = M.CustomerID
ORDER BY 
    R.Recency, F.Frequency DESC, M.Monetary DESC;

-- 7. Calculate RFM scores using quintiles and create a combined RFM score
-- Each dimension is scored 1-5, with 5 being the most valuable behavior
WITH RecencyCTE AS (
    SELECT 
        CustomerID,
        DATEDIFF(DAY, MAX(CAST(InvoiceDate AS DATE)), CAST(GETDATE() AS DATE)) AS Recency
    FROM project
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
), 
FrequencyCTE AS (
    SELECT 
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS Frequency
    FROM project
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
), 
MonetaryCTE AS (
    SELECT 
        CustomerID,
        SUM(Total_Sales) AS Monetary
    FROM project
    WHERE CustomerID IS NOT NULL AND Quantity > 0
    GROUP BY CustomerID
), 
RFM AS (
    SELECT 
        R.CustomerID,
        NTILE(5) OVER (ORDER BY R.Recency ASC) AS RecencyScore,
        NTILE(5) OVER (ORDER BY F.Frequency DESC) AS FrequencyScore,
        NTILE(5) OVER (ORDER BY M.Monetary DESC) AS MonetaryScore
    FROM 
        RecencyCTE R
    JOIN 
        FrequencyCTE F ON R.CustomerID = F.CustomerID
    JOIN 
        MonetaryCTE M ON R.CustomerID = M.CustomerID
)
SELECT 
    CustomerID,
    RecencyScore,
    FrequencyScore,
    MonetaryScore,
    (RecencyScore + FrequencyScore + MonetaryScore) AS RFMScore 
FROM RFM 
ORDER BY RFMScore DESC;

-- 8. Segment customers based on total sales value
-- This provides a simple segmentation approach based on customer lifetime value
WITH TotalSales AS (
    SELECT 
        CustomerID,
        SUM(Total_Sales) AS TotalSales
    FROM 
        project
    WHERE
        CustomerID IS NOT NULL
    GROUP BY 
        CustomerID
),
DeclineSegment AS (
    SELECT 
        CustomerID,
        CASE 
            WHEN TotalSales >= 2000 THEN 'High Value'
            WHEN TotalSales BETWEEN 800 AND 1999 THEN 'Medium Value'
            WHEN TotalSales BETWEEN 400 AND 799 THEN 'Low Value'
            ELSE 'Dormant'
        END AS SalesSegment
    FROM 
        TotalSales
)
SELECT 
    SalesSegment,
    COUNT(CustomerID) AS CustomerCount,
    CAST(COUNT(CustomerID) * 100.0 / (SELECT COUNT(*) FROM DeclineSegment) AS DECIMAL(5,2)) AS PercentageOfTotal
FROM 
    DeclineSegment
GROUP BY 
    SalesSegment
ORDER BY 
    CASE 
        WHEN SalesSegment = 'High Value' THEN 1
        WHEN SalesSegment = 'Medium Value' THEN 2
        WHEN SalesSegment = 'Low Value' THEN 3
        WHEN SalesSegment = 'Dormant' THEN 4
        ELSE 5
    END;