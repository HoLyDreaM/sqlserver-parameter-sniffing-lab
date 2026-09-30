/*
  SniffLab — veritabanı oluşturma
  sqlcmd: -i database/01-create-database.sql
  PSP için SQL Server 2022 ve compatibility level 160 gerekir.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) < 16
BEGIN
    RAISERROR(N'SQL Server 2022 (major 16) veya üzeri gerekir. Bu laboratuvar PSP optimizasyonunu kullanır.', 16, 1);
    RETURN;
END

IF DB_ID(N'SniffLab') IS NULL
BEGIN
    CREATE DATABASE [SniffLab];
    PRINT N'Veritabanı oluşturuldu: SniffLab';
END
ELSE
    PRINT N'Veritabanı zaten var: SniffLab';
GO

ALTER DATABASE [SniffLab] SET RECOVERY SIMPLE;
GO

ALTER DATABASE [SniffLab] SET COMPATIBILITY_LEVEL = 160;
GO

ALTER DATABASE [SniffLab] SET AUTO_CREATE_STATISTICS ON;
ALTER DATABASE [SniffLab] SET AUTO_UPDATE_STATISTICS ON;
GO

PRINT N'Compatibility level 160 ayarlandı.';
GO
