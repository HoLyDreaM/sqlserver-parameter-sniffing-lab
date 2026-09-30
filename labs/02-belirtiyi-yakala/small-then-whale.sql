/*
  Lab 02 — Belirti: önce küçük müşteri koklanır, plan balinada yeniden kullanılır.
  PSP kapalı tutulur; aksi halde SQL Server 2022 tek planı zorunlu kılmayabilir.
  Sonuçlar istemciye dökülmez. Karşılaştırma dbo.LabMeasurement üzerindedir.
  Sabit yüzde yoktur; kendi logical reads / CPU / elapsed değerlerinizi okuyun.

  Paylaşımlı instance'ta DBCC FREEPROCCACHE / DROPCLEANBUFFERS çalıştırmayın.
  Bu script yalnız sp_recompile kullanır.
*/
USE [SniffLab];
GO

SET NOCOUNT ON;

DECLARE @Lab NVARCHAR(80) = N'02-small-then-whale';
DELETE FROM dbo.LabMeasurement WHERE LabName = @Lab;

EXEC dbo.usp_ConfigurePsp @Enabled = 0;
GO

DECLARE @Lab NVARCHAR(80) = N'02-small-then-whale';
DECLARE @Whale INT;
DECLARE @Small INT;

EXEC dbo.usp_GetLabCustomers
    @WhaleCustomerId = @Whale OUTPUT,
    @SmallCustomerId = @Small OUTPUT;

PRINT N'1) Küçük müşteri derlemeyi belirler.';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab,
    @StepName = N'1-kucuk-derleme',
    @CustomerId = @Small,
    @Mode = N'BASE';

PRINT N'2) Balina aynı planı kullanır. Seek planı kaldıysa logical reads sıçrar.';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab,
    @StepName = N'2-balina-ayni-plan',
    @CustomerId = @Whale,
    @Mode = N'BASE';

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
GO
