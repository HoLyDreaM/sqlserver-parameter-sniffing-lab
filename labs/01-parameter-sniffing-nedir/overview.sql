/*
  Lab 01 — Parameter sniffing nedir?
  Salt okunur. Veri dağılımını ve hint'siz prosedürü gösterir.
  sqlcmd: -d SniffLab -i labs/01-parameter-sniffing-nedir/overview.sql
*/
USE [SniffLab];
GO

SET NOCOUNT ON;

DECLARE @Whale INT;
DECLARE @Small INT;
EXEC dbo.usp_GetLabCustomers
    @WhaleCustomerId = @Whale OUTPUT,
    @SmallCustomerId = @Small OUTPUT;

PRINT N'Parameter sniffing bir hata değildir.';
PRINT N'SQL Server parametrik sorguyu derlerken o anki değeri kullanır ve planı yeniden kullanır.';
PRINT N'Sorun, dengesiz dağılımda bu planın başka bir değere pahalı gelmesidir.';
PRINT N'Hedef sniffing''i kapatmak değil; problemli sorguyu ölçüp en dar çözümü seçmektir.';
PRINT N'';

SELECT
    c.SegmentCode,
    COUNT(*) AS CustomerCount,
    SUM(x.OrderRows) AS OrderRows,
    MIN(x.OrderRows) AS MinOrders,
    MAX(x.OrderRows) AS MaxOrders
FROM dbo.Customers AS c
JOIN
(
    SELECT CustomerId, COUNT_BIG(*) AS OrderRows
    FROM dbo.Orders
    GROUP BY CustomerId
) AS x ON x.CustomerId = c.CustomerId
GROUP BY c.SegmentCode
ORDER BY c.SegmentCode DESC;

SELECT
    c.CustomerId,
    c.DisplayName,
    c.SegmentCode,
    COUNT_BIG(*) AS OrderRows
FROM dbo.Customers AS c
JOIN dbo.Orders AS o ON o.CustomerId = c.CustomerId
WHERE c.CustomerId IN (@Whale, @Small)
GROUP BY c.CustomerId, c.DisplayName, c.SegmentCode
ORDER BY COUNT_BIG(*) DESC;

SELECT
    i.name AS IndexName,
    i.type_desc,
    i.is_unique
FROM sys.indexes AS i
WHERE i.object_id = OBJECT_ID(N'dbo.Orders')
ORDER BY i.index_id;

PRINT N'IX_Orders_CustomerId covering değildir. Seek planı Note ve Amount için Key Lookup yapar.';
PRINT N'Sonraki lab: labs/02-belirtiyi-yakala/small-then-whale.sql';
GO
