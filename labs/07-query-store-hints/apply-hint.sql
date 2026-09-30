/*
  Lab 07 — Query Store hint (kod değiştirmeden).
  SQL Server 2022'de sp_query_store_set_hints, query_id için hint uygular.
  OPTIMIZE FOR (@degisken = literal) Query Store hint olarak desteklenmez.
  Bu script OPTION (OPTIMIZE FOR UNKNOWN) kullanır.
  Microsoft bu araçları son çare olarak konumlandırır.

  Hint, clear-hint.sql çalışana kadar bu veritabanında kalır.
  Üretimde önce baseline alın, dar kapsam uygulayın, aynı parametre setiyle tekrar ölçün.
*/
USE [SniffLab];
GO

SET NOCOUNT ON;

DECLARE @Lab NVARCHAR(80) = N'07-query-store-hint';
DELETE FROM dbo.LabMeasurement WHERE LabName = @Lab;

EXEC dbo.usp_ConfigurePsp @Enabled = 0;
GO

DECLARE @Lab NVARCHAR(80) = N'07-query-store-hint';
DECLARE @Whale INT;
DECLARE @Small INT;
DECLARE @QueryId BIGINT;

EXEC dbo.usp_GetLabCustomers
    @WhaleCustomerId = @Whale OUTPUT,
    @SmallCustomerId = @Small OUTPUT;

PRINT N'Query Store kaydı için hint''siz bir çalıştırma.';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab, @StepName = N'oncesi-kucuk', @CustomerId = @Small, @Mode = N'BASE';

EXEC sys.sp_query_store_flush_db;

SELECT TOP (1) @QueryId = q.query_id
FROM sys.query_store_query AS q
JOIN sys.query_store_query_text AS t
    ON t.query_text_id = q.query_text_id
WHERE q.object_id = OBJECT_ID(N'dbo.usp_GetOrdersByCustomer')
  AND t.query_sql_text LIKE N'%Orders%'
  AND t.query_sql_text LIKE N'%CustomerId%'
ORDER BY q.last_execution_time DESC;

IF @QueryId IS NULL
    THROW 50007, N'Query Store bu prosedür için query_id üretmedi. 04-enable-query-store.sql sonrası lab 07''yi tekrar çalıştırın.', 1;

PRINT N'query_id=' + CONVERT(NVARCHAR(20), @QueryId);

EXEC sys.sp_query_store_set_hints
    @query_id = @QueryId,
    @query_hints = N'OPTION (OPTIMIZE FOR UNKNOWN)';

EXEC sys.sp_recompile N'dbo.usp_GetOrdersByCustomer';

PRINT N'Hint uygulandı. Aynı iki müşteri tekrar ölçülüyor.';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab, @StepName = N'hint-kucuk', @CustomerId = @Small, @Mode = N'BASE';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab, @StepName = N'hint-balina', @CustomerId = @Whale, @Mode = N'BASE';

SELECT
    StepName,
    CustomerId,
    ReturnedRows,
    LogicalReads,
    CpuMs,
    ElapsedMs,
    PlanShape
FROM dbo.LabMeasurement
WHERE LabName = @Lab
ORDER BY MeasurementId;

SELECT
    h.query_id,
    h.query_hint_text
FROM sys.query_store_query_hints AS h
WHERE h.query_id = @QueryId;

PRINT N'İşi bitirince labs/07-query-store-hints/clear-hint.sql çalıştırın.';
GO
