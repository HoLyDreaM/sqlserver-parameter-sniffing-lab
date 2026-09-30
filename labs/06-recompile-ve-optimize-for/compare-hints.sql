/*
  Lab 06 — RECOMPILE, OPTIMIZE FOR ve OPTIMIZE FOR UNKNOWN.
  PSP kapalıdır; böylece fark hint'ten gelir, PSP'den değil.
  Dört modda küçük ve balina müşteri ölçülür.
  OPTIMIZE FOR (@CustomerId = 1) balina için iyidir; küçük müşteride tarama maliyeti doğurabilir.
  RECOMPILE her çağrıda derleme CPU'su ekler. Sık çalışan kısa sorgunun varsayılanı yapmayın.
  Karar: tek çağrı değil, iki parametre sınıfının toplam maliyeti.
*/
USE [SniffLab];
GO

SET NOCOUNT ON;

DECLARE @Lab NVARCHAR(80) = N'06-hints';
DELETE FROM dbo.LabMeasurement WHERE LabName = @Lab;

EXEC dbo.usp_ConfigurePsp @Enabled = 0;
GO

DECLARE @Lab NVARCHAR(80) = N'06-hints';
DECLARE @Whale INT;
DECLARE @Small INT;

EXEC dbo.usp_GetLabCustomers
    @WhaleCustomerId = @Whale OUTPUT,
    @SmallCustomerId = @Small OUTPUT;

EXEC dbo.usp_MeasureCustomer @LabName = @Lab, @StepName = N'base-kucuk', @CustomerId = @Small, @Mode = N'BASE';
EXEC dbo.usp_MeasureCustomer @LabName = @Lab, @StepName = N'base-balina', @CustomerId = @Whale, @Mode = N'BASE';

EXEC sys.sp_recompile N'dbo.usp_GetOrdersByCustomer';

EXEC dbo.usp_MeasureCustomer @LabName = @Lab, @StepName = N'recompile-kucuk', @CustomerId = @Small, @Mode = N'RECOMPILE';
EXEC dbo.usp_MeasureCustomer @LabName = @Lab, @StepName = N'recompile-balina', @CustomerId = @Whale, @Mode = N'RECOMPILE';

EXEC dbo.usp_MeasureCustomer @LabName = @Lab, @StepName = N'opt-whale-kucuk', @CustomerId = @Small, @Mode = N'OPTIMIZE_FOR_WHALE';
EXEC dbo.usp_MeasureCustomer @LabName = @Lab, @StepName = N'opt-whale-balina', @CustomerId = @Whale, @Mode = N'OPTIMIZE_FOR_WHALE';

EXEC dbo.usp_MeasureCustomer @LabName = @Lab, @StepName = N'opt-unknown-kucuk', @CustomerId = @Small, @Mode = N'OPTIMIZE_FOR_UNKNOWN';
EXEC dbo.usp_MeasureCustomer @LabName = @Lab, @StepName = N'opt-unknown-balina', @CustomerId = @Whale, @Mode = N'OPTIMIZE_FOR_UNKNOWN';

SELECT
    StepName,
    ProcedureName,
    CustomerId,
    ReturnedRows,
    LogicalReads,
    CpuMs,
    ElapsedMs,
    PlanShape
FROM dbo.LabMeasurement
WHERE LabName = @Lab
ORDER BY MeasurementId;
GO
