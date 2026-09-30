/*
  Lab 07 — Query Store hint temizliği.
  Yalnız dbo.usp_GetOrdersByCustomer ifadelerine bağlı hint'leri kaldırır.
*/
USE [SniffLab];
GO

SET NOCOUNT ON;

DECLARE @QueryId BIGINT;

WHILE EXISTS (
    SELECT 1
    FROM sys.query_store_query_hints AS h
    JOIN sys.query_store_query AS q
        ON q.query_id = h.query_id
    WHERE q.object_id = OBJECT_ID(N'dbo.usp_GetOrdersByCustomer')
)
BEGIN
    SELECT TOP (1) @QueryId = h.query_id
    FROM sys.query_store_query_hints AS h
    JOIN sys.query_store_query AS q
        ON q.query_id = h.query_id
    WHERE q.object_id = OBJECT_ID(N'dbo.usp_GetOrdersByCustomer')
    ORDER BY h.query_id;

    EXEC sys.sp_query_store_clear_hints @query_id = @QueryId;
    PRINT N'Hint temizlendi. query_id=' + CONVERT(NVARCHAR(20), @QueryId);
END

EXEC sys.sp_recompile N'dbo.usp_GetOrdersByCustomer';

IF NOT EXISTS (
    SELECT 1
    FROM sys.query_store_query_hints AS h
    JOIN sys.query_store_query AS q
        ON q.query_id = h.query_id
    WHERE q.object_id = OBJECT_ID(N'dbo.usp_GetOrdersByCustomer')
)
    PRINT N'usp_GetOrdersByCustomer için Query Store hint kalmadı.';
GO
