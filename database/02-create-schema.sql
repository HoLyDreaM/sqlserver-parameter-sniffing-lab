/*
  SniffLab — şema ve laboratuvar prosedürleri
  sqlcmd: -I -f 65001 -d SniffLab -i database/02-create-schema.sql

  IX_Orders_CustomerId bilerek covering değildir.
  Dar müşteride Index Seek + Key Lookup ucuz, balina müşteride aynı plan pahalıdır.
  Asıl iş prosedürü dbo.usp_GetOrdersByCustomer hint içermez.
  *_Recompile / *_OptimizeFor* yalnızca lab 06 içindir.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [SniffLab];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL
AND OBJECT_ID(N'dbo.Customers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Customers
    (
        CustomerId   INT            NOT NULL IDENTITY(1, 1),
        DisplayName  NVARCHAR(120)  NOT NULL,
        SegmentCode  CHAR(1)        NOT NULL,
        CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (CustomerId),
        CONSTRAINT CK_Customers_SegmentCode CHECK (SegmentCode IN ('W', 'S'))
    );
END
GO

IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Orders
    (
        OrderId     BIGINT         NOT NULL IDENTITY(1, 1),
        CustomerId  INT            NOT NULL,
        StoreId     INT            NOT NULL,
        OrderDate   DATETIME2(0)   NOT NULL,
        StatusCode  TINYINT        NOT NULL,
        Amount      DECIMAL(12, 2) NOT NULL,
        Note        NVARCHAR(200)  NOT NULL,
        CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderId),
        CONSTRAINT FK_Orders_Customers
            FOREIGN KEY (CustomerId) REFERENCES dbo.Customers (CustomerId),
        CONSTRAINT CK_Orders_StatusCode CHECK (StatusCode BETWEEN 1 AND 5)
    );
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Orders')
      AND name = N'IX_Orders_CustomerId'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Orders_CustomerId
        ON dbo.Orders (CustomerId);
END
GO

IF OBJECT_ID(N'dbo.SeedMeta', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SeedMeta
    (
        SeedKey   NVARCHAR(64)  NOT NULL,
        SeedValue NVARCHAR(256) NOT NULL,
        CONSTRAINT PK_SeedMeta PRIMARY KEY CLUSTERED (SeedKey)
    );
END
GO

IF OBJECT_ID(N'dbo.LabMeasurement', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LabMeasurement
    (
        MeasurementId  INT            NOT NULL IDENTITY(1, 1),
        LabName        NVARCHAR(80)   NOT NULL,
        StepName       NVARCHAR(80)   NOT NULL,
        ProcedureName  NVARCHAR(256)  NOT NULL,
        CustomerId     INT            NOT NULL,
        ReturnedRows   BIGINT         NULL,
        LogicalReads   BIGINT         NULL,
        CpuMs          BIGINT         NULL,
        ElapsedMs      BIGINT         NULL,
        PlanShape      NVARCHAR(120)  NULL,
        CapturedAt     DATETIME2(0)   NOT NULL CONSTRAINT DF_LabMeasurement_CapturedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_LabMeasurement PRIMARY KEY CLUSTERED (MeasurementId)
    );
END
GO

/*
  Üretim benzeri prosedür: hint yok.
  Plan, ilk derlemede koklanan parametreye göre seçilir ve yeniden kullanılabilir.
  CHECKSUM, covering olmayan indekste Key Lookup oluşsun diye Note ve diğer kolonları okur.
  İstemciye tek satır döner; ölçüm, 80.000 satırlık aktarım maliyetine karışmaz.
*/
CREATE OR ALTER PROCEDURE dbo.usp_GetOrdersByCustomer
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT_BIG(*) AS ReturnedRows,
        CHECKSUM_AGG(CHECKSUM(o.OrderId, o.StoreId, o.StatusCode, o.Amount, o.OrderDate, o.Note)) AS PayloadChecksum
    FROM dbo.Orders AS o
    WHERE o.CustomerId = @CustomerId;
END
GO

/* Lab 06 — her çağrıda mevcut parametreyle derleme. Sık çalışan sorgunun varsayılanı değildir. */
CREATE OR ALTER PROCEDURE dbo.usp_GetOrdersByCustomer_Recompile
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT_BIG(*) AS ReturnedRows,
        CHECKSUM_AGG(CHECKSUM(o.OrderId, o.StoreId, o.StatusCode, o.Amount, o.OrderDate, o.Note)) AS PayloadChecksum
    FROM dbo.Orders AS o
    WHERE o.CustomerId = @CustomerId
    OPTION (RECOMPILE);
END
GO

/*
  Lab 06 — temsilî değer olarak balina müşteri (seed sözleşmesi: CustomerId = 1).
  Küçük müşteri çağrıları bu planla gereksiz tarama yapabilir.
*/
CREATE OR ALTER PROCEDURE dbo.usp_GetOrdersByCustomer_OptimizeForWhale
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT_BIG(*) AS ReturnedRows,
        CHECKSUM_AGG(CHECKSUM(o.OrderId, o.StoreId, o.StatusCode, o.Amount, o.OrderDate, o.Note)) AS PayloadChecksum
    FROM dbo.Orders AS o
    WHERE o.CustomerId = @CustomerId
    OPTION (OPTIMIZE FOR (@CustomerId = 1));
END
GO

/* Lab 06 — koklanan tek değere bağlanmayan ortalama seçicilik tahmini. */
CREATE OR ALTER PROCEDURE dbo.usp_GetOrdersByCustomer_OptimizeForUnknown
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT_BIG(*) AS ReturnedRows,
        CHECKSUM_AGG(CHECKSUM(o.OrderId, o.StoreId, o.StatusCode, o.Amount, o.OrderDate, o.Note)) AS PayloadChecksum
    FROM dbo.Orders AS o
    WHERE o.CustomerId = @CustomerId
    OPTION (OPTIMIZE FOR UNKNOWN);
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetLabCustomers
    @WhaleCustomerId INT OUTPUT,
    @SmallCustomerId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @WhaleCustomerId = TRY_CONVERT(INT, (
        SELECT SeedValue FROM dbo.SeedMeta WHERE SeedKey = N'WhaleCustomerId'
    ));
    SET @SmallCustomerId = TRY_CONVERT(INT, (
        SELECT SeedValue FROM dbo.SeedMeta WHERE SeedKey = N'SmallCustomerId'
    ));

    IF @WhaleCustomerId IS NULL OR @SmallCustomerId IS NULL
        THROW 50001, N'SeedMeta eksik. database/03-seed-data.sql çalıştırın.', 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_ConfigurePsp
    @Enabled BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Sql NVARCHAR(200) =
        CASE
            WHEN @Enabled = 1 THEN N'ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON;'
            ELSE N'ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = OFF;'
        END;

    EXEC sys.sp_executesql @Sql;

    EXEC sys.sp_recompile N'dbo.usp_GetOrdersByCustomer';
    EXEC sys.sp_recompile N'dbo.usp_GetOrdersByCustomer_Recompile';
    EXEC sys.sp_recompile N'dbo.usp_GetOrdersByCustomer_OptimizeForWhale';
    EXEC sys.sp_recompile N'dbo.usp_GetOrdersByCustomer_OptimizeForUnknown';

    PRINT N'PSP '
        + CASE WHEN @Enabled = 1 THEN N'ON' ELSE N'OFF' END
        + N'. Laboratuvar prosedürleri yeniden derleme için işaretlendi. sp_recompile yalnız bu prosedürleri etkiler.';
END
GO

/*
  Tek satırlık sonuç kümesini alır.
  Logical reads, iç prosedürün dm_exec_procedure_stats.last_* değeridir.
*/
CREATE OR ALTER PROCEDURE dbo.usp_MeasureCustomer
    @LabName     NVARCHAR(80),
    @StepName    NVARCHAR(80),
    @CustomerId  INT,
    @Mode        NVARCHAR(32)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode NOT IN (N'BASE', N'RECOMPILE', N'OPTIMIZE_FOR_WHALE', N'OPTIMIZE_FOR_UNKNOWN')
        THROW 50002, N'Geçersiz ölçüm modu.', 1;

    DECLARE @Proc NVARCHAR(256) =
        CASE @Mode
            WHEN N'BASE' THEN N'dbo.usp_GetOrdersByCustomer'
            WHEN N'RECOMPILE' THEN N'dbo.usp_GetOrdersByCustomer_Recompile'
            WHEN N'OPTIMIZE_FOR_WHALE' THEN N'dbo.usp_GetOrdersByCustomer_OptimizeForWhale'
            ELSE N'dbo.usp_GetOrdersByCustomer_OptimizeForUnknown'
        END;

    CREATE TABLE #One
    (
        ReturnedRows     BIGINT NULL,
        PayloadChecksum  INT    NULL
    );

    IF @Mode = N'BASE'
        INSERT INTO #One EXEC dbo.usp_GetOrdersByCustomer @CustomerId = @CustomerId;
    ELSE IF @Mode = N'RECOMPILE'
        INSERT INTO #One EXEC dbo.usp_GetOrdersByCustomer_Recompile @CustomerId = @CustomerId;
    ELSE IF @Mode = N'OPTIMIZE_FOR_WHALE'
        INSERT INTO #One EXEC dbo.usp_GetOrdersByCustomer_OptimizeForWhale @CustomerId = @CustomerId;
    ELSE
        INSERT INTO #One EXEC dbo.usp_GetOrdersByCustomer_OptimizeForUnknown @CustomerId = @CustomerId;

    DECLARE @Rows BIGINT = (SELECT TOP (1) ReturnedRows FROM #One);
    DROP TABLE #One;

    DECLARE @Logical BIGINT;
    DECLARE @Cpu BIGINT;
    DECLARE @Elapsed BIGINT;
    DECLARE @Plan XML;
    DECLARE @Shape NVARCHAR(120);

    SELECT TOP (1)
        @Logical = ps.last_logical_reads,
        @Cpu = ps.last_worker_time / 1000,
        @Elapsed = ps.last_elapsed_time / 1000
    FROM sys.dm_exec_procedure_stats AS ps
    WHERE ps.database_id = DB_ID()
      AND ps.object_id = OBJECT_ID(@Proc)
    ORDER BY ps.last_execution_time DESC;

    SELECT TOP (1) @Plan = qp.query_plan
    FROM sys.dm_exec_procedure_stats AS ps
    OUTER APPLY sys.dm_exec_query_plan(ps.plan_handle) AS qp
    WHERE ps.database_id = DB_ID()
      AND ps.object_id = OBJECT_ID(@Proc)
    ORDER BY ps.last_execution_time DESC;

    SET @Shape = N'(plan cache yok)';

    IF @Plan IS NOT NULL
    BEGIN
        IF @Plan.exist('//*[local-name()="Dispatcher"]') = 1
            SET @Shape = N'PSP dispatcher';
        ELSE IF @Plan.exist('//*[local-name()="RelOp" and @PhysicalOp="Index Seek"]') = 1
            SET @Shape = N'Index Seek + Key Lookup';
        ELSE IF @Plan.exist('//*[local-name()="RelOp" and @PhysicalOp="Clustered Index Scan"]') = 1
            SET @Shape = N'Clustered Index Scan';
        ELSE
            SET @Shape = N'(SSMS Actual Plan ile doğrulayın)';
    END
    ELSE IF @Mode = N'RECOMPILE'
        SET @Shape = N'RECOMPILE (plan cache''te kalmaz)';

    INSERT INTO dbo.LabMeasurement
    (
        LabName, StepName, ProcedureName, CustomerId,
        ReturnedRows, LogicalReads, CpuMs, ElapsedMs, PlanShape
    )
    VALUES
    (
        @LabName, @StepName, @Proc, @CustomerId,
        @Rows, @Logical, @Cpu, @Elapsed, @Shape
    );

    SELECT
        LabName,
        StepName,
        ProcedureName,
        CustomerId,
        ReturnedRows,
        LogicalReads,
        CpuMs,
        ElapsedMs,
        PlanShape
    FROM dbo.LabMeasurement
    WHERE MeasurementId = CONVERT(INT, SCOPE_IDENTITY());
END
GO

PRINT N'Şema hazır: Customers, Orders, SeedMeta, LabMeasurement, ölçüm prosedürleri.';
GO
