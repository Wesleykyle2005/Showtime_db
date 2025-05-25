USE MASTER;

-- Habilitar xp_cmdshell
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

BEGIN TRY
    -- Crear la base de datos
    CREATE DATABASE ShowtimeDB;
    SELECT * FROM sys.databases WHERE name = 'ShowtimeDB';

    EXEC sp_helpfile;

    -- Agregar un filegroup
    ALTER DATABASE ShowtimeDB ADD FILEGROUP ShowtimeDBDATA;

    -- Crear la carpeta C:\storage\data_disk si no existe
    DECLARE @DataFolderPath VARCHAR(255) = 'C:\storage\data_disk';
    DECLARE @CommandData VARCHAR(500) = 'IF NOT EXIST "' + @DataFolderPath + '" mkdir "' + @DataFolderPath + '"';
    EXEC xp_cmdshell @CommandData;

    -- Agregar el archivo de datos al filegroup
    ALTER DATABASE ShowtimeDB ADD FILE (
        NAME = ShowtimeDBData,
        FILENAME = 'C:\storage\data_disk\ShowtimeDBData.mdf'
    ) TO FILEGROUP ShowtimeDBDATA;

    -- Crear la carpeta C:\storage\logs_disk si no existe
    DECLARE @LogsFolderPath VARCHAR(255) = 'C:\storage\logs_disk';
    DECLARE @CommandLogs VARCHAR(500) = 'IF NOT EXIST "' + @LogsFolderPath + '" mkdir "' + @LogsFolderPath + '"';
    EXEC xp_cmdshell @CommandLogs;

    -- Agregar el archivo de logs
    ALTER DATABASE ShowtimeDB ADD LOG FILE (
        NAME = ShowtimeDBLogs,
        FILENAME = 'C:\storage\logs_disk\ShowtimeDBLogs.ldf'
    );

    PRINT 'Base de datos y carpetas creadas exitosamente.';
END TRY
BEGIN CATCH
    PRINT 'Error: ' + ERROR_MESSAGE();
    -- Deshabilitar xp_cmdshell incluso si hay un error
    EXEC sp_configure 'xp_cmdshell', 0;
    RECONFIGURE;
    EXEC sp_configure 'show advanced options', 0;
    RECONFIGURE;
    RETURN;
END CATCH;

-- Deshabilitar xp_cmdshell
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;

RETURN;