/*
  SniffLab — smoke test
  sqlcmd: -i scripts/run-smoke-tests.sql
  Hata varsa severity 16.
*/
SET NOCOUNT ON;

IF TRY_CONVERT(INT, SERVERPROPERTY(N'ProductMajorVersion')) < 16
BEGIN
    RAISERROR(N'[FAIL] SQL Server 2022 (major 16) veya üzeri gerekir.', 16, 1);
    RETURN;
END
ELSE
    PRINT N'[PASS] ProductMajorVersion=' + CONVERT(NVARCHAR(10), SERVERPROPERTY(N'ProductMajorVersion'));
GO

IF DB_ID(N'SniffLab') IS NULL
BEGIN
    RAISERROR(N'[FAIL] SniffLab veritabanı yok.', 16, 1);
    RETURN;
END
ELSE
    PRINT N'[PASS] Veritabanı SniffLab mevcut.';
GO

USE [SniffLab];
GO

SET NOCOUNT ON;

DECLARE @Errors INT = 0;

IF (SELECT compatibility_level FROM sys.databases WHERE name = N'SniffLab') <> 160
BEGIN
    PRINT N'[FAIL] compatibility_level 160 değil.';
    SET @Errors += 1;
END
ELSE
    PRINT N'[PASS] compatibility_level 160';

IF OBJECT_ID(N'dbo.Customers', N'U') IS NULL BEGIN PRINT N'[FAIL] Customers yok.'; SET @Errors += 1; END ELSE PRINT N'[PASS] Customers';
IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL BEGIN PRINT N'[FAIL] Orders yok.'; SET @Errors += 1; END ELSE PRINT N'[PASS] Orders';
IF OBJECT_ID(N'dbo.SeedMeta', N'U') IS NULL BEGIN PRINT N'[FAIL] SeedMeta yok.'; SET @Errors += 1; END ELSE PRINT N'[PASS] SeedMeta';
IF OBJECT_ID(N'dbo.LabMeasurement', N'U') IS NULL BEGIN PRINT N'[FAIL] LabMeasurement yok.'; SET @Errors += 1; END ELSE PRINT N'[PASS] LabMeasurement';

IF OBJECT_ID(N'dbo.usp_GetOrdersByCustomer', N'P') IS NULL BEGIN PRINT N'[FAIL] usp_GetOrdersByCustomer yok.'; SET @Errors += 1; END ELSE PRINT N'[PASS] usp_GetOrdersByCustomer';
IF OBJECT_ID(N'dbo.usp_GetOrdersByCustomer_Recompile', N'P') IS NULL BEGIN PRINT N'[FAIL] Recompile prosedürü yok.'; SET @Errors += 1; END ELSE PRINT N'[PASS] usp_GetOrdersByCustomer_Recompile';
IF OBJECT_ID(N'dbo.usp_GetOrdersByCustomer_OptimizeForWhale', N'P') IS NULL BEGIN PRINT N'[FAIL] OptimizeForWhale yok.'; SET @Errors += 1; END ELSE PRINT N'[PASS] usp_GetOrdersByCustomer_OptimizeForWhale';
IF OBJECT_ID(N'dbo.usp_GetOrdersByCustomer_OptimizeForUnknown', N'P') IS NULL BEGIN PRINT N'[FAIL] OptimizeForUnknown yok.'; SET @Errors += 1; END ELSE PRINT N'[PASS] usp_GetOrdersByCustomer_OptimizeForUnknown';
IF OBJECT_ID(N'dbo.usp_MeasureCustomer', N'P') IS NULL BEGIN PRINT N'[FAIL] usp_MeasureCustomer yok.'; SET @Errors += 1; END ELSE PRINT N'[PASS] usp_MeasureCustomer';

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Orders') AND name = N'IX_Orders_CustomerId'
)
BEGIN
    PRINT N'[FAIL] IX_Orders_CustomerId yok.';
    SET @Errors += 1;
END
ELSE
    PRINT N'[PASS] IX_Orders_CustomerId';

DECLARE @WhaleId INT = TRY_CONVERT(INT, (SELECT SeedValue FROM dbo.SeedMeta WHERE SeedKey = N'WhaleCustomerId'));
DECLARE @SmallId INT = TRY_CONVERT(INT, (SELECT SeedValue FROM dbo.SeedMeta WHERE SeedKey = N'SmallCustomerId'));
DECLARE @WhaleExpected BIGINT = TRY_CONVERT(BIGINT, (SELECT SeedValue FROM dbo.SeedMeta WHERE SeedKey = N'WhaleRows'));
DECLARE @SmallExpected BIGINT = TRY_CONVERT(BIGINT, (SELECT SeedValue FROM dbo.SeedMeta WHERE SeedKey = N'SmallRows'));
DECLARE @WhaleActual BIGINT = (SELECT COUNT_BIG(*) FROM dbo.Orders WHERE CustomerId = @WhaleId);
DECLARE @SmallActual BIGINT = (SELECT COUNT_BIG(*) FROM dbo.Orders WHERE CustomerId = @SmallId);

IF @WhaleId IS NULL OR @SmallId IS NULL OR ISNULL(@WhaleExpected, 0) < 1000 OR ISNULL(@SmallExpected, 0) < 1
BEGIN
    PRINT N'[FAIL] SeedMeta eksik veya seed tamamlanmamış.';
    SET @Errors += 1;
END
ELSE IF @WhaleActual <> @WhaleExpected OR @SmallActual <> @SmallExpected OR @WhaleActual < @SmallActual * 1000
BEGIN
    PRINT N'[FAIL] Dağılım beklenen skew''e uymuyor. Balina='
        + CONVERT(NVARCHAR(20), @WhaleActual) + N' Küçük=' + CONVERT(NVARCHAR(20), @SmallActual);
    SET @Errors += 1;
END
ELSE
    PRINT N'[PASS] Skew balina=' + CONVERT(NVARCHAR(20), @WhaleActual)
        + N' küçük=' + CONVERT(NVARCHAR(20), @SmallActual);

DECLARE @qs TINYINT = (SELECT actual_state FROM sys.database_query_store_options);
IF @qs IS NULL OR @qs = 0
BEGIN
    PRINT N'[FAIL] Query Store kapalı.';
    SET @Errors += 1;
END
ELSE
    PRINT N'[PASS] Query Store actual_state=' + CONVERT(NVARCHAR(10), @qs);

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_scoped_configurations
    WHERE name = N'PARAMETER_SENSITIVE_PLAN_OPTIMIZATION'
)
BEGIN
    PRINT N'[FAIL] PARAMETER_SENSITIVE_PLAN_OPTIMIZATION yok.';
    SET @Errors += 1;
END
ELSE
    PRINT N'[PASS] PSP yapılandırması okunabiliyor.';

IF @Errors > 0
BEGIN
    DECLARE @Msg NVARCHAR(200) = N'[FAIL] Smoke test hata sayısı=' + CONVERT(NVARCHAR(10), @Errors);
    RAISERROR(@Msg, 16, 1);
END
ELSE
    PRINT N'[PASS] Smoke test tamam.';
GO
