USE ShowtimeDB;

-- Verificar que estamos en SQL Server
IF @@VERSION NOT LIKE '%Microsoft SQL Server%'
BEGIN
    RAISERROR ('Este script está diseñado para Microsoft SQL Server. Verifica tu sistema de base de datos.', 16, 1);
    RETURN;
END;

-- Desactivar restricciones de claves foráneas para evitar errores al eliminar tablas
EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL';

-- Paso 1: Eliminar todas las tablas
DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql += 'DROP TABLE ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name) + '; '
FROM sys.tables t
JOIN sys.objects o ON t.object_id = o.object_id;
IF @sql <> '' EXEC sp_executesql @sql;

-- Paso 2: Eliminar todas las vistas
SET @sql = '';
SELECT @sql += 'DROP VIEW ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name) + '; '
FROM sys.views v
JOIN sys.objects o ON v.object_id = o.object_id;
IF @sql <> '' EXEC sp_executesql @sql;

-- Paso 3: Eliminar todas las funciones
SET @sql = '';
SELECT @sql += 'DROP FUNCTION ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name) + '; '
FROM sys.objects o
WHERE o.type IN ('FN', 'IF', 'TF'); -- FN: escalar, IF: tabla en línea, TF: tabla
IF @sql <> '' EXEC sp_executesql @sql;

-- Paso 4: Eliminar todos los procedimientos almacenados
SET @sql = '';
SELECT @sql += 'DROP PROCEDURE ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name) + '; '
FROM sys.procedures p
JOIN sys.objects o ON p.object_id = o.object_id;
IF @sql <> '' EXEC sp_executesql @sql;

-- Paso 5: Eliminar todos los triggers
SET @sql = '';
SELECT @sql += 'DROP TRIGGER ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name) + '; '
FROM sys.triggers tr
JOIN sys.objects o ON tr.object_id = o.object_id;
IF @sql <> '' EXEC sp_executesql @sql;

-- Paso 6: Eliminar tipos de datos definidos por el usuario
SET @sql = '';
SELECT @sql += 'DROP TYPE ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + '; '
FROM sys.schemas s
JOIN sys.types t ON s.schema_id = t.schema_id
WHERE s.name NOT IN ('dbo', 'sys', 'INFORMATION_SCHEMA', 'guest', 'db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin', 'db_backupoperator', 'db_datareader', 'db_datawriter', 'db_denydatareader', 'db_denydatawriter')
  AND t.is_user_defined = 1;
IF @sql <> '' EXEC sp_executesql @sql;

-- Paso 7: Eliminar permisos asociados a esquemas personalizados
SET @sql = '';
SELECT @sql += 'REVOKE ' + p.permission_name + ' ON SCHEMA::' + QUOTENAME(s.name) + ' FROM ' + QUOTENAME(pr.name) + '; '
FROM sys.schemas s
JOIN sys.database_permissions p ON s.schema_id = p.major_id
JOIN sys.database_principals pr ON p.grantee_principal_id = pr.principal_id
WHERE s.name NOT IN ('dbo', 'sys', 'INFORMATION_SCHEMA', 'guest', 'db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin', 'db_backupoperator', 'db_datareader', 'db_datawriter', 'db_denydatareader', 'db_denydatawriter');
IF @sql <> '' EXEC sp_executesql @sql;

-- Paso 8: Listar esquemas personalizados restantes antes de eliminarlos (para diagnóstico)
SELECT name AS Esquema
FROM sys.schemas
WHERE name NOT IN ('dbo', 'sys', 'INFORMATION_SCHEMA', 'guest', 'db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin', 'db_backupoperator', 'db_datareader', 'db_datawriter', 'db_denydatareader', 'db_denydatawriter')
ORDER BY name;

-- Paso 9: Verificar objetos residuales asociados a esquemas personalizados
SELECT 
    s.name AS Esquema,
    o.name AS NombreObjeto,
    o.type_desc AS TipoObjeto
FROM sys.schemas s
LEFT JOIN sys.objects o ON s.schema_id = o.schema_id
WHERE s.name NOT IN ('dbo', 'sys', 'INFORMATION_SCHEMA', 'guest', 'db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin', 'db_backupoperator', 'db_datareader', 'db_datawriter', 'db_denydatareader', 'db_denydatawriter')
  AND o.object_id IS NOT NULL
UNION ALL
SELECT 
    s.name AS Esquema,
    t.name AS NombreObjeto,
    'USER_DEFINED_TYPE' AS TipoObjeto
FROM sys.schemas s
LEFT JOIN sys.types t ON s.schema_id = t.schema_id
WHERE s.name NOT IN ('dbo', 'sys', 'INFORMATION_SCHEMA', 'guest', 'db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin', 'db_backupoperator', 'db_datareader', 'db_datawriter', 'db_denydatareader', 'db_denydatawriter')
  AND t.is_user_defined = 1;

-- Paso 10: Eliminar esquemas personalizados
SET @sql = '';
SELECT @sql += 'DROP SCHEMA ' + QUOTENAME(name) + '; '
FROM sys.schemas
WHERE name NOT IN ('dbo', 'sys', 'INFORMATION_SCHEMA', 'guest', 'db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin', 'db_backupoperator', 'db_datareader', 'db_datawriter', 'db_denydatareader', 'db_denydatawriter');
IF @sql <> '' EXEC sp_executesql @sql;

-- Paso 11: Confirmar que no quedan objetos
SELECT 'Tablas restantes: ' + CAST(COUNT(*) AS NVARCHAR) AS Estado FROM sys.tables
UNION ALL
SELECT 'Vistas restantes: ' + CAST(COUNT(*) AS NVARCHAR) FROM sys.views
UNION ALL
SELECT 'Funciones restantes: ' + CAST(COUNT(*) AS NVARCHAR) FROM sys.objects WHERE type IN ('FN', 'IF', 'TF')
UNION ALL
SELECT 'Procedimientos restantes: ' + CAST(COUNT(*) AS NVARCHAR) FROM sys.procedures
UNION ALL
SELECT 'Triggers restantes: ' + CAST(COUNT(*) AS NVARCHAR) FROM sys.triggers
UNION ALL
SELECT 'Tipos de datos definidos por el usuario restantes: ' + CAST(COUNT(*) AS NVARCHAR) FROM sys.types WHERE is_user_defined = 1
UNION ALL
SELECT 'Esquemas personalizados restantes: ' + CAST(COUNT(*) AS NVARCHAR) FROM sys.schemas WHERE name NOT IN ('dbo', 'sys', 'INFORMATION_SCHEMA', 'guest', 'db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin', 'db_backupoperator', 'db_datareader', 'db_datawriter', 'db_denydatareader', 'db_denydatawriter');

-- Reactivar restricciones (redundante tras eliminar tablas, pero incluido por completitud)
EXEC sp_MSforeachtable 'ALTER TABLE ? CHECK CONSTRAINT ALL';