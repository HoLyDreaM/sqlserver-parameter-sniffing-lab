/*
  Lab 05 — SQL Server 2022 Parameter Sensitive Plan (PSP) optimization.
  Compatibility level 160 ve PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON gerekir.
  Özellik her yavaş sorguyu otomatik düzeltmez. Dispatcher görünmezse
  predicate, histogram ve eligibility koşullarını kontrol edin.
  Varyantların çalışma istatistiği Query Store'dadır; dispatcher planı runtime üretmez.
*/
USE [SniffLab];
GO

SET NOCOUNT ON;

DECLARE @Lab NVARCHAR(80) = N'05-psp';
DELETE FROM dbo.LabMeasurement WHERE LabName = @Lab;

EXEC dbo.usp_ConfigurePsp @Enabled = 1;
GO

DECLARE @Lab NVARCHAR(80) = N'05-psp';
DECLARE @Whale INT;
DECLARE @Small INT;

EXEC dbo.usp_GetLabCustomers
    @WhaleCustomerId = @Whale OUTPUT,
    @SmallCustomerId = @Small OUTPUT;

PRINT N'Küçük ve balina değerler, PSP açıkken art arda çalıştırılıyor.';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab, @StepName = N'psp-kucuk', @CustomerId = @Small, @Mode = N'BASE';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab, @StepName = N'psp-balina', @CustomerId = @Whale, @Mode = N'BASE';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab, @StepName = N'psp-kucuk-2', @CustomerId = @Small, @Mode = N'BASE';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab, @StepName = N'psp-balina-2', @CustomerId = @Whale, @Mode = N'BASE';

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
    name,
    value
FROM sys.database_scoped_configurations
WHERE name = N'PARAMETER_SENSITIVE_PLAN_OPTIMIZATION';

SELECT
    CONVERT(XML, p.query_plan) AS query_plan,
    p.plan_id,
    p.plan_type_desc,
    q.query_id,
    q.object_id
FROM sys.query_store_plan AS p
JOIN sys.query_store_query AS q
    ON q.query_id = p.query_id
WHERE q.object_id = OBJECT_ID(N'dbo.usp_GetOrdersByCustomer')
   OR q.query_id IN
   (
        SELECT v.query_variant_query_id
        FROM sys.query_store_query_variant AS v
        JOIN sys.query_store_query AS parent
            ON parent.query_id = v.parent_query_id
        WHERE parent.object_id = OBJECT_ID(N'dbo.usp_GetOrdersByCustomer')
   )
ORDER BY p.plan_type_desc, p.plan_id;

SELECT
    v.parent_query_id,
    v.dispatcher_plan_id,
    v.query_variant_query_id,
    parent_plan.plan_type_desc AS parent_plan_type,
    variant_plan.plan_id AS variant_plan_id,
    variant_plan.plan_type_desc AS variant_plan_type,
    rs.count_executions,
    rs.avg_logical_io_reads,
    rs.avg_duration / 1000.0 AS avg_duration_ms
FROM sys.query_store_query_variant AS v
JOIN sys.query_store_query AS parent
    ON parent.query_id = v.parent_query_id
LEFT JOIN sys.query_store_plan AS parent_plan
    ON parent_plan.plan_id = v.dispatcher_plan_id
LEFT JOIN sys.query_store_plan AS variant_plan
    ON variant_plan.query_id = v.query_variant_query_id
LEFT JOIN sys.query_store_runtime_stats AS rs
    ON rs.plan_id = variant_plan.plan_id
WHERE parent.object_id = OBJECT_ID(N'dbo.usp_GetOrdersByCustomer');

IF NOT EXISTS (
    SELECT 1
    FROM sys.query_store_query_variant AS v
    JOIN sys.query_store_query AS parent
        ON parent.query_id = v.parent_query_id
    WHERE parent.object_id = OBJECT_ID(N'dbo.usp_GetOrdersByCustomer')
)
BEGIN
    PRINT N'PSP varyantı oluşmadı. Bu, özelliğin kapalı olduğu anlamına gelmez.';
    PRINT N'Kontrol: compatibility 160, PSP = ON, eşitlik parametresi, histogramda skew.';
    PRINT N'Eligibility iş yüküne bağlıdır; dispatcher yoksa lab 06 ve 07 hedefli araçlardır.';
END
ELSE
    PRINT N'PSP dispatcher ve query variant kayıtları Query Store''da görünüyor.';
GO
