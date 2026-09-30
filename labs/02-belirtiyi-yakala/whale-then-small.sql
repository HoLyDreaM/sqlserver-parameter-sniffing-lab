/*
  Lab 02 — Ters sıra: önce balina koklanır.
  Scan planı küçük müşteride de kalabilir. Bu da boşa I/O üretir;
  küçük-sonra-balina kadar sert olmayabilir. İkisini birlikte okuyun.
*/
USE [SniffLab];
GO

SET NOCOUNT ON;

DECLARE @Lab NVARCHAR(80) = N'02-whale-then-small';
DELETE FROM dbo.LabMeasurement WHERE LabName = @Lab;

EXEC dbo.usp_ConfigurePsp @Enabled = 0;
GO

DECLARE @Lab NVARCHAR(80) = N'02-whale-then-small';
DECLARE @Whale INT;
DECLARE @Small INT;

EXEC dbo.usp_GetLabCustomers
    @WhaleCustomerId = @Whale OUTPUT,
    @SmallCustomerId = @Small OUTPUT;

PRINT N'1) Balina müşteri derlemeyi belirler.';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab,
    @StepName = N'1-balina-derleme',
    @CustomerId = @Whale,
    @Mode = N'BASE';

PRINT N'2) Küçük müşteri aynı planı kullanır.';
EXEC dbo.usp_MeasureCustomer
    @LabName = @Lab,
    @StepName = N'2-kucuk-ayni-plan',
    @CustomerId = @Small,
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
