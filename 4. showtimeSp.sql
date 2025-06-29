--USE ShowtimeDB;
--GO
CREATE OR ALTER PROCEDURE Operaciones.AddCliente
(
    @Nombre VARCHAR(100),
    @Apellido VARCHAR(100),
    @Telefono VARCHAR(20),
    @Correo_electronico VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate inputs
        IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
            THROW 50001, 'El nombre del cliente es requerido.', 1;
        IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
            THROW 50002, 'El apellido del cliente es requerido.', 1;
        IF @Telefono IS NULL OR LTRIM(RTRIM(@Telefono)) = ''
            THROW 50003, 'El tel�fono del cliente es requerido.', 1;
        IF @Correo_electronico IS NOT NULL AND EXISTS (SELECT 1 FROM Operaciones.Clientes WHERE Correo_electronico = @Correo_electronico)
            THROW 50004, 'El correo electr�nico ya est� registrado.', 1;
        IF EXISTS (SELECT 1 FROM Operaciones.Clientes WHERE Telefono = @Telefono)
            THROW 50005, 'El tel�fono ya est� registrado.', 1;

		IF @Correo_electronico IS NOT NULL AND 
           @Correo_electronico NOT LIKE '_%@_%._%'
            THROW 50006, 'El formato del correo electr�nico no es v�lido.', 1;


        -- Insert client
        INSERT INTO Operaciones.Clientes (Nombre, Apellido, Telefono, Correo_electronico)
        VALUES (@Nombre, @Apellido, @Telefono, @Correo_electronico);

        SELECT Id_cliente, Nombre, Apellido, Telefono, Correo_electronico
        FROM Operaciones.Clientes
        WHERE Id_cliente = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO


--------------------------------------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE Operaciones.GetClientes
(
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TextFilter NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate pagination parameters
        IF @PageNumber < 1
            THROW 50006, 'El n�mero de p�gina debe ser mayor o igual a 1.', 1;
        IF @PageSize < 1
            THROW 50007, 'El tama�o de p�gina debe ser mayor o igual a 1.', 1;

        -- Retrieve paginated clients
        SELECT 
            Id_cliente,
            Nombre,
            Apellido,
            Telefono,
            Correo_electronico
        FROM Operaciones.Clientes
        WHERE (@TextFilter IS NULL OR 
               Nombre LIKE '%' + @TextFilter + '%' OR 
               Apellido LIKE '%' + @TextFilter + '%')
        ORDER BY Id_cliente ASC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

--------------------------------------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE Operaciones.AddPaquete
(
    @Nombre_paquete VARCHAR(100),
    @Descripcion VARCHAR(MAX) = NULL,
    @Cantidad INT = NULL,
    @Disponibilidad BIT,
    @Costo DECIMAL(18, 2),
    @ServicioIds NVARCHAR(MAX) = NULL -- Comma-separated list of service IDs
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate inputs
        IF @Nombre_paquete IS NULL OR LTRIM(RTRIM(@Nombre_paquete)) = ''
            THROW 50008, 'El nombre del paquete es requerido.', 1;
        IF @Costo <= 0
            THROW 50009, 'El costo del paquete debe ser mayor a 0.', 1;
        IF @Cantidad IS NOT NULL AND @Cantidad < 0
            THROW 50010, 'La cantidad no puede ser negativa.', 1;

        -- Insert package
        INSERT INTO Operaciones.Paquetes (Nombre_paquete, Descripcion, Cantidad, Disponibilidad, Costo)
        VALUES (@Nombre_paquete, @Descripcion, @Cantidad, @Disponibilidad, @Costo);

        DECLARE @Id_paquete INT = SCOPE_IDENTITY();

        -- Insert related services if provided
        IF @ServicioIds IS NOT NULL AND LTRIM(RTRIM(@ServicioIds)) != ''
        BEGIN
            INSERT INTO Operaciones.Paquete_Servicios (Id_paquete, Id_servicio)
            SELECT @Id_paquete, CAST(value AS INT)
            FROM STRING_SPLIT(@ServicioIds, ',')
            WHERE EXISTS (SELECT 1 FROM Operaciones.Servicios WHERE Id_servicio = CAST(value AS INT));
        END;

        COMMIT TRANSACTION;

        SELECT Id_paquete, Nombre_paquete, Descripcion, Cantidad, Disponibilidad, Costo
        FROM Operaciones.Paquetes
        WHERE Id_paquete = @Id_paquete;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

--------------------------------------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE Operaciones.GetPaquetes
(
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TextFilter NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate pagination parameters
        IF @PageNumber < 1
            THROW 50011, 'El número de página debe ser mayor o igual a 1.', 1;
        IF @PageSize < 1
            THROW 50012, 'El tamaño de página debe ser mayor o igual a 1.', 1;

        -- Retrieve paginated packages with servicios asociados en JSON
        SELECT 
            p.Id_paquete,
            p.Nombre_paquete,
            p.Descripcion,
            p.Cantidad,
            p.Disponibilidad,
            p.Costo,
            (
                SELECT 
                    s.Id_servicio,
                    s.Nombre_servicio,
                    s.Descripcion,
                    s.Costo
                FROM Operaciones.Paquete_Servicios ps
                INNER JOIN Operaciones.Servicios s ON ps.Id_servicio = s.Id_servicio
                WHERE ps.Id_paquete = p.Id_paquete
                FOR JSON PATH
            ) AS ServiciosJson
        FROM Operaciones.Paquetes p
        WHERE p.Disponibilidad = 1
          AND (@TextFilter IS NULL OR p.Nombre_paquete LIKE '%' + @TextFilter + '%')
        ORDER BY p.Id_paquete ASC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

--------------------------------------------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE Operaciones.AddEvento
(
    @Id_paquete INT = NULL,
    @Id_cliente INT,
    @Fecha_reserva DATE,
    @Fecha_inicio DATE,
    @Hora_inicio TIME,
    @Hora_fin TIME,
    @Ubicacion VARCHAR(255),
    @Direccion VARCHAR(MAX),
    @Cantidad_de_asistentes INT,
    @Detalles_adicionales VARCHAR(MAX) = NULL,
    @Costo_total DECIMAL(18, 2),
    @Estado VARCHAR(20) = 'Pendiente',
    @ServicioIds NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate inputs
        IF @Id_cliente IS NULL OR NOT EXISTS (SELECT 1 FROM Operaciones.Clientes WHERE Id_cliente = @Id_cliente)
            THROW 50013, 'El cliente especificado no existe.', 1;
        IF @Id_paquete IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Operaciones.Paquetes WHERE Id_paquete = @Id_paquete)
            THROW 50014, 'El paquete especificado no existe.', 1;
        IF @Fecha_reserva IS NULL OR @Fecha_inicio IS NULL
            THROW 50015, 'La fecha de reserva y la fecha de inicio son requeridas.', 1;
        IF @Hora_inicio IS NULL OR @Hora_fin IS NULL
            THROW 50016, 'La hora de inicio y fin son requeridas.', 1;
        IF @Fecha_inicio <= @Fecha_reserva OR @Hora_fin <= @Hora_inicio
            THROW 50017, 'La fecha de inicio debe ser posterior a la reserva y la hora de fin posterior a la de inicio.', 1;
        IF @Ubicacion IS NULL OR LTRIM(RTRIM(@Ubicacion)) = ''
            THROW 50018, 'La ubicaci�n es requerida.', 1;
        IF @Direccion IS NULL OR LTRIM(RTRIM(@Direccion)) = ''
            THROW 50019, 'La direcci�n es requerida.', 1;
        IF @Cantidad_de_asistentes <= 0
            THROW 50020, 'La cantidad de asistentes debe ser mayor a 0.', 1;
        IF @Costo_total <= 0
            THROW 50021, 'El costo total debe ser mayor a 0.', 1;
        IF @Estado NOT IN ('Pendiente', 'Reservado', 'Finalizado', 'Cancelado', 'Incompleto')
            THROW 50022, 'Estado inv�lido.', 1;

        -- Insert event
        INSERT INTO Operaciones.Eventos (
            Id_paquete, Id_cliente, Fecha_reserva, Fecha_inicio, Hora_inicio, Hora_fin,
            Ubicacion, Direccion, Cantidad_de_asistentes, Detalles_adicionales, Costo_total, Estado
        )
        VALUES (
            @Id_paquete, @Id_cliente, @Fecha_reserva, @Fecha_inicio, @Hora_inicio, @Hora_fin,
            @Ubicacion, @Direccion, @Cantidad_de_asistentes, @Detalles_adicionales, @Costo_total, @Estado
        );

        DECLARE @Id_evento INT = SCOPE_IDENTITY();

        -- Insert related services if provided
        IF @ServicioIds IS NOT NULL AND LTRIM(RTRIM(@ServicioIds)) != ''
        BEGIN
            INSERT INTO Operaciones.Evento_Servicios (Id_evento, Id_servicio)
            SELECT @Id_evento, CAST(value AS INT)
            FROM STRING_SPLIT(@ServicioIds, ',')
            WHERE EXISTS (SELECT 1 FROM Operaciones.Servicios WHERE Id_servicio = CAST(value AS INT));
        END;

        COMMIT TRANSACTION;

        SELECT Id_evento, Id_paquete, Id_cliente, Fecha_reserva, Fecha_inicio, Hora_inicio, Hora_fin,
               Ubicacion, Direccion, Cantidad_de_asistentes, Detalles_adicionales, Costo_total, Estado
        FROM Operaciones.Eventos
        WHERE Id_evento = @Id_evento;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO


CREATE OR ALTER PROCEDURE Operaciones.GetEventos
(
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TextFilter NVARCHAR(100) = NULL,
    @Estado VARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validar paginación y estado
        IF @PageNumber < 1
            THROW 50023, 'El número de página debe ser mayor o igual a 1.', 1;
        IF @PageSize < 1
            THROW 50024, 'El tamaño de página debe ser mayor o igual a 1.', 1;
        IF @Estado IS NOT NULL AND @Estado NOT IN ('Pendiente', 'Reservado', 'Finalizado', 'Cancelado', 'Incompleto')
            THROW 50025, 'Estado inválido.', 1;

        -- Traer eventos con servicios asociados como JSON y información de pagos
        SELECT 
            e.Id_evento,
            e.Id_paquete,
            e.Id_cliente,	
            c.Nombre AS Nombre_cliente,
            c.Apellido AS Apellido_cliente,
            e.Fecha_reserva,
            e.Fecha_inicio,
            e.Hora_inicio,
            e.Hora_fin,
            e.Ubicacion,
            e.Direccion,
            e.Cantidad_de_asistentes,
            e.Detalles_adicionales,
            e.Costo_total,
            e.Estado,
            -- Información de pagos usando la función
            pr.PagoRestante,
            pr.PorcentajePagado,
            -- Subconsulta para traer los servicios asociados como JSON
            (
                SELECT 
                    s.Id_servicio,
                    s.Nombre_servicio
                FROM Operaciones.Evento_Servicios es
                INNER JOIN Operaciones.Servicios s ON es.Id_servicio = s.Id_servicio
                WHERE es.Id_evento = e.Id_evento
                FOR JSON PATH
            ) AS ServiciosJson
        FROM Operaciones.Eventos e
        JOIN Operaciones.Clientes c ON e.Id_cliente = c.Id_cliente
        CROSS APPLY dbo.CalcularPagoRestante(e.Id_evento) pr
        WHERE (@TextFilter IS NULL OR 
               c.Nombre LIKE '%' + @TextFilter + '%' OR 
               c.Apellido LIKE '%' + @TextFilter + '%' OR 
               e.Ubicacion LIKE '%' + @TextFilter + '%')
          AND (@Estado IS NULL OR e.Estado = @Estado)
        ORDER BY e.Fecha_reserva DESC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-------

CREATE OR ALTER PROCEDURE Operaciones.AddServicio
(
    @Nombre_servicio VARCHAR(100),
    @Descripcion VARCHAR(MAX) = NULL,
    @Costo DECIMAL(18, 2),
    @UtileriaIds NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate inputs
        IF @Nombre_servicio IS NULL OR LTRIM(RTRIM(@Nombre_servicio)) = ''
            THROW 50026, 'El nombre del servicio es requerido.', 1;
        IF @Costo <= 0
            THROW 50027, 'El costo del servicio debe ser mayor a 0.', 1;

        -- Insert service
        INSERT INTO Operaciones.Servicios (Nombre_servicio, Descripcion, Costo)
        VALUES (@Nombre_servicio, @Descripcion, @Costo);

        DECLARE @Id_servicio INT = SCOPE_IDENTITY();

        -- Insert related props if provided
        IF @UtileriaIds IS NOT NULL AND LTRIM(RTRIM(@UtileriaIds)) != ''
        BEGIN
            INSERT INTO Inventario.Servicio_Utileria (Id_servicio, Id_utileria)
            SELECT @Id_servicio, CAST(value AS INT)
            FROM STRING_SPLIT(@UtileriaIds, ',')
            WHERE EXISTS (SELECT 1 FROM Inventario.Utileria WHERE Id_utileria = CAST(value AS INT));
        END;

        COMMIT TRANSACTION;

        SELECT Id_servicio, Nombre_servicio, Descripcion, Costo
        FROM Operaciones.Servicios
        WHERE Id_servicio = @Id_servicio;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-------
CREATE OR ALTER PROCEDURE Operaciones.GetServicios
(
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TextFilter NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate pagination parameters
        IF @PageNumber < 1
            THROW 50028, 'El número de página debe ser mayor o igual a 1.', 1;
        IF @PageSize < 1
            THROW 50029, 'El tamaño de página debe ser mayor o igual a 1.', 1;

        -- Retrieve paginated services with utilerías asociadas en JSON
        SELECT 
            s.Id_servicio,
            s.Nombre_servicio,
            s.Descripcion,
            s.Costo,
            (
                SELECT 
                    u.Id_utileria,
                    u.Nombre,
                    u.Cantidad
                FROM Inventario.Servicio_Utileria su
                INNER JOIN Inventario.Utileria u ON su.Id_utileria = u.Id_utileria
                WHERE su.Id_servicio = s.Id_servicio
                FOR JSON PATH
            ) AS UtileriasJson
        FROM Operaciones.Servicios s
        WHERE (@TextFilter IS NULL OR s.Nombre_servicio LIKE '%' + @TextFilter + '%')
        ORDER BY s.Id_servicio ASC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO


----



--////////////////////////////////////////////////////?
CREATE OR ALTER PROCEDURE Operaciones.AddPago
(
    @Id_evento INT,
    @Monto DECIMAL(18, 2),
    @Fecha_pago DATE,
    @Metodo_pago VARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate inputs
        IF @Id_evento IS NULL OR NOT EXISTS (SELECT 1 FROM Operaciones.Eventos WHERE Id_evento = @Id_evento)
            THROW 50030, 'El evento especificado no existe.', 1;
        IF @Monto <= 0
            THROW 50031, 'El monto del pago debe ser mayor a 0.', 1;
        IF @Fecha_pago IS NULL
            THROW 50032, 'La fecha de pago es requerida.', 1;
        IF @Metodo_pago IS NULL OR LTRIM(RTRIM(@Metodo_pago)) = ''
            THROW 50033, 'El m�todo de pago es requerido.', 1;

        -- Validate payment against event cost
        DECLARE @Costo_total DECIMAL(18, 2);
        DECLARE @Total_pagado DECIMAL(18, 2);

        -- Get event total cost
        SELECT @Costo_total = Costo_total
        FROM Operaciones.Eventos
        WHERE Id_evento = @Id_evento;

        -- Get sum of previous payments
        SELECT @Total_pagado = ISNULL(SUM(Monto), 0)
        FROM Operaciones.Pagos
        WHERE Id_evento = @Id_evento;

        -- Check if new payment exceeds remaining balance
        IF (@Total_pagado + @Monto) > @Costo_total
            THROW 50034, 'El monto del pago excede el costo total pendiente del evento.', 1;

        -- Insert payment
        INSERT INTO Operaciones.Pagos (Id_evento, Monto, Fecha_pago, Metodo_pago)
        VALUES (@Id_evento, @Monto, @Fecha_pago, @Metodo_pago);

        COMMIT TRANSACTION;

        SELECT Id_pago, Id_evento, Monto, Fecha_pago, Metodo_pago
        FROM Operaciones.Pagos
        WHERE Id_pago = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO


-----



CREATE OR ALTER PROCEDURE Operaciones.GetPagos
(
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @Id_evento INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate pagination parameters
        IF @PageNumber < 1
            THROW 50034, 'El n�mero de p�gina debe ser mayor o igual a 1.', 1;
        IF @PageSize < 1
            THROW 50035, 'El tama�o de p�gina debe ser mayor o igual a 1.', 1;
        IF @Id_evento IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Operaciones.Eventos WHERE Id_evento = @Id_evento)
            THROW 50036, 'El evento especificado no existe.', 1;

        -- Retrieve paginated payments
        SELECT 
            p.Id_pago,
            p.Id_evento,
            p.Monto,
            p.Fecha_pago,
            p.Metodo_pago,
            e.Id_cliente,
            c.Nombre AS Nombre_cliente,
            c.Apellido AS Apellido_cliente
        FROM Operaciones.Pagos p
        JOIN Operaciones.Eventos e ON p.Id_evento = e.Id_evento
        JOIN Operaciones.Clientes c ON e.Id_cliente = c.Id_cliente
        WHERE (@Id_evento IS NULL OR p.Id_evento = @Id_evento)
        ORDER BY p.Fecha_pago DESC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO


-------


CREATE OR ALTER PROCEDURE Administracion.AddEmpleado
(
    @Nombre VARCHAR(100),
    @Apellido VARCHAR(100),
    @Telefono VARCHAR(20),
    @Email VARCHAR(100),
    @Estado_Empleado INT,
    @Nombre_usuario VARCHAR(50),
    @Contrase�a NVARCHAR(100),
    @Id_Cargo INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate inputs
        IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
            THROW 50037, 'El nombre del empleado es requerido.', 1;
        IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
            THROW 50038, 'El apellido del empleado es requerido.', 1;
        IF @Telefono IS NULL OR LTRIM(RTRIM(@Telefono)) = ''
            THROW 50039, 'El tel�fono del empleado es requerido.', 1;
        IF @Email IS NULL OR LTRIM(RTRIM(@Email)) = ''
            THROW 50040, 'El email del empleado es requerido.', 1;
        IF EXISTS (SELECT 1 FROM Administracion.Empleados WHERE Email = @Email)
            THROW 50041, 'El email ya est� registrado.', 1;
        IF EXISTS (SELECT 1 FROM Administracion.Empleados WHERE Telefono = @Telefono)
            THROW 50042, 'El tel�fono ya est� registrado.', 1;
        IF NOT EXISTS (SELECT 1 FROM Administracion.Estado_Empleado WHERE Id_estado = @Estado_Empleado)
            THROW 50043, 'El estado del empleado no existe.', 1;
        IF @Nombre_usuario IS NULL OR LTRIM(RTRIM(@Nombre_usuario)) = ''
            THROW 50044, 'El nombre de usuario es requerido.', 1;
        IF EXISTS (SELECT 1 FROM Administracion.Usuarios WHERE Nombre_usuario = @Nombre_usuario)
            THROW 50045, 'El nombre de usuario ya est� registrado.', 1;
        IF @Contrase�a IS NULL OR LTRIM(RTRIM(@Contrase�a)) = ''
            THROW 50046, 'La contrase�a es requerida.', 1;
        IF NOT EXISTS (SELECT 1 FROM Administracion.Cargos WHERE Id_cargo = @Id_Cargo)
            THROW 50047, 'El cargo especificado no existe.', 1;

        -- Insert employee
        INSERT INTO Administracion.Empleados (Nombre, Apellido, Telefono, Email, Estado_Empleado)
        VALUES (@Nombre, @Apellido, @Telefono, @Email, @Estado_Empleado);

        DECLARE @Id_empleado INT = SCOPE_IDENTITY();

        -- Generate hashed password
        DECLARE @UniqueHash NVARCHAR(36) = NEWID();
        DECLARE @HashedPassword VARBINARY(32) = HASHBYTES('SHA2_256', @Contrase�a + @UniqueHash);

        -- Insert user
        INSERT INTO Administracion.Usuarios (Id_empleado, Id_Cargo, Nombre_usuario, Contrase�a, UniqueHash, Estado)
        VALUES (@Id_empleado, @Id_Cargo, @Nombre_usuario, @HashedPassword, @UniqueHash, 1);

        COMMIT TRANSACTION;

        SELECT 
            e.Id_empleado,
            e.Nombre,
            e.Apellido,
            e.Telefono,
            e.Email,
            e.Estado_Empleado,
            u.Nombre_usuario,
            u.Id_Cargo
        FROM Administracion.Empleados e
        JOIN Administracion.Usuarios u ON e.Id_empleado = u.Id_empleado
        WHERE e.Id_empleado = @Id_empleado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO


----------


CREATE OR ALTER PROCEDURE Administracion.GetEmpleados
(
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TextFilter NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate pagination parameters
        IF @PageNumber < 1
            THROW 50048, 'El número de página debe ser mayor o igual a 1.', 1;
        IF @PageSize < 1
            THROW 50049, 'El tamaño de página debe ser mayor o igual a 1.', 1;

        -- Retrieve paginated employees, JOIN con Usuarios y Cargos
        SELECT 
            e.Id_empleado,
            e.Nombre,
            e.Apellido,
            e.Telefono,
            e.Email,
            e.Estado_Empleado,
            es.Tipo_estado,
            u.Nombre_usuario,
            u.Id_Cargo,
            c.Nombre_cargo
        FROM Administracion.Empleados e
        JOIN Administracion.Estado_Empleado es ON e.Estado_Empleado = es.Id_estado
        LEFT JOIN Administracion.Usuarios u ON e.Id_empleado = u.Id_empleado
        LEFT JOIN Administracion.Cargos c ON u.Id_Cargo = c.Id_cargo
        WHERE (@TextFilter IS NULL OR 
               e.Nombre LIKE '%' + @TextFilter + '%' OR 
               e.Apellido LIKE '%' + @TextFilter + '%')
        ORDER BY e.Id_empleado ASC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO



-------


CREATE OR ALTER PROCEDURE Administracion.AddCargo
(
    @Nombre_cargo VARCHAR(100),
    @Descripci�n VARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate inputs
        IF @Nombre_cargo IS NULL OR LTRIM(RTRIM(@Nombre_cargo)) = ''
            THROW 50050, 'El nombre del cargo es requerido.', 1;

        -- Insert cargo
        INSERT INTO Administracion.Cargos (Nombre_cargo, Descripci�n)
        VALUES (@Nombre_cargo, @Descripci�n);

        SELECT Id_cargo, Nombre_cargo, Descripci�n
        FROM Administracion.Cargos
        WHERE Id_cargo = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO


----


CREATE OR ALTER PROCEDURE Administracion.GetCargos
(
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TextFilter NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate pagination parameters
        IF @PageNumber < 1
            THROW 50051, 'El n�mero de p�gina debe ser mayor o igual a 1.', 1;
        IF @PageSize < 1
            THROW 50052, 'El tama�o de p�gina debe ser mayor o igual a 1.', 1;

        -- Retrieve paginated cargos
        SELECT 
            Id_cargo,
            Nombre_cargo,
            Descripci�n
        FROM Administracion.Cargos
        WHERE (@TextFilter IS NULL OR Nombre_cargo LIKE '%' + @TextFilter + '%')
        ORDER BY Id_cargo ASC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO



--------



CREATE OR ALTER PROCEDURE Administracion.AddRol
(
    @Nombre_rol VARCHAR(100),
    @Descripcion VARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate inputs
        IF @Nombre_rol IS NULL OR LTRIM(RTRIM(@Nombre_rol)) = ''
            THROW 50053, 'El nombre del rol es requerido.', 1;

        -- Insert role
        INSERT INTO Administracion.Roles (Nombre_rol, Descripcion)
        VALUES (@Nombre_rol, @Descripcion);

        SELECT Id_rol, Nombre_rol, Descripcion
        FROM Administracion.Roles
        WHERE Id_rol = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO


------


CREATE OR ALTER PROCEDURE Administracion.GetRoles
(
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TextFilter NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate pagination parameters
        IF @PageNumber < 1
            THROW 50054, 'El n�mero de p�gina debe ser mayor o igual a 1.', 1;
        IF @PageSize < 1
            THROW 50055, 'El tama�o de p�gina debe ser mayor o igual a 1.', 1;

        -- Retrieve paginated roles
        SELECT 
            Id_rol,
            Nombre_rol,
            Descripcion
        FROM Administracion.Roles
        WHERE (@TextFilter IS NULL OR Nombre_rol LIKE '%' + @TextFilter + '%')
        ORDER BY Id_rol ASC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO


CREATE OR ALTER PROCEDURE Inventario.GetUtileria
(
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @Id_utileria INT = NULL,
    @TextFilter NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validar par�metros de paginaci�n
        IF @PageNumber < 1
            THROW 50060, 'El n�mero de p�gina debe ser mayor o igual a 1.', 1;
        IF @PageSize < 1
            THROW 50061, 'El tama�o de p�gina debe ser mayor o igual a 1.', 1;
        IF @Id_utileria IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Inventario.Utileria WHERE Id_utileria = @Id_utileria)
            THROW 50062, 'La utiler�a especificada no existe.', 1;

        -- Obtener utiler�as paginadas
        SELECT 
            u.Id_utileria,
            u.Nombre,
            u.Cantidad,
            STRING_AGG(s.Nombre_servicio, ', ') AS ServiciosAsociados
        FROM Inventario.Utileria u
        LEFT JOIN Inventario.Servicio_Utileria su ON u.Id_utileria = su.Id_utileria
        LEFT JOIN Operaciones.Servicios s ON su.Id_servicio = s.Id_servicio
        WHERE (@Id_utileria IS NULL OR u.Id_utileria = @Id_utileria)
          AND (@TextFilter IS NULL OR u.Nombre LIKE '%' + @TextFilter + '%')
        GROUP BY u.Id_utileria, u.Nombre, u.Cantidad
        ORDER BY u.Id_utileria ASC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Inventario.AddUtileria
(
    @Nombre VARCHAR(100),
    @Cantidad INT,
    @ServicioIds NVARCHAR(MAX) = NULL -- Nuevo parámetro opcional
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar entradas
        IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
            THROW 50063, 'El nombre de la utilería es requerido.', 1;
        IF EXISTS (SELECT 1 FROM Inventario.Utileria WHERE Nombre = @Nombre)
            THROW 50064, 'El nombre de la utilería ya está registrado.', 1;
        IF @Cantidad < 0
            THROW 50065, 'La cantidad debe ser mayor o igual a 0.', 1;

        -- Insertar utilería
        INSERT INTO Inventario.Utileria (Nombre, Cantidad)
        VALUES (@Nombre, @Cantidad);

        DECLARE @Id_utileria INT = SCOPE_IDENTITY();

        -- Insertar relaciones con servicios si se proporcionan
        IF @ServicioIds IS NOT NULL AND LTRIM(RTRIM(@ServicioIds)) != ''
        BEGIN
            INSERT INTO Inventario.Servicio_Utileria (Id_servicio, Id_utileria)
            SELECT CAST(value AS INT), @Id_utileria
            FROM STRING_SPLIT(@ServicioIds, ',')
            WHERE EXISTS (SELECT 1 FROM Operaciones.Servicios WHERE Id_servicio = CAST(value AS INT));
        END

        -- Devolver el registro insertado
        SELECT 
            Id_utileria,
            Nombre,
            Cantidad
        FROM Inventario.Utileria
        WHERE Id_utileria = @Id_utileria;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO


CREATE OR ALTER PROCEDURE Operaciones.GenerateUniqueContactInfo
    @Nombre NVARCHAR(100),
    @Apellido NVARCHAR(100),
    @Email NVARCHAR(100) OUTPUT,
    @Phone NVARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BaseEmail NVARCHAR(100);
    DECLARE @Counter INT = 0;
    DECLARE @UniqueEmail NVARCHAR(100);
    DECLARE @UniquePhone NVARCHAR(20);
    SET @BaseEmail = LOWER(REPLACE(@Nombre, ' ', '.') + '.' + REPLACE(@Apellido, ' ', '.') + '@example.com');
    SET @UniqueEmail = @BaseEmail;
    WHILE EXISTS (
        SELECT 1 FROM Administracion.Empleados WHERE Email = @UniqueEmail
        UNION
        SELECT 1 FROM Operaciones.Clientes WHERE Correo_electronico = @UniqueEmail
    )
    BEGIN
        SET @Counter = @Counter + 1;
        SET @UniqueEmail = LOWER(REPLACE(@Nombre, ' ', '.') + '.' + REPLACE(@Apellido, ' ', '.') + '_' + CAST(@Counter AS NVARCHAR(10)) + '@example.com');
    END
    SET @Email = @UniqueEmail;
    SET @UniquePhone = CAST(CAST(9000000000 + (ABS(CHECKSUM(NEWID())) % 1000000000) AS BIGINT) AS NVARCHAR(20));
    WHILE EXISTS (
        SELECT 1 FROM Administracion.Empleados WHERE Telefono = @UniquePhone
        UNION
        SELECT 1 FROM Operaciones.Clientes WHERE Telefono = @UniquePhone
    )
    BEGIN
        SET @UniquePhone = CAST(CAST(9000000000 + (ABS(CHECKSUM(NEWID())) % 1000000000) AS BIGINT) AS NVARCHAR(20));
    END
    SET @Phone = @UniquePhone;
END;
GO



-- Updates -----------------------------------------------------------------------------------------


--USE ShowtimeDB;
--GO

-- Update Cliente
CREATE OR ALTER PROCEDURE Operaciones.UpdateCliente
(
    @Id_cliente INT,
    @Nombre VARCHAR(100),
    @Apellido VARCHAR(100),
    @Telefono VARCHAR(20),
    @Correo_electronico VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate inputs
        IF NOT EXISTS (SELECT 1 FROM Operaciones.Clientes WHERE Id_cliente = @Id_cliente)
            THROW 50066, 'El cliente especificado no existe.', 1;
        IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
            THROW 50001, 'El nombre del cliente es requerido.', 1;
        IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
            THROW 50002, 'El apellido del cliente es requerido.', 1;
        IF @Telefono IS NULL OR LTRIM(RTRIM(@Telefono)) = ''
            THROW 50003, 'El tel�fono del cliente es requerido.', 1;
        IF @Correo_electronico IS NOT NULL AND EXISTS (
            SELECT 1 FROM Operaciones.Clientes 
            WHERE Correo_electronico = @Correo_electronico AND Id_cliente != @Id_cliente
        )
            THROW 50004, 'El correo electr�nico ya est� registrado.', 1;
        IF EXISTS (SELECT 1 FROM Operaciones.Clientes WHERE Telefono = @Telefono AND Id_cliente != @Id_cliente)
            THROW 50005, 'El tel�fono ya est� registrado.', 1;
        IF @Correo_electronico IS NOT NULL AND 
           @Correo_electronico NOT LIKE '_%@_%._%'
            THROW 50006, 'El formato del correo electr�nico no es v�lido.', 1;

        -- Update client
        UPDATE Operaciones.Clientes
        SET Nombre = @Nombre,
            Apellido = @Apellido,
            Telefono = @Telefono,
            Correo_electronico = @Correo_electronico
        WHERE Id_cliente = @Id_cliente;

        -- Return updated client
        SELECT Id_cliente, Nombre, Apellido, Telefono, Correo_electronico
        FROM Operaciones.Clientes
        WHERE Id_cliente = @Id_cliente;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE Operaciones.UpdatePaquete
(
    @Id_paquete INT,
    @Nombre_paquete VARCHAR(100),
    @Descripcion VARCHAR(MAX) = NULL,
    @Cantidad INT = NULL,
    @Disponibilidad BIT,
    @Costo DECIMAL(18, 2),
    @ServicioIds NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate inputs
        IF NOT EXISTS (SELECT 1 FROM Operaciones.Paquetes WHERE Id_paquete = @Id_paquete)
            THROW 50067, 'El paquete especificado no existe.', 1;
        IF @Nombre_paquete IS NULL OR LTRIM(RTRIM(@Nombre_paquete)) = ''
            THROW 50008, 'El nombre del paquete es requerido.', 1;
        IF @Costo <= 0
            THROW 50009, 'El costo del paquete debe ser mayor a 0.', 1;
        IF @Cantidad IS NOT NULL AND @Cantidad < 0
            THROW 50010, 'La cantidad no puede ser negativa.', 1;

        -- Update package
        UPDATE Operaciones.Paquetes
        SET Nombre_paquete = @Nombre_paquete,
            Descripcion = @Descripcion,
            Cantidad = @Cantidad,
            Disponibilidad = @Disponibilidad,
            Costo = @Costo
        WHERE Id_paquete = @Id_paquete;

        -- Delete existing related services
        DELETE FROM Operaciones.Paquete_Servicios
        WHERE Id_paquete = @Id_paquete;

        -- Insert updated related services if provided
        IF @ServicioIds IS NOT NULL AND LTRIM(RTRIM(@ServicioIds)) != ''
        BEGIN
            INSERT INTO Operaciones.Paquete_Servicios (Id_paquete, Id_servicio)
            SELECT @Id_paquete, CAST(value AS INT)
            FROM STRING_SPLIT(@ServicioIds, ',')
            WHERE EXISTS (SELECT 1 FROM Operaciones.Servicios WHERE Id_servicio = CAST(value AS INT));
        END;

        -- Return updated package with associated services as JSON
        SELECT 
            p.Id_paquete,
            p.Nombre_paquete,
            p.Descripcion,
            p.Cantidad,
            p.Disponibilidad,
            p.Costo,
            (
                SELECT 
                    s.Id_servicio,
                    s.Nombre_servicio,
                    s.Descripcion,
                    s.Costo
                FROM Operaciones.Paquete_Servicios ps
                INNER JOIN Operaciones.Servicios s ON ps.Id_servicio = s.Id_servicio
                WHERE ps.Id_paquete = p.Id_paquete
                FOR JSON PATH
            ) AS ServiciosJson
        FROM Operaciones.Paquetes p
        WHERE p.Id_paquete = @Id_paquete;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Update Evento
CREATE OR ALTER PROCEDURE Operaciones.UpdateEvento
(
    @Id_evento INT,
    @Id_paquete INT = NULL,
    @Id_cliente INT,
    @Fecha_reserva DATE,
    @Fecha_inicio DATE,
    @Hora_inicio TIME,
    @Hora_fin TIME,
    @Ubicacion VARCHAR(255),
    @Direccion VARCHAR(MAX),
    @Cantidad_de_asistentes INT,
    @Detalles_adicionales VARCHAR(MAX) = NULL,
    @Costo_total DECIMAL(18, 2),
    @Estado VARCHAR(20) = 'Pendiente',
    @ServicioIds NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate inputs
        IF NOT EXISTS (SELECT 1 FROM Operaciones.Eventos WHERE Id_evento = @Id_evento)
            THROW 50068, 'El evento especificado no existe.', 1;
        IF @Id_cliente IS NULL OR NOT EXISTS (SELECT 1 FROM Operaciones.Clientes WHERE Id_cliente = @Id_cliente)
            THROW 50013, 'El cliente especificado no existe.', 1;
        IF @Id_paquete IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Operaciones.Paquetes WHERE Id_paquete = @Id_paquete)
            THROW 50014, 'El paquete especificado no existe.', 1;
        IF @Fecha_reserva IS NULL OR @Fecha_inicio IS NULL
            THROW 50015, 'La fecha de reserva y la fecha de inicio son requeridas.', 1;
        IF @Hora_inicio IS NULL OR @Hora_fin IS NULL
            THROW 50016, 'La hora de inicio y fin son requeridas.', 1;
        IF @Fecha_inicio <= @Fecha_reserva OR @Hora_fin <= @Hora_inicio
            THROW 50017, 'La fecha de inicio debe ser posterior a la reserva y la hora de fin posterior a la de inicio.', 1;
        IF @Ubicacion IS NULL OR LTRIM(RTRIM(@Ubicacion)) = ''
            THROW 50018, 'La ubicaci�n es requerida.', 1;
        IF @Direccion IS NULL OR LTRIM(RTRIM(@Direccion)) = ''
            THROW 50019, 'La direcci�n es requerida.', 1;
        IF @Cantidad_de_asistentes <= 0
            THROW 50020, 'La cantidad de asistentes debe ser mayor a 0.', 1;
        IF @Costo_total <= 0
            THROW 50021, 'El costo total debe ser mayor a 0.', 1;
        IF @Estado NOT IN ('Pendiente', 'Reservado', 'Finalizado', 'Cancelado', 'Incompleto')
            THROW 50022, 'Estado inv�lido.', 1;

        -- Update event
        UPDATE Operaciones.Eventos
        SET Id_paquete = @Id_paquete,
            Id_cliente = @Id_cliente,
            Fecha_reserva = @Fecha_reserva,
            Fecha_inicio = @Fecha_inicio,
            Hora_inicio = @Hora_inicio,
            Hora_fin = @Hora_fin,
            Ubicacion = @Ubicacion,
            Direccion = @Direccion,
            Cantidad_de_asistentes = @Cantidad_de_asistentes,
            Detalles_adicionales = @Detalles_adicionales,
            Costo_total = @Costo_total,
            Estado = @Estado
        WHERE Id_evento = @Id_evento;

        -- Delete existing related services
        DELETE FROM Operaciones.Evento_Servicios
        WHERE Id_evento = @Id_evento;

        -- Insert updated related services if provided
        IF @ServicioIds IS NOT NULL AND LTRIM(RTRIM(@ServicioIds)) != ''
        BEGIN
            INSERT INTO Operaciones.Evento_Servicios (Id_evento, Id_servicio)
            SELECT @Id_evento, CAST(value AS INT)
            FROM STRING_SPLIT(@ServicioIds, ',')
            WHERE EXISTS (SELECT 1 FROM Operaciones.Servicios WHERE Id_servicio = CAST(value AS INT));
        END;

        -- Return updated event
        SELECT Id_evento, Id_paquete, Id_cliente, Fecha_reserva, Fecha_inicio, Hora_inicio, Hora_fin,
               Ubicacion, Direccion, Cantidad_de_asistentes, Detalles_adicionales, Costo_total, Estado
        FROM Operaciones.Eventos
        WHERE Id_evento = @Id_evento;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Update Servicio
CREATE OR ALTER PROCEDURE Operaciones.UpdateServicio
(
    @Id_servicio INT,
    @Nombre_servicio VARCHAR(100),
    @Descripcion VARCHAR(MAX) = NULL,
    @Costo DECIMAL(18, 2),
    @UtileriaIds NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate inputs
        IF NOT EXISTS (SELECT 1 FROM Operaciones.Servicios WHERE Id_servicio = @Id_servicio)
            THROW 50069, 'El servicio especificado no existe.', 1;
        IF @Nombre_servicio IS NULL OR LTRIM(RTRIM(@Nombre_servicio)) = ''
            THROW 50026, 'El nombre del servicio es requerido.', 1;
        IF @Costo <= 0
            THROW 50027, 'El costo del servicio debe ser mayor a 0.', 1;

        -- Update service
        UPDATE Operaciones.Servicios
        SET Nombre_servicio = @Nombre_servicio,
            Descripcion = @Descripcion,
            Costo = @Costo
        WHERE Id_servicio = @Id_servicio;

        -- Delete existing related props
        DELETE FROM Inventario.Servicio_Utileria
        WHERE Id_servicio = @Id_servicio;

        -- Insert updated related props if provided
        IF @UtileriaIds IS NOT NULL AND LTRIM(RTRIM(@UtileriaIds)) != ''
        BEGIN
            INSERT INTO Inventario.Servicio_Utileria (Id_servicio, Id_utileria)
            SELECT @Id_servicio, CAST(value AS INT)
            FROM STRING_SPLIT(@UtileriaIds, ',')
            WHERE EXISTS (SELECT 1 FROM Inventario.Utileria WHERE Id_utileria = CAST(value AS INT));
        END;

        -- Return updated service
        SELECT Id_servicio, Nombre_servicio, Descripcion, Costo
        FROM Operaciones.Servicios
        WHERE Id_servicio = @Id_servicio;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Update Pago
CREATE OR ALTER PROCEDURE Operaciones.UpdatePago
(
    @Id_pago INT,
    @Id_evento INT,
    @Monto DECIMAL(18, 2),
    @Fecha_pago DATE,
    @Metodo_pago VARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate inputs
        IF NOT EXISTS (SELECT 1 FROM Operaciones.Pagos WHERE Id_pago = @Id_pago)
            THROW 50070, 'El pago especificado no existe.', 1;
        IF @Id_evento IS NULL OR NOT EXISTS (SELECT 1 FROM Operaciones.Eventos WHERE Id_evento = @Id_evento)
            THROW 50030, 'El evento especificado no existe.', 1;
        IF @Monto <= 0
            THROW 50031, 'El monto del pago debe ser mayor a 0.', 1;
        IF @Fecha_pago IS NULL
            THROW 50032, 'La fecha de pago es requerida.', 1;
        IF @Metodo_pago IS NULL OR LTRIM(RTRIM(@Metodo_pago)) = ''
            THROW 50033, 'El m�todo de pago es requerido.', 1;

        -- Validate payment against event cost
        DECLARE @Costo_total DECIMAL(18, 2);
        DECLARE @Total_pagado DECIMAL(18, 2);

        -- Get event total cost
        SELECT @Costo_total = Costo_total
        FROM Operaciones.Eventos
        WHERE Id_evento = @Id_evento;

        -- Get sum of previous payments excluding the current payment
        SELECT @Total_pagado = ISNULL(SUM(Monto), 0)
        FROM Operaciones.Pagos
        WHERE Id_evento = @Id_evento AND Id_pago != @Id_pago;

        -- Check if new payment exceeds remaining balance
        IF (@Total_pagado + @Monto) > @Costo_total
            THROW 50034, 'El monto del pago excede el costo total pendiente del evento.', 1;

        -- Update payment
        UPDATE Operaciones.Pagos
        SET Id_evento = @Id_evento,
            Monto = @Monto,
            Fecha_pago = @Fecha_pago,
            Metodo_pago = @Metodo_pago
        WHERE Id_pago = @Id_pago;

        -- Return updated payment
        SELECT Id_pago, Id_evento, Monto, Fecha_pago, Metodo_pago
        FROM Operaciones.Pagos
        WHERE Id_pago = @Id_pago;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Update Empleado
CREATE OR ALTER PROCEDURE Administracion.UpdateEmpleado
(
    @Id_empleado INT,
    @Nombre VARCHAR(100),
    @Apellido VARCHAR(100),
    @Telefono VARCHAR(20),
    @Email VARCHAR(100),
    @Estado_Empleado INT,
    @Nombre_usuario VARCHAR(50),
    @Contrase�a NVARCHAR(100) = NULL,
    @Id_Cargo INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate inputs
        IF NOT EXISTS (SELECT 1 FROM Administracion.Empleados WHERE Id_empleado = @Id_empleado)
            THROW 50071, 'El empleado especificado no existe.', 1;
        IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
            THROW 50037, 'El nombre del empleado es requerido.', 1;
        IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
            THROW 50038, 'El apellido del empleado es requerido.', 1;
        IF @Telefono IS NULL OR LTRIM(RTRIM(@Telefono)) = ''
            THROW 50039, 'El tel�fono del empleado es requerido.', 1;
        IF @Email IS NULL OR LTRIM(RTRIM(@Email)) = ''
            THROW 50040, 'El email del empleado es requerido.', 1;
        IF EXISTS (SELECT 1 FROM Administracion.Empleados WHERE Email = @Email AND Id_empleado != @Id_empleado)
            THROW 50041, 'El email ya est� registrado.', 1;
        IF EXISTS (SELECT 1 FROM Administracion.Empleados WHERE Telefono = @Telefono AND Id_empleado != @Id_empleado)
            THROW 50042, 'El tel�fono ya est� registrado.', 1;
        IF NOT EXISTS (SELECT 1 FROM Administracion.Estado_Empleado WHERE Id_estado = @Estado_Empleado)
            THROW 50043, 'El estado del empleado no existe.', 1;
        IF @Nombre_usuario IS NULL OR LTRIM(RTRIM(@Nombre_usuario)) = ''
            THROW 50044, 'El nombre de usuario es requerido.', 1;
        IF EXISTS (SELECT 1 FROM Administracion.Usuarios WHERE Nombre_usuario = @Nombre_usuario AND Id_empleado != @Id_empleado)
            THROW 50045, 'El nombre de usuario ya est� registrado.', 1;
        IF NOT EXISTS (SELECT 1 FROM Administracion.Cargos WHERE Id_cargo = @Id_Cargo)
            THROW 50047, 'El cargo especificado no existe.', 1;

        -- Update employee
        UPDATE Administracion.Empleados
        SET Nombre = @Nombre,
            Apellido = @Apellido,
            Telefono = @Telefono,
            Email = @Email,
            Estado_Empleado = @Estado_Empleado
        WHERE Id_empleado = @Id_empleado;

        -- Update user
        IF @Contrase�a IS NOT NULL AND LTRIM(RTRIM(@Contrase�a)) != ''
        BEGIN
            DECLARE @UniqueHash NVARCHAR(36) = NEWID();
            DECLARE @HashedPassword VARBINARY(32) = HASHBYTES('SHA2_256', @Contrase�a + @UniqueHash);

            UPDATE Administracion.Usuarios
            SET Nombre_usuario = @Nombre_usuario,
                Contrase�a = @HashedPassword,
                UniqueHash = @UniqueHash,
                Id_Cargo = @Id_Cargo
            WHERE Id_empleado = @Id_empleado;
        END
        ELSE
        BEGIN
            UPDATE Administracion.Usuarios
            SET Nombre_usuario = @Nombre_usuario,
                Id_Cargo = @Id_Cargo
            WHERE Id_empleado = @Id_empleado;
        END;

        -- Return updated employee
        SELECT 
            e.Id_empleado,
            e.Nombre,
            e.Apellido,
            e.Telefono,
            e.Email,
            e.Estado_Empleado,
            u.Nombre_usuario,
            u.Id_Cargo
        FROM Administracion.Empleados e
        JOIN Administracion.Usuarios u ON e.Id_empleado = u.Id_empleado
        WHERE e.Id_empleado = @Id_empleado;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Update Cargo
CREATE OR ALTER PROCEDURE Administracion.UpdateCargo
(
    @Id_cargo INT,
    @Nombre_cargo VARCHAR(100),
    @Descripci�n VARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate inputs
        IF NOT EXISTS (SELECT 1 FROM Administracion.Cargos WHERE Id_cargo = @Id_cargo)
            THROW 50072, 'El cargo especificado no existe.', 1;
        IF @Nombre_cargo IS NULL OR LTRIM(RTRIM(@Nombre_cargo)) = ''
            THROW 50050, 'El nombre del cargo es requerido.', 1;

        -- Update cargo
        UPDATE Administracion.Cargos
        SET Nombre_cargo = @Nombre_cargo,
            Descripci�n = @Descripci�n
        WHERE Id_cargo = @Id_cargo;

        -- Return updated cargo
        SELECT Id_cargo, Nombre_cargo, Descripci�n
        FROM Administracion.Cargos
        WHERE Id_cargo = @Id_cargo;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Update Rol
CREATE OR ALTER PROCEDURE Administracion.UpdateRol
(
    @Id_rol INT,
    @Nombre_rol VARCHAR(100),
    @Descripcion VARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate inputs
        IF NOT EXISTS (SELECT 1 FROM Administracion.Roles WHERE Id_rol = @Id_rol)
            THROW 50073, 'El rol especificado no existe.', 1;
        IF @Nombre_rol IS NULL OR LTRIM(RTRIM(@Nombre_rol)) = ''
            THROW 50053, 'El nombre del rol es requerido.', 1;

        -- Update role
        UPDATE Administracion.Roles
        SET Nombre_rol = @Nombre_rol,
            Descripcion = @Descripcion
        WHERE Id_rol = @Id_rol;

        -- Return updated role
        SELECT Id_rol, Nombre_rol, Descripcion
        FROM Administracion.Roles
        WHERE Id_rol = @Id_rol;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Update Utileria
CREATE OR ALTER PROCEDURE Inventario.UpdateUtileria
(
    @Id_utileria INT,
    @Nombre VARCHAR(100),
    @Cantidad INT,
    @ServicioIds NVARCHAR(MAX) = NULL -- Nuevo parámetro
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validaciones existentes
        IF NOT EXISTS (SELECT 1 FROM Inventario.Utileria WHERE Id_utileria = @Id_utileria)
            THROW 50074, 'La utilería especificada no existe.', 1;
        IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
            THROW 50063, 'El nombre de la utilería es requerido.', 1;
        IF EXISTS (SELECT 1 FROM Inventario.Utileria WHERE Nombre = @Nombre AND Id_utileria != @Id_utileria)
            THROW 50064, 'El nombre de la utilería ya está registrado.', 1;
        IF @Cantidad < 0
            THROW 50065, 'La cantidad debe ser mayor o igual a 0.', 1;

        -- Actualizar utilería
        UPDATE Inventario.Utileria
        SET Nombre = @Nombre,
            Cantidad = @Cantidad
        WHERE Id_utileria = @Id_utileria;

        -- Eliminar relaciones actuales
        DELETE FROM Inventario.Servicio_Utileria WHERE Id_utileria = @Id_utileria;

        -- Insertar nuevas relaciones si se proporcionan
        IF @ServicioIds IS NOT NULL AND LTRIM(RTRIM(@ServicioIds)) != ''
        BEGIN
            INSERT INTO Inventario.Servicio_Utileria (Id_servicio, Id_utileria)
            SELECT CAST(value AS INT), @Id_utileria
            FROM STRING_SPLIT(@ServicioIds, ',')
            WHERE EXISTS (SELECT 1 FROM Operaciones.Servicios WHERE Id_servicio = CAST(value AS INT));
        END

        -- Devolver utilería actualizada
        SELECT Id_utileria, Nombre, Cantidad
        FROM Inventario.Utileria
        WHERE Id_utileria = @Id_utileria;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO
----------GetById

--USE ShowtimeDB;
--GO

-- Get Cliente by Id
CREATE OR ALTER PROCEDURE Operaciones.GetClienteById
(
    @Id_cliente INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate input
        IF @Id_cliente IS NULL OR NOT EXISTS (SELECT 1 FROM Operaciones.Clientes WHERE Id_cliente = @Id_cliente)
            THROW 50075, 'El cliente especificado no existe.', 1;

        -- Retrieve client by ID
        SELECT 
            Id_cliente,
            Nombre,
            Apellido,
            Telefono,
            Correo_electronico
        FROM Operaciones.Clientes
        WHERE Id_cliente = @Id_cliente;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Get Paquete by Id
CREATE OR ALTER PROCEDURE Operaciones.GetPaqueteById
(
    @Id_paquete INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate input
        IF @Id_paquete IS NULL OR NOT EXISTS (SELECT 1 FROM Operaciones.Paquetes WHERE Id_paquete = @Id_paquete)
            THROW 50076, 'El paquete especificado no existe.', 1;

        -- Retrieve package by ID
        SELECT 
            Id_paquete,
            Nombre_paquete,
            Descripcion,
            Cantidad,
            Disponibilidad,
            Costo
        FROM Operaciones.Paquetes
        WHERE Id_paquete = @Id_paquete;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Get Evento by Id
CREATE OR ALTER PROCEDURE Operaciones.GetEventoById
(
    @Id_evento INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate input
        IF @Id_evento IS NULL OR NOT EXISTS (SELECT 1 FROM Operaciones.Eventos WHERE Id_evento = @Id_evento)
            THROW 50077, 'El evento especificado no existe.', 1;

        -- Retrieve event by ID
        SELECT 
            e.Id_evento,
            e.Id_paquete,
            e.Id_cliente,
            c.Nombre AS Nombre_cliente,
            c.Apellido AS Apellido_cliente,
            e.Fecha_reserva,
            e.Fecha_inicio,
            e.Hora_inicio,
            e.Hora_fin,
            e.Ubicacion,
            e.Direccion,
            e.Cantidad_de_asistentes,
            e.Detalles_adicionales,
            e.Costo_total,
            e.Estado
        FROM Operaciones.Eventos e
        JOIN Operaciones.Clientes c ON e.Id_cliente = c.Id_cliente
        WHERE e.Id_evento = @Id_evento;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Get Servicio by Id
CREATE OR ALTER PROCEDURE Operaciones.GetServicioById
(
    @Id_servicio INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate input
        IF @Id_servicio IS NULL OR NOT EXISTS (SELECT 1 FROM Operaciones.Servicios WHERE Id_servicio = @Id_servicio)
            THROW 50078, 'El servicio especificado no existe.', 1;

        -- Retrieve service by ID
        SELECT 
            Id_servicio,
            Nombre_servicio,
            Descripcion,
            Costo
        FROM Operaciones.Servicios
        WHERE Id_servicio = @Id_servicio;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Get Pago by Id
CREATE OR ALTER PROCEDURE Operaciones.GetPagoById
(
    @Id_pago INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate input
        IF @Id_pago IS NULL OR NOT EXISTS (SELECT 1 FROM Operaciones.Pagos WHERE Id_pago = @Id_pago)
            THROW 50079, 'El pago especificado no existe.', 1;

        -- Retrieve payment by ID
        SELECT 
            p.Id_pago,
            p.Id_evento,
            p.Monto,
            p.Fecha_pago,
            p.Metodo_pago,
            e.Id_cliente,
            c.Nombre AS Nombre_cliente,
            c.Apellido AS Apellido_cliente
        FROM Operaciones.Pagos p
        JOIN Operaciones.Eventos e ON p.Id_evento = e.Id_evento
        JOIN Operaciones.Clientes c ON e.Id_cliente = c.Id_cliente
        WHERE p.Id_pago = @Id_pago;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Get Empleado by Id
CREATE OR ALTER PROCEDURE Administracion.GetEmpleadoById
(
    @Id_empleado INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate input
        IF @Id_empleado IS NULL OR NOT EXISTS (SELECT 1 FROM Administracion.Empleados WHERE Id_empleado = @Id_empleado)
            THROW 50080, 'El empleado especificado no existe.', 1;

        -- Retrieve employee by ID
        SELECT 
            e.Id_empleado,
            e.Nombre,
            e.Apellido,
            e.Telefono,
            e.Email,
            e.Estado_Empleado,
            es.Tipo_estado,
            u.Nombre_usuario,
            u.Id_Cargo
        FROM Administracion.Empleados e
        JOIN Administracion.Estado_Empleado es ON e.Estado_Empleado = es.Id_estado
        JOIN Administracion.Usuarios u ON e.Id_empleado = u.Id_empleado
        WHERE e.Id_empleado = @Id_empleado;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Get Cargo by Id
CREATE OR ALTER PROCEDURE Administracion.GetCargoById
(
    @Id_cargo INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate input
        IF @Id_cargo IS NULL OR NOT EXISTS (SELECT 1 FROM Administracion.Cargos WHERE Id_cargo = @Id_cargo)
            THROW 50081, 'El cargo especificado no existe.', 1;

        -- Retrieve cargo by ID
        SELECT 
            Id_cargo,
            Nombre_cargo,
            Descripci�n
        FROM Administracion.Cargos
        WHERE Id_cargo = @Id_cargo;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Get Rol by Id
CREATE OR ALTER PROCEDURE Administracion.GetRolById
(
    @Id_rol INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate input
        IF @Id_rol IS NULL OR NOT EXISTS (SELECT 1 FROM Administracion.Roles WHERE Id_rol = @Id_rol)
            THROW 50082, 'El rol especificado no existe.', 1;

        -- Retrieve role by ID
        SELECT 
            Id_rol,
            Nombre_rol,
            Descripcion
        FROM Administracion.Roles
        WHERE Id_rol = @Id_rol;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Get Utileria by Id
CREATE OR ALTER PROCEDURE Inventario.GetUtileriaById
(
    @Id_utileria INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validate input
        IF @Id_utileria IS NULL OR NOT EXISTS (SELECT 1 FROM Inventario.Utileria WHERE Id_utileria = @Id_utileria)
            THROW 50083, 'La utiler�a especificada no existe.', 1;

        -- Retrieve utileria by ID
        SELECT 
            u.Id_utileria,
            u.Nombre,
            u.Cantidad,
            STRING_AGG(s.Nombre_servicio, ', ') AS ServiciosAsociados
        FROM Inventario.Utileria u
        LEFT JOIN Inventario.Servicio_Utileria su ON u.Id_utileria = su.Id_utileria
        LEFT JOIN Operaciones.Servicios s ON su.Id_servicio = s.Id_servicio
        WHERE u.Id_utileria = @Id_utileria
        GROUP BY u.Id_utileria, u.Nombre, u.Cantidad;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

--- =============================================
-- PROCEDIMIENTOS PARA ASIGNACIÓN DE EMPLEADOS A EVENTOS
-- =============================================

--USE ShowtimeDB;
--GO
CREATE OR ALTER PROCEDURE Administracion.AddAsignacionEmpleadoEvento
(
    @Id_evento INT,
    @Id_empleado INT,
    @Id_rol INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar entradas
        IF @Id_evento IS NULL OR NOT EXISTS (SELECT 1 FROM Operaciones.Eventos WHERE Id_evento = @Id_evento)
            THROW 50084, 'El evento especificado no existe.', 1;
        IF @Id_empleado IS NULL OR NOT EXISTS (SELECT 1 FROM Administracion.Empleados WHERE Id_empleado = @Id_empleado)
            THROW 50085, 'El empleado especificado no existe.', 1;
        IF @Id_rol IS NULL OR NOT EXISTS (SELECT 1 FROM Administracion.Roles WHERE Id_rol = @Id_rol)
            THROW 50086, 'El rol especificado no existe.', 1;

        -- Verificar que el empleado esté disponible (Estado_Empleado = 1 o 2)
        IF NOT EXISTS (
            SELECT 1 FROM Administracion.Empleados 
            WHERE Id_empleado = @Id_empleado 
            AND Estado_Empleado IN (1, 2) -- Activo o Disponible
        )
            THROW 50087, 'El empleado no está disponible para asignación.', 1;

        -- Verificar que no exista ya una asignación para este empleado en este evento
        IF EXISTS (
            SELECT 1 FROM Administracion.Rol_Empleado_Evento 
            WHERE Id_evento = @Id_evento AND Id_empleado = @Id_empleado
        )
            THROW 50088, 'El empleado ya está asignado a este evento.', 1;

        -- Obtener datos del evento actual
        DECLARE @Fecha_evento DATE, @Hora_inicio TIME, @Hora_fin TIME;
        SELECT @Fecha_evento = Fecha_inicio, @Hora_inicio = Hora_inicio, @Hora_fin = Hora_fin
        FROM Operaciones.Eventos 
        WHERE Id_evento = @Id_evento;

        -- Validar traslape de horario en la misma fecha
        IF EXISTS (
            SELECT 1
            FROM Administracion.Rol_Empleado_Evento RE
            JOIN Operaciones.Eventos E ON RE.Id_evento = E.Id_evento
            WHERE RE.Id_empleado = @Id_empleado
              AND E.Fecha_inicio = @Fecha_evento
              AND (E.Hora_inicio < @Hora_fin AND E.Hora_fin > @Hora_inicio)
              AND RE.Id_evento != @Id_evento
        )
            THROW 50095, 'El empleado ya está asignado a otro evento en el mismo día y horario.', 1;

        -- Insertar la asignación
        INSERT INTO Administracion.Rol_Empleado_Evento (Id_evento, Id_empleado, Id_rol)
        VALUES (@Id_evento, @Id_empleado, @Id_rol);

        -- Actualizar el estado del empleado a "En evento" (Estado_Empleado = 3)
        UPDATE Administracion.Empleados
        SET Estado_Empleado = 3
        WHERE Id_empleado = @Id_empleado;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO
GO
-- Procedimiento para actualizar una asignación de empleado a evento
CREATE OR ALTER PROCEDURE Administracion.UpdateAsignacionEmpleadoEvento
(
    @Id_rol_empleado_evento INT,
    @Id_evento INT = NULL,
    @Id_empleado INT = NULL,
    @Id_rol INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que la asignación existe
        IF NOT EXISTS (SELECT 1 FROM Administracion.Rol_Empleado_Evento WHERE Id_rol_empleado_evento = @Id_rol_empleado_evento)
            THROW 50090, 'La asignación especificada no existe.', 1;

        -- Obtener valores actuales si no se proporcionan
        DECLARE @CurrentId_evento INT, @CurrentId_empleado INT, @CurrentId_rol INT;
        SELECT @CurrentId_evento = Id_evento, @CurrentId_empleado = Id_empleado, @CurrentId_rol = Id_rol
        FROM Administracion.Rol_Empleado_Evento
        WHERE Id_rol_empleado_evento = @Id_rol_empleado_evento;

        SET @Id_evento = ISNULL(@Id_evento, @CurrentId_evento);
        SET @Id_empleado = ISNULL(@Id_empleado, @CurrentId_empleado);
        SET @Id_rol = ISNULL(@Id_rol, @CurrentId_rol);

        -- Validar entradas
        IF NOT EXISTS (SELECT 1 FROM Operaciones.Eventos WHERE Id_evento = @Id_evento)
            THROW 50084, 'El evento especificado no existe.', 1;
        IF NOT EXISTS (SELECT 1 FROM Administracion.Empleados WHERE Id_empleado = @Id_empleado)
            THROW 50085, 'El empleado especificado no existe.', 1;
        IF NOT EXISTS (SELECT 1 FROM Administracion.Roles WHERE Id_rol = @Id_rol)
            THROW 50086, 'El rol especificado no existe.', 1;

        -- Obtener datos del evento destino
        DECLARE @Fecha_evento DATE, @Hora_inicio TIME, @Hora_fin TIME;
        SELECT @Fecha_evento = Fecha_inicio, @Hora_inicio = Hora_inicio, @Hora_fin = Hora_fin
        FROM Operaciones.Eventos 
        WHERE Id_evento = @Id_evento;

        -- Si se está cambiando el empleado o el evento, validar traslape de horario
        IF @Id_empleado != @CurrentId_empleado OR @Id_evento != @CurrentId_evento
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM Administracion.Rol_Empleado_Evento RE
                JOIN Operaciones.Eventos E ON RE.Id_evento = E.Id_evento
                WHERE RE.Id_empleado = @Id_empleado
                  AND E.Fecha_inicio = @Fecha_evento
                  AND (E.Hora_inicio < @Hora_fin AND E.Hora_fin > @Hora_inicio)
                  AND RE.Id_rol_empleado_evento != @Id_rol_empleado_evento
            )
                THROW 50095, 'El empleado ya está asignado a otro evento en el mismo día y horario.', 1;
        END

        -- Si se está cambiando el empleado, verificar disponibilidad y otras validaciones
        IF @Id_empleado != @CurrentId_empleado
        BEGIN
            -- Verificar que el nuevo empleado esté disponible
            IF NOT EXISTS (
                SELECT 1 FROM Administracion.Empleados 
                WHERE Id_empleado = @Id_empleado 
                AND Estado_Empleado IN (1, 2) -- Activo o Disponible
            )
                THROW 50087, 'El empleado no está disponible para asignación.', 1;

            -- Verificar que no exista ya una asignación para este empleado en este evento
            IF EXISTS (
                SELECT 1 FROM Administracion.Rol_Empleado_Evento 
                WHERE Id_evento = @Id_evento AND Id_empleado = @Id_empleado
                AND Id_rol_empleado_evento != @Id_rol_empleado_evento
            )
                THROW 50088, 'El empleado ya está asignado a este evento.', 1;

            -- Restaurar el estado del empleado anterior a "Disponible" si no tiene otras asignaciones
            IF NOT EXISTS (
                SELECT 1 FROM Administracion.Rol_Empleado_Evento 
                WHERE Id_empleado = @CurrentId_empleado 
                AND Id_rol_empleado_evento != @Id_rol_empleado_evento
            )
            BEGIN
                UPDATE Administracion.Empleados
                SET Estado_Empleado = 2 -- Disponible
                WHERE Id_empleado = @CurrentId_empleado;
            END;

            -- Actualizar el estado del nuevo empleado a "En evento"
            UPDATE Administracion.Empleados
            SET Estado_Empleado = 3 -- En evento
            WHERE Id_empleado = @Id_empleado;
        END;

        -- Actualizar la asignación
        UPDATE Administracion.Rol_Empleado_Evento
        SET Id_evento = @Id_evento,
            Id_empleado = @Id_empleado,
            Id_rol = @Id_rol
        WHERE Id_rol_empleado_evento = @Id_rol_empleado_evento;

        COMMIT TRANSACTION;

        -- Retornar la asignación actualizada
        SELECT 
            ree.Id_rol_empleado_evento,
            ree.Id_evento,
            ree.Id_empleado,
            ree.Id_rol,
            e.Fecha_inicio,
            e.Hora_inicio,
            e.Hora_fin,
            e.Ubicacion,
            emp.Nombre + ' ' + emp.Apellido AS Nombre_empleado,
            r.Nombre_rol,
            es.Tipo_estado
        FROM Administracion.Rol_Empleado_Evento ree
        JOIN Operaciones.Eventos e ON ree.Id_evento = e.Id_evento
        JOIN Administracion.Empleados emp ON ree.Id_empleado = emp.Id_empleado
        JOIN Administracion.Roles r ON ree.Id_rol = r.Id_rol
        JOIN Administracion.Estado_Empleado es ON emp.Estado_Empleado = es.Id_estado
        WHERE ree.Id_rol_empleado_evento = @Id_rol_empleado_evento;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Procedimiento para obtener asignaciones de empleados a eventos
CREATE OR ALTER PROCEDURE Administracion.GetAsignacionesEmpleadoEvento
(
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @Id_evento INT = NULL,
    @Id_empleado INT = NULL,
    @Id_rol INT = NULL,
    @TextFilter NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validar parámetros de paginación
        IF @PageNumber < 1
            THROW 50091, 'El número de página debe ser mayor o igual a 1.', 1;
        IF @PageSize < 1
            THROW 50092, 'El tamaño de página debe ser mayor o igual a 1.', 1;

        -- Validar filtros
        IF @Id_evento IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Operaciones.Eventos WHERE Id_evento = @Id_evento)
            THROW 50084, 'El evento especificado no existe.', 1;
        IF @Id_empleado IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Empleados WHERE Id_empleado = @Id_empleado)
            THROW 50085, 'El empleado especificado no existe.', 1;
        IF @Id_rol IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Administracion.Roles WHERE Id_rol = @Id_rol)
            THROW 50086, 'El rol especificado no existe.', 1;

        -- Obtener asignaciones con información detallada
        SELECT 
            ree.Id_rol_empleado_evento,
            ree.Id_evento,
            ree.Id_empleado,
            ree.Id_rol,
            e.Fecha_inicio,
            e.Hora_inicio,
            e.Hora_fin,
            e.Ubicacion,
            e.Estado AS Estado_evento,
            emp.Nombre + ' ' + emp.Apellido AS Nombre_empleado,
            emp.Telefono AS Telefono_empleado,
            emp.Email AS Email_empleado,
            r.Nombre_rol,
            es.Tipo_estado AS Estado_empleado,
            c.Nombre_cargo AS Cargo_empleado
        FROM Administracion.Rol_Empleado_Evento ree
        JOIN Operaciones.Eventos e ON ree.Id_evento = e.Id_evento
        JOIN Administracion.Empleados emp ON ree.Id_empleado = emp.Id_empleado
        JOIN Administracion.Roles r ON ree.Id_rol = r.Id_rol
        JOIN Administracion.Estado_Empleado es ON emp.Estado_Empleado = es.Id_estado
        LEFT JOIN Administracion.Usuarios u ON emp.Id_empleado = u.Id_empleado
        LEFT JOIN Administracion.Cargos c ON u.Id_Cargo = c.Id_cargo
        WHERE (@Id_evento IS NULL OR ree.Id_evento = @Id_evento)
          AND (@Id_empleado IS NULL OR ree.Id_empleado = @Id_empleado)
          AND (@Id_rol IS NULL OR ree.Id_rol = @Id_rol)
          AND (@TextFilter IS NULL OR 
               emp.Nombre LIKE '%' + @TextFilter + '%' OR 
               emp.Apellido LIKE '%' + @TextFilter + '%' OR
               r.Nombre_rol LIKE '%' + @TextFilter + '%' OR
               e.Ubicacion LIKE '%' + @TextFilter + '%')
        ORDER BY e.Fecha_inicio DESC, e.Hora_inicio ASC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Procedimiento para eliminar una asignación de empleado a evento
CREATE OR ALTER PROCEDURE Administracion.DeleteAsignacionEmpleadoEvento
(
    @Id_rol_empleado_evento INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que la asignación existe
        IF NOT EXISTS (SELECT 1 FROM Administracion.Rol_Empleado_Evento WHERE Id_rol_empleado_evento = @Id_rol_empleado_evento)
            THROW 50090, 'La asignación especificada no existe.', 1;

        -- Obtener información del empleado antes de eliminar
        DECLARE @Id_empleado INT;
        SELECT @Id_empleado = Id_empleado
        FROM Administracion.Rol_Empleado_Evento
        WHERE Id_rol_empleado_evento = @Id_rol_empleado_evento;

        -- Eliminar la asignación
        DELETE FROM Administracion.Rol_Empleado_Evento
        WHERE Id_rol_empleado_evento = @Id_rol_empleado_evento;

        -- Verificar si el empleado tiene otras asignaciones
        IF NOT EXISTS (
            SELECT 1 FROM Administracion.Rol_Empleado_Evento 
            WHERE Id_empleado = @Id_empleado
        )
        BEGIN
            -- Si no tiene otras asignaciones, cambiar su estado a "Disponible"
            UPDATE Administracion.Empleados
            SET Estado_Empleado = 2 -- Disponible
            WHERE Id_empleado = @Id_empleado;
        END;

        COMMIT TRANSACTION;

        -- Retornar confirmación
        SELECT 'Asignación eliminada exitosamente' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO

-- Procedimiento para obtener empleados disponibles para asignar a eventos
CREATE OR ALTER PROCEDURE Administracion.GetEmpleadosDisponibles
(
    @Fecha_evento DATE,
    @Id_evento INT = NULL, -- Para excluir empleados ya asignados a este evento
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @TextFilter NVARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Validar parámetros de paginación
        IF @PageNumber < 1
            THROW 50091, 'El número de página debe ser mayor o igual a 1.', 1;
        IF @PageSize < 1
            THROW 50092, 'El tamaño de página debe ser mayor o igual a 1.', 1;

        -- Obtener empleados disponibles (no asignados a eventos en la fecha especificada)
        SELECT 
            e.Id_empleado,
            e.Nombre,
            e.Apellido,
            e.Telefono,
            e.Email,
            es.Tipo_estado,
            c.Nombre_cargo,
            u.Nombre_usuario
        FROM Administracion.Empleados e
        JOIN Administracion.Estado_Empleado es ON e.Estado_Empleado = es.Id_estado
        LEFT JOIN Administracion.Usuarios u ON e.Id_empleado = u.Id_empleado
        LEFT JOIN Administracion.Cargos c ON u.Id_Cargo = c.Id_cargo
        WHERE e.Estado_Empleado IN (1, 2) -- Activo o Disponible
          AND e.Id_empleado NOT IN (
              -- Excluir empleados ya asignados a eventos en la fecha especificada
              SELECT DISTINCT ree.Id_empleado
              FROM Administracion.Rol_Empleado_Evento ree
              JOIN Operaciones.Eventos ev ON ree.Id_evento = ev.Id_evento
              WHERE ev.Fecha_inicio = @Fecha_evento
                AND (@Id_evento IS NULL OR ree.Id_evento != @Id_evento)
          )
          AND (@TextFilter IS NULL OR 
               e.Nombre LIKE '%' + @TextFilter + '%' OR 
               e.Apellido LIKE '%' + @TextFilter + '%' OR
               c.Nombre_cargo LIKE '%' + @TextFilter + '%')
        ORDER BY e.Nombre, e.Apellido
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        THROW 50000, @ErrorMessage, @ErrorState;
    END CATCH
END;
GO
