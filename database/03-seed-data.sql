/*
  SniffLab — sentetik ve dengesiz seed
  Balina müşteri (CustomerId = 1): 80.000 sipariş
  300 küçük müşteri: her biri tam 20 sipariş (örnek küçük müşteri CustomerId = 2)
  Idempotent: SeedComplete = 1 ise atlar. Yarım kalan yüklemede baştan kurar.
  sqlcmd: -d SniffLab -i database/03-seed-data.sql
*/
USE [SniffLab];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (
    SELECT 1
    FROM dbo.SeedMeta
    WHERE SeedKey = N'SeedComplete'
      AND SeedValue = N'1'
)
BEGIN
    PRINT N'Seed zaten tamam. Atlandı.';
    RETURN;
END

DECLARE @WhaleRows INT = 80000;
DECLARE @SmallCustomers INT = 300;
DECLARE @SmallEach INT = 20;
DECLARE @Batch INT = 20000;
DECLARE @Done INT = 0;
DECLARE @Next INT;

PRINT N'=== SniffLab seed başladı ===';

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Orders')
      AND name = N'IX_Orders_CustomerId'
)
    DROP INDEX IX_Orders_CustomerId ON dbo.Orders;

DELETE FROM dbo.Orders;
DELETE FROM dbo.Customers;

SET IDENTITY_INSERT dbo.Customers ON;

INSERT INTO dbo.Customers (CustomerId, DisplayName, SegmentCode)
VALUES (1, N'Balina Müşteri', 'W');

;WITH
L0 AS (SELECT 1 AS c UNION ALL SELECT 1),
L1 AS (SELECT 1 AS c FROM L0 AS a CROSS JOIN L0 AS b),
L2 AS (SELECT 1 AS c FROM L1 AS a CROSS JOIN L1 AS b),
L3 AS (SELECT 1 AS c FROM L2 AS a CROSS JOIN L2 AS b),
L4 AS (SELECT 1 AS c FROM L3 AS a CROSS JOIN L3 AS b)
INSERT INTO dbo.Customers (CustomerId, DisplayName, SegmentCode)
SELECT
    n.n + 1,
    N'Küçük Müşteri ' + CONVERT(NVARCHAR(10), n.n + 1),
    'S'
FROM
(
    SELECT TOP (@SmallCustomers)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM L4
) AS n;

SET IDENTITY_INSERT dbo.Customers OFF;

IF OBJECT_ID(N'tempdb..#Nums', N'U') IS NOT NULL
    DROP TABLE #Nums;

SELECT TOP (@WhaleRows)
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
INTO #Nums
FROM sys.all_objects AS a
CROSS JOIN sys.all_objects AS b;

CREATE UNIQUE CLUSTERED INDEX CX_Nums ON #Nums (n);

WHILE @Done < @WhaleRows
BEGIN
    SET @Next = CASE
        WHEN @WhaleRows - @Done > @Batch THEN @Done + @Batch
        ELSE @WhaleRows
    END;

    INSERT INTO dbo.Orders (CustomerId, StoreId, OrderDate, StatusCode, Amount, Note)
    SELECT
        1,
        (n.n % 40) + 1,
        DATEADD(MINUTE, n.n % 900000, CONVERT(DATETIME2(0), '2023-01-01')),
        CONVERT(TINYINT, (n.n % 5) + 1),
        CONVERT(DECIMAL(12, 2), 15 + ((n.n % 4000) / 10.0)),
        REPLICATE(N'x', 120)
    FROM #Nums AS n
    WHERE n.n > @Done
      AND n.n <= @Next;

    SET @Done = @Next;
    PRINT N'Balina sipariş: ' + CONVERT(NVARCHAR(20), @Done);
END

INSERT INTO dbo.Orders (CustomerId, StoreId, OrderDate, StatusCode, Amount, Note)
SELECT
    ((n.n - 1) / @SmallEach) + 2,
    (n.n % 40) + 1,
    DATEADD(MINUTE, n.n % 900000, CONVERT(DATETIME2(0), '2024-01-01')),
    CONVERT(TINYINT, (n.n % 5) + 1),
    CONVERT(DECIMAL(12, 2), 20 + (n.n % 50)),
    REPLICATE(N'x', 120)
FROM #Nums AS n
WHERE n.n <= (@SmallCustomers * @SmallEach);

CREATE NONCLUSTERED INDEX IX_Orders_CustomerId
    ON dbo.Orders (CustomerId);

UPDATE STATISTICS dbo.Orders IX_Orders_CustomerId WITH FULLSCAN;
UPDATE STATISTICS dbo.Orders PK_Orders WITH FULLSCAN;
UPDATE STATISTICS dbo.Customers PK_Customers WITH FULLSCAN;

DELETE FROM dbo.SeedMeta;

INSERT INTO dbo.SeedMeta (SeedKey, SeedValue)
VALUES
    (N'SeedComplete', N'1'),
    (N'WhaleCustomerId', N'1'),
    (N'SmallCustomerId', N'2'),
    (N'WhaleRows', CONVERT(NVARCHAR(20), @WhaleRows)),
    (N'SmallRows', CONVERT(NVARCHAR(20), @SmallEach)),
    (N'SmallCustomerCount', CONVERT(NVARCHAR(20), @SmallCustomers));

DROP TABLE #Nums;

PRINT N'Seed tamam. Balina CustomerId=1 (' + CONVERT(NVARCHAR(20), @WhaleRows)
    + N' satır). Küçük örnek CustomerId=2 (' + CONVERT(NVARCHAR(20), @SmallEach) + N' satır).';
GO
