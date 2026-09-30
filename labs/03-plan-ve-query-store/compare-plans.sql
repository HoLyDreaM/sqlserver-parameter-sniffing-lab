/*
  Lab 03 — Execution plan ve Query Store.
  Aynı prosedür için iki derleme yönünü çalıştırır, sonra Query Store'da
  plan başına execution / duration / logical I/O okur.
  Tek plan ekranı geçmişi göstermez; bu script onu kalıcı istatistikle tamamlar.
*/
USE [SniffLab];
GO

SET NOCOUNT ON;

DECLARE @Lab NVARCHAR(80) = N'03-plan-query-store';
DELETE FROM dbo.LabMeasurement WHERE LabName = @Lab;

EXEC dbo.usp_ConfigurePsp @Enabled = 0;
GO

DECLARE @Lab NVARCHAR(80) = N'03-plan-query-store';
DECLARE @Whale INT;
DECLARE @Small INT;

EXEC dbo.usp_GetLabCustomers
    @WhaleCustomerId = @Whale OUTPUT,
    @SmallCustomerId = @Small OUTPUT;

PRINT N'Yön A: küçük değer koklanır, balinada yeniden kullanılır.';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab, @StepName = N'A-kucuk', @CustomerId = @Small, @Mode = N'BASE';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab, @StepName = N'A-balina', @CustomerId = @Whale, @Mode = N'BASE';

EXEC dbo.usp_ConfigurePsp @Enabled = 0;

PRINT N'Yön B: balina değer koklanır, küçük müşteride yeniden kullanılır.';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab, @StepName = N'B-balina', @CustomerId = @Whale, @Mode = N'BASE';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab, @StepName = N'B-kucuk', @CustomerId = @Small, @Mode = N'BASE';

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

EXEC sys.sp_query_store_flush_db;

SELECT
    q.query_id,
    p.plan_id,
    p.plan_type_desc,
    rs.count_executions,
    rs.avg_duration / 1000.0 AS avg_duration_ms,
    rs.avg_cpu_time / 1000.0 AS avg_cpu_ms,
    rs.avg_logical_io_reads,
    rsi.start_time
FROM sys.query_store_query AS q
JOIN sys.query_store_plan AS p
    ON p.query_id = q.query_id
JOIN sys.query_store_runtime_stats AS rs
    ON rs.plan_id = p.plan_id
JOIN sys.query_store_runtime_stats_interval AS rsi
    ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
WHERE q.object_id = OBJECT_ID(N'dbo.usp_GetOrdersByCustomer')
ORDER BY rsi.start_time, p.plan_id;

PRINT N'SSMS Actual Plan: tahmini satır ile gerçek satır, Seek/Scan ve Key Lookup.';
PRINT N'Query Store satırı boşsa bir kez daha çalıştırın; flush sonrası aralık yeni dolmuş olmalıdır.';
GO
