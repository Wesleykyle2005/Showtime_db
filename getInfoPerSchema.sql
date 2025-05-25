USE ShowtimeDB;

-- Generar y ejecutar SELECT * para todas las tablas en el esquema 'Operaciones'
DECLARE @SchemaName NVARCHAR(128) = 'Administracion';
DECLARE @sql NVARCHAR(MAX) = '';
DECLARE @TableName NVARCHAR(128);

-- Cursor para iterar sobre las tablas
DECLARE table_cursor CURSOR FOR
SELECT t.name
FROM sys.tables t
WHERE SCHEMA_NAME(t.schema_id) = @SchemaName;

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @TableName;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Generar SELECT * para la tabla
    SET @sql = 'SELECT ''' + @TableName + ''' AS Tabla, * FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ';';
    -- Ejecutar la consulta y mostrar resultados
    EXEC sp_executesql @sql;
    FETCH NEXT FROM table_cursor INTO @TableName;
END;

CLOSE table_cursor;
DEALLOCATE table_cursor;