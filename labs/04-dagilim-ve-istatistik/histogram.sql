/*
  Lab 04 — Veri dağılımı ve istatistik histogramı.
  Salt okunur. EQ_ROWS balina adımında on binler, küçük müşteride 20 olmalıdır.
  Eski istatistik planı bozar; kör UPDATE STATISTICS her iş yükünü düzeltmez.
  Bu veritabanında seed sonrası FULLSCAN alınmıştır.
*/
USE [SniffLab];
GO

SET NOCOUNT ON;

DECLARE @Whale INT;
DECLARE @Small INT;
EXEC dbo.usp_GetLabCustomers
    @WhaleCustomerId = @Whale OUTPUT,
    @SmallCustomerId = @Small OUTPUT;

SELECT
    c.CustomerId,
    c.DisplayName,
    COUNT_BIG(*) AS OrderRows
FROM dbo.Customers AS c
JOIN dbo.Orders AS o ON o.CustomerId = c.CustomerId
WHERE c.CustomerId IN (@Whale, @Small)
GROUP BY c.CustomerId, c.DisplayName
ORDER BY OrderRows DESC;

SELECT
    s.name AS StatsName,
    STATS_DATE(s.object_id, s.stats_id) AS LastUpdated,
    s.auto_created,
    s.user_created
FROM sys.stats AS s
WHERE s.object_id = OBJECT_ID(N'dbo.Orders')
ORDER BY s.stats_id;

PRINT N'--- IX_Orders_CustomerId histogram ---';
DBCC SHOW_STATISTICS (N'dbo.Orders', N'IX_Orders_CustomerId') WITH HISTOGRAM;
GO

PRINT N'Histogramda RANGE_HI_KEY / EQ_ROWS alanına bakın.';
PRINT N'CustomerId = 1 satırındaki EQ_ROWS, küçük müşterilerin adımlarından çok büyük olmalıdır.';
PRINT N'Aynı prensip şirket, mağaza, tarih, belge tipi veya durum kodu gibi yüksek varyanslı filtrelerde de geçerlidir.';
GO
