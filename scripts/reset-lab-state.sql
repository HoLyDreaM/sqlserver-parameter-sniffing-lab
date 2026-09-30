/*
  Laboratuvar durumunu sıfırlar.
  Veriyi silmez. PSP'yi kapatır, temel prosedürün Query Store hint'lerini temizler,
  prosedürleri yeniden derleme için işaretler.
  sp_recompile yalnız bu veritabanındaki lab prosedürlerini etkiler.
*/
USE [SniffLab];
GO

SET NOCOUNT ON;

EXEC dbo.usp_ConfigurePsp @Enabled = 0;
GO

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

PRINT N'Lab durumu sıfırlandı: PSP OFF, temel prosedür hint''siz.';
GO
