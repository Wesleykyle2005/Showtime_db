USE ShowtimeDB;
GO

-- Bloque para crear los esquemas con manejo de errores
BEGIN TRY
    -- Crear esquema [Administracion]
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Administracion')
    BEGIN
        EXEC('CREATE SCHEMA [Administracion] AUTHORIZATION dbo');
        PRINT 'Esquema [Administracion] creado exitosamente.';
    END
    ELSE
    BEGIN
        PRINT 'El esquema [Administracion] ya existe. Se omite la creación.';
    END

    -- Crear esquema [Operaciones]
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Operaciones')
    BEGIN
        EXEC('CREATE SCHEMA [Operaciones] AUTHORIZATION dbo');
        PRINT 'Esquema [Operaciones] creado exitosamente.';
    END
    ELSE
    BEGIN
        PRINT 'El esquema [Operaciones] ya existe. Se omite la creación.';
    END

    -- Crear esquema [Inventario]
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Inventario')
    BEGIN
        EXEC('CREATE SCHEMA [Inventario] AUTHORIZATION dbo');
        PRINT 'Esquema [Inventario] creado exitosamente.';
    END
    ELSE
    BEGIN
        PRINT 'El esquema [Inventario] ya existe. Se omite la creación.';
    END

    -- Crear esquema [Auditoria]
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Auditoria')
    BEGIN
        EXEC('CREATE SCHEMA [Auditoria] AUTHORIZATION dbo');
        PRINT 'Esquema [Auditoria] creado exitosamente.';
    END
    ELSE
    BEGIN
        PRINT 'El esquema [Auditoria] ya existe. Se omite la creación.';
    END
END TRY
BEGIN CATCH
    -- Capturar y reportar cualquier error durante la creación de esquemas
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();

    PRINT 'Error al crear los esquemas: ' + @ErrorMessage;
    RAISERROR ('Fallo en la creación de esquemas con severidad %d y estado %d', 16, 1, @ErrorSeverity, @ErrorState);
END CATCH;
GO