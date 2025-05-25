USE ShowtimeDB;
GO

-- Limpieza inicial (opcional, descomentar si se desea borrar datos previos)
/*
DELETE FROM Operaciones.Pagos;
DELETE FROM Operaciones.Evento_Servicios;
DELETE FROM Operaciones.Paquete_Servicios;
DELETE FROM Operaciones.Eventos;
DELETE FROM Operaciones.Paquetes;
DELETE FROM Operaciones.Servicios;
DELETE FROM Operaciones.Clientes;
DELETE FROM Administracion.Usuarios;
DELETE FROM Administracion.Empleados;
DELETE FROM Administracion.Cargos;
DELETE FROM Administracion.Roles;
DELETE FROM Administracion.Estado_Empleado;
GO
*/

-- 1. Pruebas para Estado_Empleado (necesario para Empleados)
-- Insertar un estado si no existe
IF NOT EXISTS (SELECT 1 FROM Administracion.Estado_Empleado WHERE Tipo_estado = 'Activo')
BEGIN
    INSERT INTO Administracion.Estado_Empleado (Tipo_estado)
    VALUES ('Activo');
END
GO

-- 2. Pruebas para Cargos
-- AddCargo
EXEC Administracion.AddCargo 
    @Nombre_cargo = 'Administrador', 
    @Descripción = 'Responsable de la gestión del sistema';
GO

-- Obtener Id_cargo dinámicamente y usar en el mismo lote
DECLARE @Id_cargo INT;
SELECT @Id_cargo = Id_cargo 
FROM Administracion.Cargos 
WHERE Nombre_cargo = 'Administrador';

-- GetCargos
EXEC Administracion.GetCargos 
    @PageNumber = 1, 
    @PageSize = 5, 
    @TextFilter = 'Admin';
GO

-- 3. Pruebas para Roles
-- AddRol
EXEC Administracion.AddRol 
    @Nombre_rol = 'Coordinador de Eventos', 
    @Descripcion = 'Organiza y supervisa eventos';
GO

-- Obtener Id_rol dinámicamente y usar en el mismo lote
DECLARE @Id_rol INT;
SELECT @Id_rol = Id_rol 
FROM Administracion.Roles 
WHERE Nombre_rol = 'Coordinador de Eventos';

-- GetRoles
EXEC Administracion.GetRoles 
    @PageNumber = 1, 
    @PageSize = 5, 
    @TextFilter = 'Coordinador';
GO

-- 4. Pruebas para Empleados (incluye creación de usuario)
-- Obtener Id_estado dinámicamente
DECLARE @Id_estado INT;
SELECT @Id_estado = Id_estado 
FROM Administracion.Estado_Empleado 
WHERE Tipo_estado = 'Activo';

-- Obtener Id_cargo dinámicamente
DECLARE @Id_cargo_empleado INT;
SELECT @Id_cargo_empleado = Id_cargo 
FROM Administracion.Cargos 
WHERE Nombre_cargo = 'Administrador';

-- AddEmpleado
EXEC Administracion.AddEmpleado 
    @Nombre = 'Ana', 
    @Apellido = 'Gómez', 
    @Telefono = '1234567890', 
    @Email = 'ana.gomez@example.com', 
    @Estado_Empleado = @Id_estado, 
    @Nombre_usuario = 'anagomez', 
    @Contraseña = 'SecurePass123', 
    @Id_Cargo = @Id_cargo_empleado;

-- Obtener Id_empleado dinámicamente
DECLARE @Id_empleado INT;
SELECT @Id_empleado = Id_empleado 
FROM Administracion.Empleados 
WHERE Email = 'ana.gomez@example.com';

-- GetEmpleados
EXEC Administracion.GetEmpleados 
    @PageNumber = 1, 
    @PageSize = 5, 
    @TextFilter = 'Ana';
GO


-- Declarar variables para generar el correo único
DECLARE @BaseEmail VARCHAR(100) = 'carlos.lo2pez@example.com';
DECLARE @RandomSuffix INT;
DECLARE @NewEmail VARCHAR(100);
DECLARE @Attempts INT = 0;
DECLARE @MaxAttempts INT = 10; -- Límite de intentos para evitar bucle infinito

-- Generar un correo único
WHILE @Attempts < @MaxAttempts
BEGIN
    -- Generar un número aleatorio entre 1 y 1000
    SET @RandomSuffix = FLOOR(RAND() * 1000) + 1;
    
    -- Construir el correo concatenando el sufijo aleatorio
    SET @NewEmail = CONCAT(LEFT(@BaseEmail, CHARINDEX('@', @BaseEmail) - 1), 
                           '_', 
                           @RandomSuffix, 
                           RIGHT(@BaseEmail, LEN(@BaseEmail) - CHARINDEX('@', @BaseEmail) + 1));

    -- Verificar si el correo ya existe
    IF NOT EXISTS (SELECT 1 FROM Operaciones.Clientes WHERE Correo_electronico = @NewEmail)
        BREAK; -- Salir del bucle si el correo es único

    SET @Attempts = @Attempts + 1;

    -- Si se alcanza el máximo de intentos, lanzar un error
    IF @Attempts >= @MaxAttempts
        THROW 50001, 'No se pudo generar un correo electrónico único después de varios intentos.', 1;
END

-- Ejecutar AddCliente con el correo único generado
BEGIN TRY
    EXEC Operaciones.AddCliente 
        @Nombre = 'Carlos', 
        @Apellido = 'López', 
        @Telefono = '9876542220', 
        @Correo_electronico = @NewEmail;

    -- Mostrar el correo generado para confirmar
    SELECT @NewEmail AS CorreoGenerado;
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    THROW 50000, @ErrorMessage, @ErrorState;
END CATCH
GO

-- Obtener Id_cliente dinámicamente
DECLARE @Id_cliente INT;
SELECT @Id_cliente = Id_cliente 
FROM Operaciones.Clientes 
WHERE Correo_electronico = 'carlos.lopez@example.com';

-- GetClientes
EXEC Operaciones.GetClientes 
    @PageNumber = 1, 
    @PageSize = 5, 
    @TextFilter = 'Carlos';
GO

-- 6. Pruebas para Servicios
-- AddServicio (primer servicio)
EXEC Operaciones.AddServicio 
    @Nombre_servicio = 'Show de Payasos', 
    @Descripcion = 'Entretenimiento con payasos y malabares', 
    @Costo = 200.00, 
    @UtileriaIds = NULL;

-- Obtener Id_servicio1 dinámicamente
DECLARE @Id_servicio1 INT;
SELECT @Id_servicio1 = Id_servicio 
FROM Operaciones.Servicios 
WHERE Nombre_servicio = 'Show de Payasos';

-- AddServicio (segundo servicio)
EXEC Operaciones.AddServicio 
    @Nombre_servicio = 'Decoración Temática', 
    @Descripcion = 'Decoración personalizada para eventos', 
    @Costo = 150.00, 
    @UtileriaIds = NULL;

-- Obtener Id_servicio2 dinámicamente
DECLARE @Id_servicio2 INT;
SELECT @Id_servicio2 = Id_servicio 
FROM Operaciones.Servicios 
WHERE Nombre_servicio = 'Decoración Temática';

-- GetServicios
EXEC Operaciones.GetServicios 
    @PageNumber = 1, 
    @PageSize = 5, 
    @TextFilter = 'Payasos';
GO

-- 7. Pruebas para Paquetes
-- Obtener Ids de servicios dinámicamente
DECLARE @Id_servicio1_paquete INT;
DECLARE @Id_servicio2_paquete INT;
SELECT @Id_servicio1_paquete = Id_servicio 
FROM Operaciones.Servicios 
WHERE Nombre_servicio = 'Show de Payasos';
SELECT @Id_servicio2_paquete = Id_servicio 
FROM Operaciones.Servicios 
WHERE Nombre_servicio = 'Decoración Temática';

-- Construir ServicioIds dinámicamente
DECLARE @ServicioIds NVARCHAR(MAX) = CAST(@Id_servicio1_paquete AS NVARCHAR(10)) + ',' + CAST(@Id_servicio2_paquete AS NVARCHAR(10));

-- AddPaquete
EXEC Operaciones.AddPaquete 
    @Nombre_paquete = 'Fiesta Infantil Deluxe', 
    @Descripcion = 'Incluye show y decoración', 
    @Cantidad = 5, 
    @Disponibilidad = 1, 
    @Costo = 500.00, 
    @ServicioIds = @ServicioIds;

-- Obtener Id_paquete dinámicamente
DECLARE @Id_paquete INT;
SELECT @Id_paquete = Id_paquete 
FROM Operaciones.Paquetes 
WHERE Nombre_paquete = 'Fiesta Infantil Deluxe';

-- GetPaquetes
EXEC Operaciones.GetPaquetes 
    @PageNumber = 1, 
    @PageSize = 5, 
    @TextFilter = 'Deluxe';
GO

-- 8. Pruebas para Eventos
-- Obtener Id_cliente y ServicioIds dinámicamente
DECLARE @Id_cliente_evento INT;
SELECT @Id_cliente_evento = Id_cliente 
FROM Operaciones.Clientes 
WHERE Correo_electronico = 'carlos.lopez@example.com';

DECLARE @Id_servicio1_evento INT;
DECLARE @Id_servicio2_evento INT;
SELECT @Id_servicio1_evento = Id_servicio 
FROM Operaciones.Servicios 
WHERE Nombre_servicio = 'Show de Payasos';
SELECT @Id_servicio2_evento = Id_servicio 
FROM Operaciones.Servicios 
WHERE Nombre_servicio = 'Decoración Temática';
DECLARE @ServicioIds_evento NVARCHAR(MAX) = CAST(@Id_servicio1_evento AS NVARCHAR(10)) + ',' + CAST(@Id_servicio2_evento AS NVARCHAR(10));

-- Obtener Id_paquete dinámicamente
DECLARE @Id_paquete_evento INT;
SELECT @Id_paquete_evento = Id_paquete 
FROM Operaciones.Paquetes 
WHERE Nombre_paquete = 'Fiesta Infantil Deluxe';

-- AddEvento
EXEC Operaciones.AddEvento 
    @Id_paquete = @Id_paquete_evento, 
    @Id_cliente = @Id_cliente_evento, 
    @Fecha_reserva = '2025-05-15', 
    @Fecha_inicio = '2025-05-20', 
    @Hora_inicio = '14:00', 
    @Hora_fin = '17:00', 
    @Ubicacion = 'Salón Fiesta', 
    @Direccion = 'Calle 123, Ciudad', 
    @Cantidad_de_asistentes = 50, 
    @Detalles_adicionales = 'Temática de superhéroes', 
    @Costo_total = 600.00, 
    @Estado = 'Pendiente', 
    @ServicioIds = @ServicioIds_evento;

-- Obtener Id_evento dinámicamente
DECLARE @Id_evento INT;
SELECT @Id_evento = Id_evento 
FROM Operaciones.Eventos 
WHERE Id_cliente = @Id_cliente_evento AND Fecha_inicio = '2025-05-20';

-- GetEventos
EXEC Operaciones.GetEventos 
    @PageNumber = 1, 
    @PageSize = 5, 
    @TextFilter = 'Salón', 
    @Estado = 'Pendiente';
GO

-- 9. Pruebas para Pagos
-- Obtener Id_evento dinámicamente
DECLARE @Id_evento_pago INT;
DECLARE @Id_cliente_pago INT;
SELECT @Id_cliente_pago = Id_cliente 
FROM Operaciones.Clientes 
WHERE Correo_electronico = 'carlos.lopez@example.com';
SELECT @Id_evento_pago = Id_evento 
FROM Operaciones.Eventos 
WHERE Id_cliente = @Id_cliente_pago AND Fecha_inicio = '2025-05-20';

-- GetPagos
EXEC Operaciones.GetPagos 
    @PageNumber = 1, 
    @PageSize = 5, 
    @Id_evento = @Id_evento_pago;
GO


-- AddPago (primer pago, no excede el costo del evento)
EXEC Operaciones.AddPago 
    @Id_evento = @Id_evento_pago, 
    @Monto = 300.00, 
    @Fecha_pago = '2025-05-16', 
    @Metodo_pago = 'Tarjeta';

-- AddPago (segundo pago, no excede el costo restante)
EXEC Operaciones.AddPago 
    @Id_evento = @Id_evento_pago, 
    @Monto = 200.00, 
    @Fecha_pago = '2025-05-17', 
    @Metodo_pago = 'Efectivo';

-- AddPago (prueba de error: excede el costo del evento)
EXEC Operaciones.AddPago 
    @Id_evento = @Id_evento_pago, 
    @Monto = 200.00, 
    @Fecha_pago = '2025-05-18', 
    @Metodo_pago = 'Tarjeta';

