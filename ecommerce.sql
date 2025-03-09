USE [master]
GO

/****** Object:  Table [dbo].[ecommerce]    Script Date: 01-02-2025 22:37:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ecommerce](
	[InvoiceNo] [varchar](50) NULL,
	[StockCode] [varchar](50) NULL,
	[Description] [varchar](50) NULL,
	[Quantity] [varchar](50) NULL,
	[InvoiceDate] [varchar](50) NULL,
	[UnitPrice] [varchar](50) NULL,
	[CustomerID] [varchar](50) NULL,
	[Country] [varchar](50) NULL,
	[TOTAL SALES] [varchar](50) NULL,
	[Column 9] [varchar](50) NULL,
	[Column 10] [varchar](50) NULL,
	[Column 11] [varchar](50) NULL,
	[Column 12] [varchar](50) NULL,
	[Column 13] [varchar](50) NULL,
	[Column 14] [varchar](50) NULL,
	[Column 15] [varchar](50) NULL,
	[ One Invoice Id] [varchar](50) NULL,
	[Column 17] [varchar](50) NULL,
	[Column 18] [varchar](50) NULL,
	[Column 19] [varchar](50) NULL,
	[Column 20] [varchar](50) NULL,
	[Column 21] [varchar](50) NULL,
	[Column 22] [varchar](50) NULL,
	[Column 23] [varchar](50) NULL,
	[Column 24] [varchar](50) NULL,
	[Column 25] [varchar](50) NULL,
	[Column 26] [varchar](50) NULL,
	[Column 27] [varchar](50) NULL,
	[Column 28] [varchar](50) NULL,
	[Column 29] [varchar](50) NULL,
	[Column 30] [varchar](50) NULL,
	[Column 31] [varchar](50) NULL
) ON [PRIMARY]
GO


SELECT * FROM ecommerce

--UNIQUE ACTIVE CUSTOMERS --

SELECT COUNT(DISTINCT CustomerID) AS ActiveCustomers
FROM ecommerce

UPDATE ecommerce
SET quantity = '0'  -- Or another default value
WHERE ISNUMERIC(quantity) = 0;

UPDATE ecommerce
SET unitprice = '0'  -- Or another default value
WHERE ISNUMERIC(unitprice) = 0;

-- Alter the table to change quantity from VARCHAR to INT
ALTER TABLE ecommerce
ALTER COLUMN quantity INT;

-- Alter the table to change unitprice from VARCHAR to DECIMAL
ALTER TABLE ecommerce
ALTER COLUMN unitprice DECIMAL(10, 2);  -- Adjust precision/scale as needed


--distribution of total sales, average purchase size, and frequency of transactions--

SELECT 
    CustomerID,
    COUNT(*) AS TransactionFrequency,          -- Frequency of transactions
    SUM(totalsales) AS TotalSales,         -- Total sales for the customer
    AVG(totalsales) AS AveragePurchaseSize -- Average purchase size
FROM 
    (select *, quantity*unitprice as totalsales from ecommerce) as a
GROUP BY 
    CustomerID
ORDER BY 
    TotalSales DESC;
	
--RFM ANALYSIS--

UPDATE ECOMMERCE
SET invoicedate = '1900-01-01'  -- or NULL
WHERE ISDATE(invoicedate) = 0;

SELECT invoicedate
FROM ecommerce
WHERE TRY_CONVERT(DATE, invoicedate, 101) IS NULL;


;WITH RecencyCTE AS (
    SELECT 
        CustomerID,
        DATEDIFF(DAY, MAX(TRY_CONVERT(DATE, invoicedate, 101)), GETDATE()) AS Recency
    FROM ecommerce
    WHERE TRY_CONVERT(DATE, invoicedate, 101) IS NOT NULL  -- Only include valid dates
    GROUP BY CustomerID
),
FrequencyCTE AS (
    SELECT 
        CustomerID,
        COUNT(*) AS Frequency
    FROM ecommerce
    GROUP BY CustomerID
),
MonetaryCTE AS (
    SELECT 
        CustomerID,
        SUM(quantity * unitprice) AS Monetary
    FROM ecommerce
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

--adding rfm scores--

;WITH RecencyCTE AS (
    SELECT 
        CustomerID,
        DATEDIFF(DAY, MAX(TRY_CONVERT(DATE, invoicedate, 101)), GETDATE()) AS Recency
    FROM ecommerce
    WHERE TRY_CONVERT(DATE, invoicedate, 101) IS NOT NULL  -- Handle invalid dates safely
    GROUP BY CustomerID
),
FrequencyCTE AS (
    SELECT 
        CustomerID,
        COUNT(*) AS Frequency
    FROM ecommerce
    GROUP BY CustomerID
),
MonetaryCTE AS (
    SELECT 
        CustomerID,
        SUM(quantity * unitprice) AS Monetary
    FROM ecommerce
    GROUP BY CustomerID
),
RFM AS (
    SELECT 
        R.CustomerID,
        NTILE(5) OVER (ORDER BY R.Recency ASC) AS RecencyScore,  -- Recency: Lower is better
        NTILE(5) OVER (ORDER BY F.Frequency DESC) AS FrequencyScore,  -- Frequency: Higher is better
        NTILE(5) OVER (ORDER BY M.Monetary DESC) AS MonetaryScore  -- Monetary: Higher is better
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

--identify declining segment --


  WITH TotalSales AS (
    SELECT 
        CustomerID,
        SUM(quantity * unitprice) AS TotalSales
    FROM ecommerce
    GROUP BY CustomerID
),
DeclineSegment AS (
    SELECT 
        CustomerID,
        CASE 
            WHEN TotalSales >= 2000 THEN 'High Value'
            WHEN TotalSales BETWEEN 800 AND 2000 THEN 'Medium Value'
            WHEN TotalSales BETWEEN 400 AND 799 THEN 'Low Value'
            ELSE 'Dormant'
        END AS SalesSegment
    FROM TotalSales
),
SalesCounts AS (
    SELECT 
        SalesSegment,
        COUNT(CustomerID) AS CustomerCount
    FROM DeclineSegment
    GROUP BY SalesSegment
)
SELECT 
    SalesSegment,
    CustomerCount,
    FORMAT(CAST(CustomerCount AS FLOAT)*100 / (SELECT COUNT(*) FROM ecommerce) * 100, 'N2') AS Percentage
FROM SalesCounts
ORDER BY 
    CASE SalesSegment
        WHEN 'High Value' THEN 1
        WHEN 'Medium Value' THEN 2
        WHEN 'Low Value' THEN 3
        ELSE 4
    END;
 



