/*
  SniffLab — Query Store (lab 03, 05, 07)
  Tekrar çalıştırmak bu veritabanının Query Store geçmişini temizler.
  sqlcmd: -d SniffLab -i database/04-enable-query-store.sql
*/
USE [SniffLab];
GO

SET NOCOUNT ON;

ALTER DATABASE [SniffLab] SET QUERY_STORE = ON
(
    OPERATION_MODE              = READ_WRITE,
    CLEANUP_POLICY              = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 60,
    INTERVAL_LENGTH_MINUTES     = 1,
    MAX_STORAGE_SIZE_MB         = 512,
    QUERY_CAPTURE_MODE          = ALL,
    SIZE_BASED_CLEANUP_MODE     = AUTO,
    MAX_PLANS_PER_QUERY         = 200,
    WAIT_STATS_CAPTURE_MODE     = ON
);
GO

ALTER DATABASE [SniffLab] SET QUERY_STORE CLEAR ALL;
GO

DECLARE @desired TINYINT =
(
    SELECT desired_state
    FROM sys.database_query_store_options
);

IF @desired = 2
    PRINT N'Query Store açık (READ_WRITE) ve temizlendi.';
ELSE
    PRINT N'Uyarı: Query Store istenen durumda değil. desired_state=' + CONVERT(NVARCHAR(10), @desired);
GO
