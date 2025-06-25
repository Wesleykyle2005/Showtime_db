--USE ShowtimeDB;
GO

-- Reordered DELETE statements to respect foreign key constraints
DELETE FROM Operaciones.Pagos;
DELETE FROM Administracion.Rol_Empleado_Evento;
DELETE FROM Operaciones.Evento_Servicios;
DELETE FROM Operaciones.Paquete_Servicios;
DELETE FROM Inventario.Servicio_Utileria;
DELETE FROM Operaciones.Eventos;
DELETE FROM Operaciones.Paquetes;
DELETE FROM Operaciones.Servicios;
DELETE FROM Inventario.Utileria;
DELETE FROM Operaciones.Clientes;
DELETE FROM Administracion.Usuarios;
DELETE FROM Administracion.Empleados;
DELETE FROM Administracion.Cargos;
DELETE FROM Administracion.Roles;
DELETE FROM Administracion.Estado_Empleado;
GO

-- Habilitar NOCOUNT para reducir mensajes
SET NOCOUNT ON;

-- Crear tabla Utileria si no existe
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Utileria' AND schema_id = SCHEMA_ID('Inventario'))
BEGIN
    CREATE TABLE Inventario.Utileria (
        Id_utileria INT IDENTITY(1,1) PRIMARY KEY,
        Nombre VARCHAR(100) NOT NULL,
        Cantidad INT,
        CONSTRAINT CHK_Cantidad_Positive CHECK (Cantidad >= 0)
    );
END

-- Crear tabla Servicio_Utileria si no existe
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Servicio_Utileria' AND schema_id = SCHEMA_ID('Inventario'))
BEGIN
    CREATE TABLE Inventario.Servicio_Utileria (
        Id_servicio_utileria INT IDENTITY(1,1) PRIMARY KEY,
        Id_servicio INT NOT NULL,
        Id_utileria INT NOT NULL,
        CONSTRAINT FK_Servicio_Utileria_Servicio FOREIGN KEY (Id_servicio) REFERENCES Operaciones.Servicios(Id_servicio),
        CONSTRAINT FK_Servicio_Utileria_Utileria FOREIGN KEY (Id_utileria) REFERENCES Inventario.Utileria(Id_utileria)
    );
END
GO

-- Crear tablas temporales f�sicas para mantener datos entre secciones
IF OBJECT_ID('tempdb..#Cargos') IS NOT NULL DROP TABLE #Cargos;
CREATE TABLE #Cargos (Id_cargo INT, Nombre_cargo NVARCHAR(100));

IF OBJECT_ID('tempdb..#Roles') IS NOT NULL DROP TABLE #Roles;
CREATE TABLE #Roles (Id_rol INT, Nombre_rol NVARCHAR(100));

IF OBJECT_ID('tempdb..#Empleados') IS NOT NULL DROP TABLE #Empleados;
CREATE TABLE #Empleados (Id_empleado INT, Nombre NVARCHAR(100), Apellido NVARCHAR(100));

IF OBJECT_ID('tempdb..#Servicios') IS NOT NULL DROP TABLE #Servicios;
CREATE TABLE #Servicios (Id_servicio INT, Nombre_servicio NVARCHAR(100));

IF OBJECT_ID('tempdb..#Paquetes') IS NOT NULL DROP TABLE #Paquetes;
CREATE TABLE #Paquetes (Id_paquete INT, Nombre_paquete NVARCHAR(100));

IF OBJECT_ID('tempdb..#Clientes') IS NOT NULL DROP TABLE #Clientes;
CREATE TABLE #Clientes (Id_cliente INT, Nombre NVARCHAR(100), Apellido NVARCHAR(100));

IF OBJECT_ID('tempdb..#Eventos') IS NOT NULL DROP TABLE #Eventos;
CREATE TABLE #Eventos (Id_evento INT);
GO

-- Asegurar que 'Activo' exista en Estado_Empleado
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    IF NOT EXISTS (SELECT 1 FROM Administracion.Estado_Empleado WHERE Tipo_estado = 'Activo')
    BEGIN
        INSERT INTO Administracion.Estado_Empleado (Tipo_estado) VALUES ('Activo');
    END

    -- Insertar tipos de estado adicionales
    IF NOT EXISTS (SELECT 1 FROM Administracion.Estado_Empleado WHERE Tipo_estado = 'Disponible')
        INSERT INTO Administracion.Estado_Empleado (Tipo_estado) VALUES ('Disponible');
    IF NOT EXISTS (SELECT 1 FROM Administracion.Estado_Empleado WHERE Tipo_estado = 'En evento')
        INSERT INTO Administracion.Estado_Empleado (Tipo_estado) VALUES ('En evento');
    IF NOT EXISTS (SELECT 1 FROM Administracion.Estado_Empleado WHERE Tipo_estado = 'Incapacidad laboral')
        INSERT INTO Administracion.Estado_Empleado (Tipo_estado) VALUES ('Incapacidad laboral');
    IF NOT EXISTS (SELECT 1 FROM Administracion.Estado_Empleado WHERE Tipo_estado = 'No disponible')
        INSERT INTO Administracion.Estado_Empleado (Tipo_estado) VALUES ('No disponible');
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar cargos usando AddCargo
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    INSERT INTO #Cargos (Id_cargo, Nombre_cargo)
    SELECT Id_cargo, Nombre_cargo
    FROM Administracion.Cargos
    WHERE Nombre_cargo IN ('Gerente', 'Bodeguero', 'Empleado', 'Recursos Humanos');

    IF NOT EXISTS (SELECT 1 FROM #Cargos WHERE Nombre_cargo = 'Gerente')
    BEGIN
        EXEC Administracion.AddCargo @Nombre_cargo = 'Gerente', @Descripci�n = 'Acceso completo al sistema.';
        INSERT INTO #Cargos SELECT Id_cargo, 'Gerente' FROM Administracion.Cargos WHERE Nombre_cargo = 'Gerente';
    END
    IF NOT EXISTS (SELECT 1 FROM #Cargos WHERE Nombre_cargo = 'Bodeguero')
    BEGIN
        EXEC Administracion.AddCargo @Nombre_cargo = 'Bodeguero', @Descripci�n = 'Acceso solo a administrar la utiler�a.';
        INSERT INTO #Cargos SELECT Id_cargo, 'Bodeguero' FROM Administracion.Cargos WHERE Nombre_cargo = 'Bodeguero';
    END
    IF NOT EXISTS (SELECT 1 FROM #Cargos WHERE Nombre_cargo = 'Empleado')
    BEGIN
        EXEC Administracion.AddCargo @Nombre_cargo = 'Empleado', @Descripci�n = 'Solo puede hacer registros de eventos, pagos y asignar empleados a eventos.';
        INSERT INTO #Cargos SELECT Id_cargo, 'Empleado' FROM Administracion.Cargos WHERE Nombre_cargo = 'Empleado';
    END
    IF NOT EXISTS (SELECT 1 FROM #Cargos WHERE Nombre_cargo = 'Recursos Humanos')
    BEGIN
        EXEC Administracion.AddCargo @Nombre_cargo = 'Recursos Humanos', @Descripci�n = 'Acceso a administrar clientes y empleados.';
        INSERT INTO #Cargos SELECT Id_cargo, 'Recursos Humanos' FROM Administracion.Cargos WHERE Nombre_cargo = 'Recursos Humanos';
    END
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar roles usando AddRol
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    INSERT INTO #Roles (Id_rol, Nombre_rol)
    SELECT Id_rol, Nombre_rol
    FROM Administracion.Roles
    WHERE Nombre_rol IN ('Decorador', 'Especialista en Iluminaci�n', 'DJ o M�sico', 'Fot�grafo/Vide�grafo', 
                         'Encargado de Catering', 'T�cnico de Sonido', 'Animadores', 'Botargueros', 'Administrador');

    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Decorador')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Decorador', @Descripcion = 'Encargado de dise�ar y montar la decoraci�n tem�tica del evento.';
        INSERT INTO #Roles SELECT Id_rol, 'Decorador' FROM Administracion.Roles WHERE Nombre_rol = 'Decorador';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Especialista en Iluminaci�n')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Especialista en Iluminaci�n', @Descripcion = 'Configura y supervisa las luces y efectos visuales del evento.';
        INSERT INTO #Roles SELECT Id_rol, 'Especialista en Iluminaci�n' FROM Administracion.Roles WHERE Nombre_rol = 'Especialista en Iluminaci�n';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'DJ o M�sico')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'DJ o M�sico', @Descripcion = 'Encargado de la m�sica y el entretenimiento durante el evento.';
        INSERT INTO #Roles SELECT Id_rol, 'DJ o M�sico' FROM Administracion.Roles WHERE Nombre_rol = 'DJ o M�sico';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Fot�grafo/Vide�grafo')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Fot�grafo/Vide�grafo', @Descripcion = 'Documenta el evento a trav�s de fotos y videos.';
        INSERT INTO #Roles SELECT Id_rol, 'Fot�grafo/Vide�grafo' FROM Administracion.Roles WHERE Nombre_rol = 'Fot�grafo/Vide�grafo';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Encargado de Catering')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Encargado de Catering', @Descripcion = 'Supervisa la preparaci�n y el servicio de alimentos y bebidas.';
        INSERT INTO #Roles SELECT Id_rol, 'Encargado de Catering' FROM Administracion.Roles WHERE Nombre_rol = 'Encargado de Catering';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'T�cnico de Sonido')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'T�cnico de Sonido', @Descripcion = 'Configura y opera los sistemas de audio para el evento.';
        INSERT INTO #Roles SELECT Id_rol, 'T�cnico de Sonido' FROM Administracion.Roles WHERE Nombre_rol = 'T�cnico de Sonido';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Animadores')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Animadores', @Descripcion = 'Encargados de entretener a los invitados con actividades tem�ticas y juegos.';
        INSERT INTO #Roles SELECT Id_rol, 'Animadores' FROM Administracion.Roles WHERE Nombre_rol = 'Animadores';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Botargueros')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Botargueros', @Descripcion = 'Personas que usan botargas o disfraces para animar eventos y captar la atenci�n de los asistentes.';
        INSERT INTO #Roles SELECT Id_rol, 'Botargueros' FROM Administracion.Roles WHERE Nombre_rol = 'Botargueros';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Administrador')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Administrador', @Descripcion = 'Supervisa el funcionamiento general de la empresa y la gesti�n de los eventos.';
        INSERT INTO #Roles SELECT Id_rol, 'Administrador' FROM Administracion.Roles WHERE Nombre_rol = 'Administrador';
    END
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar empleados usando AddEmpleado
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @Nombre NVARCHAR(100), @Apellido NVARCHAR(100), @Email NVARCHAR(100), @Phone NVARCHAR(20);
    DECLARE @Id_estado INT = (SELECT Id_estado FROM Administracion.Estado_Empleado WHERE Tipo_estado = 'Activo');
    DECLARE @Id_cargo INT, @Id_empleado INT;
    DECLARE @Nombre_usuario NVARCHAR(100);
    DECLARE @Contrase�a NVARCHAR(64);
    DECLARE @Cargo NVARCHAR(100);

    DECLARE @EmpleadoData TABLE (Nombre NVARCHAR(100), Apellido NVARCHAR(100), Cargo NVARCHAR(100));
    INSERT INTO @EmpleadoData (Nombre, Apellido, Cargo) VALUES
        ('Juan', 'P�rez', 'Gerente'), ('Mar�a', 'G�mez', 'Bodeguero'), ('Carlos', 'Ram�rez', 'Bodeguero'),
        ('Ana', 'Mart�nez', 'Gerente'), ('Luis', 'Hern�ndez', 'Bodeguero'), ('Sof�a', 'L�pez', 'Gerente'),
        ('Miguel', 'D�az', 'Bodeguero'), ('Elena', 'Fern�ndez', 'Bodeguero'), ('Diego', 'Torres', 'Bodeguero'),
        ('Valeria', 'Ortiz', 'Gerente'), ('Fernando', 'Castillo', 'Empleado'), ('Isabel', 'Vega', 'Empleado'),
        ('Andr�s', 'Moreno', 'Empleado'), ('Rosa', 'Jim�nez', 'Empleado'), ('Santiago', 'Dom�nguez', 'Recursos Humanos'),
        ('Clara', 'Fuentes', 'Recursos Humanos'), ('Javier', 'R�os', 'Recursos Humanos'), ('Natalia', 'Campos', 'Recursos Humanos'),
        ('Emilio', 'Garc�a', 'Recursos Humanos'), ('Patricia', 'Soto', 'Recursos Humanos');

    DECLARE emp_cursor CURSOR FOR SELECT Nombre, Apellido, Cargo FROM @EmpleadoData;
    OPEN emp_cursor;
    FETCH NEXT FROM emp_cursor INTO @Nombre, @Apellido, @Cargo;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Generar correo y tel�fono �nicos
        EXEC Operaciones.GenerateUniqueContactInfo 
            @Nombre = @Nombre, 
            @Apellido = @Apellido, 
            @Email = @Email OUTPUT, 
            @Phone = @Phone OUTPUT;

        -- Obtener Id_cargo desde #Cargos usando el nombre del cargo
        SELECT @Id_cargo = Id_cargo FROM #Cargos WHERE Nombre_cargo = @Cargo;

        -- Generar nombre de usuario y contrase�a
        SET @Nombre_usuario = LOWER(CONCAT(@Nombre, '.', REPLACE(@Apellido, ' ', '')));
        SET @Contrase�a = CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT('password', @Nombre, @Apellido)), 2);

        -- Insertar empleado
        EXEC Administracion.AddEmpleado 
            @Nombre = @Nombre, 
            @Apellido = @Apellido, 
            @Telefono = @Phone, 
            @Email = @Email, 
            @Estado_Empleado = @Id_estado, 
            @Nombre_usuario = @Nombre_usuario, 
            @Contrase�a = @Contrase�a, 
            @Id_Cargo = @Id_cargo;

        -- Almacenar Id_empleado
        INSERT INTO #Empleados
        SELECT Id_empleado, @Nombre, @Apellido
        FROM Administracion.Empleados
        WHERE Email = @Email;

        FETCH NEXT FROM emp_cursor INTO @Nombre, @Apellido, @Cargo;
    END
    CLOSE emp_cursor;
    DEALLOCATE emp_cursor;

    -- Insertar usuario Admin
    SELECT @Id_cargo = Id_cargo FROM #Cargos WHERE Nombre_cargo = 'Gerente';
    SELECT @Id_empleado = Id_empleado, @Nombre = Nombre, @Apellido = Apellido
    FROM #Empleados
    WHERE Nombre = 'Patricia' AND Apellido = 'Soto';

    SET @Email = 'admin@example.com';
    SET @Phone = '9999999999';
    SET @Nombre_usuario = 'Admin';
    SET @Contrase�a = CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', '12345678'), 2);

    IF NOT EXISTS (SELECT 1 FROM Administracion.Usuarios WHERE Nombre_usuario = 'Admin')
    BEGIN
        EXEC Administracion.AddEmpleado 
            @Nombre = @Nombre, 
            @Apellido = @Apellido, 
            @Telefono = @Phone, 
            @Email = @Email, 
            @Estado_Empleado = @Id_estado, 
            @Nombre_usuario = @Nombre_usuario, 
            @Contrase�a = @Contrase�a, 
            @Id_Cargo = @Id_cargo;
    END
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar utiler�a (sin procedimiento, usar INSERT)
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    INSERT INTO Inventario.Utileria (Nombre, Cantidad)
    SELECT Nombre, Cantidad
    FROM (VALUES
        ('Traje de Barney', 3), ('Traje de Baby Bop', 3), ('Traje de BJ', 3),
        ('Traje de Peppa Pig', 3), ('Traje de George Pig', 3), ('Traje de Mam� Pig', 3),
        ('Traje de Pablo', 3), ('Traje de Tyrone', 3), ('Traje de Uniqua', 3),
        ('Traje de Ladybug', 3), ('Traje de Cat Noir', 3), ('Traje de Hawk Moth', 3),
        ('Traje de Chase', 3), ('Traje de Marshall', 3), ('Traje de Skye', 3),
        ('Traje de Elsa', 3), ('Traje de Anna', 3), ('Traje de Olaf', 3),
        ('Traje de Scooby-Doo', 3), ('Traje de Shaggy', 3), ('Traje de Daphne', 3),
        ('Traje de Rayo McQueen', 3), ('Traje de Mate', 3), ('Traje de Sally', 3),
        ('Traje de Mickey Mouse', 3), ('Traje de Minnie Mouse', 3), ('Traje de Donald Duck', 3),
        ('Traje de Kevin', 3), ('Traje de Stuart', 3), ('Traje de Bob', 3),
        ('Traje de Bob Esponja', 3), ('Traje de Patricio', 3), ('Traje de Calamardo', 3),
        ('Traje de Elmo', 3), ('Traje de Cookie Monster', 3), ('Traje de Big Bird', 3),
        ('Traje de Woody', 3), ('Traje de Buzz Lightyear', 3), ('Traje de Jessie', 3),
        ('Traje de Mario', 3), ('Traje de Luigi', 3), ('Traje de Bowser', 3),
        ('Traje de Pikachu', 3), ('Traje de Ash', 3), ('Traje de Misty', 3),
        ('Altavoz', 10), ('Micr�fono', 10), ('Mesa de mezclas', 5), ('Cables de audio', 30),
        ('Silla plegable decorada', 200), ('Fundas de sillas', 200), ('Cintas decorativas', 200), ('Cojines adicionales', 50),
        ('Mesa redonda', 40), ('Mantel tem�tico', 40), ('Centros de mesa tem�ticos', 40), ('Cubiertos y platos', 200),
        ('Calentadores de alimentos', 10), ('Bandejas para servir', 30), ('Jarras de bebidas', 30), ('Cucharones y pinzas', 20),
        ('Luces LED', 30), ('Reflectores', 10), ('Panel de control de iluminaci�n', 2), ('Soportes de luces', 15)
    ) AS u(Nombre, Cantidad)
    WHERE NOT EXISTS (
        SELECT 1 FROM Inventario.Utileria WHERE Nombre = u.Nombre
    );
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar servicios usando AddServicio
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @Nombre_servicio NVARCHAR(100), @Descripcion NVARCHAR(500), @Costo DECIMAL(18,2), @UtileriaIds NVARCHAR(MAX);

    INSERT INTO #Servicios (Id_servicio, Nombre_servicio)
    SELECT Id_servicio, Nombre_servicio
    FROM Operaciones.Servicios
    WHERE Nombre_servicio IN (
        'Animacion_Barney', 'Animacion_PeppaPig', 'Animacion_Backyardigans', 'Animacion_Miraculous', 'Animacion_PawPatrol',
        'Animacion_Frozen', 'Animacion_ScoobyDoo', 'Animacion_Cars', 'Animacion_MickeyMouse', 'Animacion_Minion',
        'Animacion_SpongeBob', 'Animacion_SesameStreet', 'Animacion_ToyStory', 'Animacion_SuperMario', 'Animacion_Pokemon',
        'Servicio_Sonido', 'Servicio_Sillas', 'Servicio_Mesas', 'Servicio_Alimentos', 'Servicio_Iluminacion'
    );

    DECLARE @ServicioData TABLE (Nombre_servicio NVARCHAR(100), Descripcion NVARCHAR(500), Costo DECIMAL(18,2), UtileriaIds NVARCHAR(MAX));
    INSERT INTO @ServicioData (Nombre_servicio, Descripcion, Costo, UtileriaIds)
    VALUES
        ('Animacion_Barney', 'Animaci�n tem�tica con el personaje de Barney.', 1500.00, NULL),
        ('Animacion_PeppaPig', 'Animaci�n tem�tica con el personaje de Peppa Pig.', 1400.00, NULL),
        ('Animacion_Backyardigans', 'Animaci�n tem�tica con los personajes de Backyardigans.', 1450.00, NULL),
        ('Animacion_Miraculous', 'Animaci�n tem�tica con Ladybug y Cat Noir.', 1600.00, NULL),
        ('Animacion_PawPatrol', 'Animaci�n tem�tica con los cachorros de Paw Patrol.', 1500.00, NULL),
        ('Animacion_Frozen', 'Animaci�n tem�tica con Elsa, Anna y Olaf.', 1700.00, NULL),
        ('Animacion_ScoobyDoo', 'Animaci�n tem�tica con Scooby-Doo y sus amigos.', 1550.00, NULL),
        ('Animacion_Cars', 'Animaci�n tem�tica con los personajes de Cars.', 1400.00, NULL),
        ('Animacion_MickeyMouse', 'Animaci�n tem�tica con Mickey Mouse y sus amigos.', 1500.00, NULL),
        ('Animacion_Minion', 'Animaci�n tem�tica con los Minions.', 1400.00, NULL),
        ('Animacion_SpongeBob', 'Animaci�n tem�tica con Bob Esponja y sus amigos.', 1500.00, NULL),
        ('Animacion_SesameStreet', 'Animaci�n tem�tica con los personajes de Plaza S�samo.', 1450.00, NULL),
        ('Animacion_ToyStory', 'Animaci�n tem�tica con Woody, Buzz y amigos.', 1600.00, NULL),
        ('Animacion_SuperMario', 'Animaci�n tem�tica con Mario, Luigi y compa��a.', 1550.00, NULL),
        ('Animacion_Pokemon', 'Animaci�n tem�tica con Ash, Pikachu y amigos.', 1500.00, NULL),
        ('Servicio_Sonido', 'Equipo de sonido para m�sica y presentaciones.', 2000.00, NULL),
        ('Servicio_Sillas', 'Renta de sillas decoradas seg�n la tem�tica.', 1000.00, NULL),
        ('Servicio_Mesas', 'Renta de mesas decoradas para la ocasi�n.', 1200.00, NULL),
        ('Servicio_Alimentos', 'Servicio de alimentos y bebidas tem�ticos.', 3000.00, NULL),
        ('Servicio_Iluminacion', 'Iluminaci�n especial seg�n la tem�tica.', 1800.00, NULL);

    DECLARE svc_cursor CURSOR FOR SELECT Nombre_servicio, Descripcion, Costo, UtileriaIds FROM @ServicioData;
    OPEN svc_cursor;
    FETCH NEXT FROM svc_cursor INTO @Nombre_servicio, @Descripcion, @Costo, @UtileriaIds;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM #Servicios WHERE Nombre_servicio = @Nombre_servicio)
        BEGIN
            EXEC Operaciones.AddServicio 
                @Nombre_servicio = @Nombre_servicio, 
                @Descripcion = @Descripcion, 
                @Costo = @Costo, 
                @UtileriaIds = @UtileriaIds;

            INSERT INTO #Servicios
            SELECT Id_servicio, @Nombre_servicio
            FROM Operaciones.Servicios
            WHERE Nombre_servicio = @Nombre_servicio;
        END
        FETCH NEXT FROM svc_cursor INTO @Nombre_servicio, @Descripcion, @Costo, @UtileriaIds;
    END
    CLOSE svc_cursor;
    DEALLOCATE svc_cursor;
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar relaci�n servicio-utiler�a (sin procedimiento, usar INSERT)
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    INSERT INTO Inventario.Servicio_Utileria (Id_servicio, Id_utileria)
    SELECT s.Id_servicio, u.Id_utileria
    FROM Operaciones.Servicios s
    JOIN Inventario.Utileria u ON s.Nombre_servicio + '_' + u.Nombre IN (
        SELECT CONCAT(s2.Nombre_servicio, '_', u2.Nombre)
        FROM (VALUES
            ('Animacion_Barney', 'Traje de Barney'), ('Animacion_Barney', 'Traje de Baby Bop'), ('Animacion_Barney', 'Traje de BJ'),
            ('Animacion_PeppaPig', 'Traje de Peppa Pig'), ('Animacion_PeppaPig', 'Traje de George Pig'), ('Animacion_PeppaPig', 'Traje de Mam� Pig'),
            ('Animacion_Backyardigans', 'Traje de Pablo'), ('Animacion_Backyardigans', 'Traje de Tyrone'), ('Animacion_Backyardigans', 'Traje de Uniqua'),
            ('Animacion_Miraculous', 'Traje de Ladybug'), ('Animacion_Miraculous', 'Traje de Cat Noir'), ('Animacion_Miraculous', 'Traje de Hawk Moth'),
            ('Animacion_PawPatrol', 'Traje de Chase'), ('Animacion_PawPatrol', 'Traje de Marshall'), ('Animacion_PawPatrol', 'Traje de Skye'),
            ('Animacion_Frozen', 'Traje de Elsa'), ('Animacion_Frozen', 'Traje de Anna'), ('Animacion_Frozen', 'Traje de Olaf'),
            ('Animacion_ScoobyDoo', 'Traje de Scooby-Doo'), ('Animacion_ScoobyDoo', 'Traje de Shaggy'), ('Animacion_ScoobyDoo', 'Traje de Daphne'),
            ('Animacion_Cars', 'Traje de Rayo McQueen'), ('Animacion_Cars', 'Traje de Mate'), ('Animacion_Cars', 'Traje de Sally'),
            ('Animacion_MickeyMouse', 'Traje de Mickey Mouse'), ('Animacion_MickeyMouse', 'Traje de Minnie Mouse'), ('Animacion_MickeyMouse', 'Traje de Donald Duck'),
            ('Animacion_Minion', 'Traje de Kevin'), ('Animacion_Minion', 'Traje de Stuart'), ('Animacion_Minion', 'Traje de Bob'),
            ('Animacion_SpongeBob', 'Traje de Bob Esponja'), ('Animacion_SpongeBob', 'Traje de Patricio'), ('Animacion_SpongeBob', 'Traje de Calamardo'),
            ('Animacion_SesameStreet', 'Traje de Elmo'), ('Animacion_SesameStreet', 'Traje de Cookie Monster'), ('Animacion_SesameStreet', 'Traje de Big Bird'),
            ('Animacion_ToyStory', 'Traje de Woody'), ('Animacion_ToyStory', 'Traje de Buzz Lightyear'), ('Animacion_ToyStory', 'Traje de Jessie'),
            ('Animacion_SuperMario', 'Traje de Mario'), ('Animacion_SuperMario', 'Traje de Luigi'), ('Animacion_SuperMario', 'Traje de Bowser'),
            ('Animacion_Pokemon', 'Traje de Pikachu'), ('Animacion_Pokemon', 'Traje de Ash'), ('Animacion_Pokemon', 'Traje de Misty'),
            ('Servicio_Sonido', 'Altavoz'), ('Servicio_Sonido', 'Micr�fono'), ('Servicio_Sonido', 'Mesa de mezclas'), ('Servicio_Sonido', 'Cables de audio'),
            ('Servicio_Sillas', 'Silla plegable decorada'), ('Servicio_Sillas', 'Fundas de sillas'), ('Servicio_Sillas', 'Cintas decorativas'), ('Servicio_Sillas', 'Cojines adicionales'),
            ('Servicio_Mesas', 'Mesa redonda'), ('Servicio_Mesas', 'Mantel tem�tico'), ('Servicio_Mesas', 'Centros de mesa tem�ticos'), ('Servicio_Mesas', 'Cubiertos y platos'),
            ('Servicio_Alimentos', 'Calentadores de alimentos'), ('Servicio_Alimentos', 'Bandejas para servir'), ('Servicio_Alimentos', 'Jarras de bebidas'), ('Servicio_Alimentos', 'Cucharones y pinzas'),
            ('Servicio_Iluminacion', 'Luces LED'), ('Servicio_Iluminacion', 'Reflectores'), ('Servicio_Iluminacion', 'Panel de control de iluminaci�n'), ('Servicio_Iluminacion', 'Soportes de luces')
        ) AS su(Nombre_servicio, Nombre)
        JOIN Operaciones.Servicios s2 ON s2.Nombre_servicio = su.Nombre_servicio
        JOIN Inventario.Utileria u2 ON u2.Nombre = su.Nombre
    )
    WHERE NOT EXISTS (
        SELECT 1 FROM Inventario.Servicio_Utileria su
        WHERE su.Id_servicio = s.Id_servicio AND su.Id_utileria = u.Id_utileria
    );
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar paquetes usando AddPaquete
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @Nombre_paquete NVARCHAR(100), @Descripcion NVARCHAR(500), @Cantidad INT, @Disponibilidad BIT, @Costo DECIMAL(18,2), @ServicioIds NVARCHAR(MAX);

    INSERT INTO #Paquetes (Id_paquete, Nombre_paquete)
    SELECT Id_paquete, Nombre_paquete
    FROM Operaciones.Paquetes
    WHERE Nombre_paquete IN (
        'Paquete_Barney', 'Paquete_PeppaPig', 'Paquete_Backyardigans', 'Paquete_Miraculous', 'Paquete_PawPatrol',
        'Paquete_Frozen', 'Paquete_ScoobyDoo', 'Paquete_Cars', 'Paquete_MickeyMouse', 'Paquete_Minion',
        'Paquete_SpongeBob', 'Paquete_SesameStreet', 'Paquete_ToyStory', 'Paquete_SuperMario', 'Paquete_Pokemon'
    );

    DECLARE @PaqueteData TABLE (Nombre_paquete NVARCHAR(100), Descripcion NVARCHAR(500), Cantidad INT, Disponibilidad BIT, Costo DECIMAL(18,2), ServicioIds NVARCHAR(MAX));
    INSERT INTO @PaqueteData (Nombre_paquete, Descripcion, Cantidad, Disponibilidad, Costo, ServicioIds)
    SELECT 
        Nombre_paquete, 
        Descripcion, 
        Cantidad, 
        Disponibilidad, 
        Costo,
        STUFF((
            SELECT ',' + CAST(s.Id_servicio AS NVARCHAR(10))
            FROM #Servicios s
            WHERE s.Nombre_servicio IN (
                CASE p.Nombre_paquete
                    WHEN 'Paquete_Barney' THEN 'Animacion_Barney'
                    WHEN 'Paquete_PeppaPig' THEN 'Animacion_PeppaPig'
                    WHEN 'Paquete_Backyardigans' THEN 'Animacion_Backyardigans'
                    WHEN 'Paquete_Miraculous' THEN 'Animacion_Miraculous'
                    WHEN 'Paquete_PawPatrol' THEN 'Animacion_PawPatrol'
                    WHEN 'Paquete_Frozen' THEN 'Animacion_Frozen'
                    WHEN 'Paquete_ScoobyDoo' THEN 'Animacion_ScoobyDoo'
                    WHEN 'Paquete_Cars' THEN 'Animacion_Cars'
                    WHEN 'Paquete_MickeyMouse' THEN 'Animacion_MickeyMouse'
                    WHEN 'Paquete_Minion' THEN 'Animacion_Minion'
                    WHEN 'Paquete_SpongeBob' THEN 'Animacion_SpongeBob'
                    WHEN 'Paquete_SesameStreet' THEN 'Animacion_SesameStreet'
                    WHEN 'Paquete_ToyStory' THEN 'Animacion_ToyStory'
                    WHEN 'Paquete_SuperMario' THEN 'Animacion_SuperMario'
                    WHEN 'Paquete_Pokemon' THEN 'Animacion_Pokemon'
                END,
                'Servicio_Sonido', 'Servicio_Sillas', 'Servicio_Mesas', 'Servicio_Alimentos', 'Servicio_Iluminacion'
            )
            FOR XML PATH('')
        ), 1, 1, '') AS ServicioIds
    FROM (VALUES
        ('Paquete_Barney', 'Un show tem�tico de Barney con m�sica, decoraci�n y animaci�n.', 3, 1, 5000.00),
        ('Paquete_PeppaPig', 'Espect�culo basado en Peppa Pig con juegos, decoraci�n y animaci�n.', 3, 1, 4500.00),
        ('Paquete_Backyardigans', 'Fiesta con tem�tica de Backyardigans y actividades interactivas.', 3, 1, 4700.00),
        ('Paquete_Miraculous', 'Evento tem�tico de Ladybug y Cat Noir con juegos y m�sica.', 3, 1, 5200.00),
        ('Paquete_PawPatrol', 'Celebraci�n con tem�tica de Paw Patrol, personajes y animaci�n.', 3, 1, 4800.00),
        ('Paquete_Frozen', 'Show tem�tico de Frozen con canciones y decoraci�n invernal.', 3, 1, 5500.00),
        ('Paquete_ScoobyDoo', 'Fiesta con tem�tica de Scooby-Doo, misterios y diversi�n.', 3, 1, 4900.00),
        ('Paquete_Cars', 'Celebraci�n inspirada en Cars, con juegos y decoraci�n automovil�stica.', 3, 1, 4600.00),
        ('Paquete_MickeyMouse', 'Espect�culo basado en Mickey Mouse y sus amigos.', 3, 1, 5100.00),
        ('Paquete_Minion', 'Fiesta con tem�tica de Minions, juegos y disfraces.', 3, 1, 4800.00),
        ('Paquete_SpongeBob', 'Evento tem�tico de Bob Esponja con actividades acu�ticas y animaci�n.', 3, 1, 5300.00),
        ('Paquete_SesameStreet', 'Celebraci�n con personajes de Plaza S�samo, decoraci�n y actividades.', 3, 1, 4700.00),
        ('Paquete_ToyStory', 'Fiesta con Woody, Buzz y m�s personajes de Toy Story.', 3, 1, 5400.00),
        ('Paquete_SuperMario', 'Evento con tem�tica de Mario Bros, juegos y desaf�os interactivos.', 3, 1, 5000.00),
        ('Paquete_Pokemon', 'Celebraci�n tem�tica de Pok�mon, con animaci�n y juegos creativos.', 3, 1, 5200.00)
    ) AS p(Nombre_paquete, Descripcion, Cantidad, Disponibilidad, Costo);

    DECLARE pkg_cursor CURSOR FOR SELECT Nombre_paquete, Descripcion, Cantidad, Disponibilidad, Costo, ServicioIds FROM @PaqueteData;
    OPEN pkg_cursor;
    FETCH NEXT FROM pkg_cursor INTO @Nombre_paquete, @Descripcion, @Cantidad, @Disponibilidad, @Costo, @ServicioIds;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM #Paquetes WHERE Nombre_paquete = @Nombre_paquete)
        BEGIN
            EXEC Operaciones.AddPaquete 
                @Nombre_paquete = @Nombre_paquete, 
                @Descripcion = @Descripcion, 
                @Cantidad = @Cantidad, 
                @Disponibilidad = @Disponibilidad, 
                @Costo = @Costo, 
                @ServicioIds = @ServicioIds;

            INSERT INTO #Paquetes
            SELECT Id_paquete, @Nombre_paquete
            FROM Operaciones.Paquetes
            WHERE Nombre_paquete = @Nombre_paquete;
        END
        FETCH NEXT FROM pkg_cursor INTO @Nombre_paquete, @Descripcion, @Cantidad, @Disponibilidad, @Costo, @ServicioIds;
    END
    CLOSE pkg_cursor;
    DEALLOCATE pkg_cursor;
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar clientes usando AddCliente
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @Nombre NVARCHAR(100), @Apellido NVARCHAR(100), @Email NVARCHAR(100), @Phone NVARCHAR(20);

    DECLARE @ClienteData TABLE (Nombre NVARCHAR(100), Apellido NVARCHAR(100));
    INSERT INTO @ClienteData (Nombre, Apellido) VALUES
        ('Juan', 'P�rez'), ('Ana', 'L�pez'), ('Carlos', 'Mart�nez'), ('Mar�a', 'Gonz�lez'), ('Pedro', 'Hern�ndez'),
        ('Luc�a', 'Rodr�guez'), ('Jorge', 'S�nchez'), ('Laura', 'Ram�rez'), ('David', 'Torres'), ('Elena', 'V�zquez');

    DECLARE cli_cursor CURSOR FOR SELECT Nombre, Apellido FROM @ClienteData;
    OPEN cli_cursor;
    FETCH NEXT FROM cli_cursor INTO @Nombre, @Apellido;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC Operaciones.GenerateUniqueContactInfo 
            @Nombre = @Nombre, 
            @Apellido = @Apellido, 
            @Email = @Email OUTPUT, 
            @Phone = @Phone OUTPUT;

        IF NOT EXISTS (SELECT 1 FROM Operaciones.Clientes WHERE Correo_electronico = @Email)
        BEGIN
            EXEC Operaciones.AddCliente 
                @Nombre = @Nombre, 
                @Apellido = @Apellido, 
                @Telefono = @Phone, 
                @Correo_electronico = @Email;

            INSERT INTO #Clientes
            SELECT Id_cliente, @Nombre, @Apellido
            FROM Operaciones.Clientes
            WHERE Correo_electronico = @Email;
        END
        FETCH NEXT FROM cli_cursor INTO @Nombre, @Apellido;
    END
    CLOSE cli_cursor;
    DEALLOCATE cli_cursor;
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar eventos usando AddEvento
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @Nombre_paquete NVARCHAR(100), @Nombre NVARCHAR(100), @Apellido NVARCHAR(100);
    DECLARE @Id_paquete INT, @Id_cliente INT;
    DECLARE @Fecha_reserva DATE, @Fecha_inicio DATE, @Hora_inicio TIME, @Hora_fin TIME;
    DECLARE @Ubicacion NVARCHAR(100), @Direccion NVARCHAR(200), @Cantidad_de_asistentes INT;
    DECLARE @Detalles_adicionales NVARCHAR(500), @Costo_total DECIMAL(18,2), @Estado NVARCHAR(50), @ServicioIds NVARCHAR(MAX);

    DECLARE @EventoData TABLE (Nombre_paquete NVARCHAR(100), Nombre NVARCHAR(100), Apellido NVARCHAR(100), 
                              Fecha_reserva DATE, Fecha_inicio DATE, Hora_inicio TIME, Hora_fin TIME, 
                              Ubicacion NVARCHAR(100), Direccion NVARCHAR(200), Cantidad_de_asistentes INT, 
                              Detalles_adicionales NVARCHAR(500), Costo_total DECIMAL(18,2), Estado NVARCHAR(50), 
                              ServicioIds NVARCHAR(MAX));
    INSERT INTO @EventoData 
    SELECT 
        Nombre_paquete, Nombre, Apellido, Fecha_reserva, Fecha_inicio, Hora_inicio, Hora_fin, Ubicacion, Direccion,
        Cantidad_de_asistentes, Detalles_adicionales, Costo_total, Estado,
        STUFF((
            SELECT ',' + CAST(s.Id_servicio AS NVARCHAR(10))
            FROM #Servicios s
            WHERE s.Nombre_servicio IN (
                CASE Nombre_paquete
                    WHEN 'Paquete_Barney' THEN 'Animacion_Barney'
                    WHEN 'Paquete_PeppaPig' THEN 'Animacion_PeppaPig'
                    WHEN 'Paquete_Backyardigans' THEN 'Animacion_Backyardigans'
                    WHEN 'Paquete_Miraculous' THEN 'Animacion_Miraculous'
                    WHEN 'Paquete_PawPatrol' THEN 'Animacion_PawPatrol'
                    WHEN 'Paquete_Frozen' THEN 'Animacion_Frozen'
                    WHEN 'Paquete_ScoobyDoo' THEN 'Animacion_ScoobyDoo'
                    WHEN 'Paquete_Cars' THEN 'Animacion_Cars'
                    WHEN 'Paquete_MickeyMouse' THEN 'Animacion_MickeyMouse'
                    WHEN 'Paquete_Minion' THEN 'Animacion_Minion'
                    WHEN 'Paquete_SpongeBob' THEN 'Animacion_SpongeBob'
                    WHEN 'Paquete_SesameStreet' THEN 'Animacion_SesameStreet'
                    WHEN 'Paquete_ToyStory' THEN 'Animacion_ToyStory'
                    WHEN 'Paquete_SuperMario' THEN 'Animacion_SuperMario'
                    WHEN 'Paquete_Pokemon' THEN 'Animacion_Pokemon'
                END,
                'Servicio_Sonido', 'Servicio_Sillas', 'Servicio_Mesas', 'Servicio_Alimentos', 'Servicio_Iluminacion'
            )
            FOR XML PATH('')
        ), 1, 1, '') AS ServicioIds
    FROM (VALUES
        ('Paquete_Barney', 'Juan', 'P�rez', CAST(GETDATE() AS DATE), DATEADD(DAY, 30, GETDATE()), '18:00:00', '22:00:00', 'Managua', 'Calle principal #1, Barrio central, Managua', 70, 'Detalles del evento #1', 5000.00, 'Pendiente'),
        ('Paquete_Cars', 'Luc�a', 'Rodr�guez', DATEADD(DAY, 3, GETDATE()), DATEADD(DAY, 33, GETDATE()), '08:00:00', '12:00:00', 'Rivas', 'Calle principal #2, Barrio central, Rivas', 41, 'Detalles del evento #2', 4600.00, 'Pendiente'),
        ('Paquete_Cars', 'Mar�a', 'Gonz�lez', DATEADD(DAY, 5, GETDATE()), DATEADD(DAY, 35, GETDATE()), '08:00:00', '12:00:00', 'Jinotega', 'Calle principal #3, Barrio central, Jinotega', 56, 'Detalles del evento #3', 4600.00, 'Pendiente'),
        ('Paquete_MickeyMouse', 'Elena', 'V�zquez', DATEADD(DAY, 7, GETDATE()), DATEADD(DAY, 37, GETDATE()), '11:00:00', '15:00:00', 'Madriz', 'Calle principal #4, Barrio central, Madriz', 78, 'Detalles del evento #4', 5100.00, 'Pendiente'),
        ('Paquete_PeppaPig', 'Pedro', 'Hern�ndez', CAST(GETDATE() AS DATE), DATEADD(DAY, 30, GETDATE()), '20:00:00', '23:00:00', 'R�o San Juan', 'Calle principal #5, Barrio central, R�o San Juan', 58, 'Detalles del evento #5', 4500.00, 'Pendiente'),
        ('Paquete_PeppaPig', 'Mar�a', 'Gonz�lez', DATEADD(DAY, 2, GETDATE()), DATEADD(DAY, 32, GETDATE()), '20:00:00', '22:00:00', 'Boaco', 'Calle principal #6, Barrio central, Boaco', 59, 'Detalles del evento #6', 4500.00, 'Pendiente'),
        ('Paquete_SuperMario', 'Luc�a', 'Rodr�guez', DATEADD(DAY, -3, GETDATE()), DATEADD(DAY, 27, GETDATE()), '14:00:00', '18:00:00', 'R�o San Juan', 'Calle principal #7, Barrio central, R�o San Juan', 57, 'Detalles del evento #7', 5000.00, 'Pendiente'),
        ('Paquete_ToyStory', 'Elena', 'V�zquez', CAST(GETDATE() AS DATE), DATEADD(DAY, 30, GETDATE()), '18:00:00', '22:00:00', 'Madriz', 'Calle principal #8, Barrio central, Madriz', 23, 'Detalles del evento #8', 5400.00, 'Pendiente'),
        ('Paquete_ScoobyDoo', 'Luc�a', 'Rodr�guez', DATEADD(DAY, 6, GETDATE()), DATEADD(DAY, 36, GETDATE()), '19:00:00', '23:00:00', 'Rivas', 'Calle principal #9, Barrio central, Rivas', 73, 'Detalles del evento #9', 4900.00, 'Pendiente'),
        ('Paquete_Miraculous', 'Laura', 'Ram�rez', DATEADD(DAY, 2, GETDATE()), DATEADD(DAY, 32, GETDATE()), '09:00:00', '13:00:00', 'Estel�', 'Calle principal #10, Barrio central, Estel�', 28, 'Detalles del evento #10', 5200.00, 'Pendiente'),
        ('Paquete_Barney', 'Ana', 'L�pez', DATEADD(DAY, -3, GETDATE()), DATEADD(DAY, 27, GETDATE()), '20:00:00', '22:00:00', 'Madriz', 'Calle principal #11, Barrio central, Madriz', 53, 'Detalles del evento #11', 5000.00, 'Pendiente'),
        ('Paquete_SesameStreet', 'Juan', 'P�rez', DATEADD(DAY, 1, GETDATE()), DATEADD(DAY, 31, GETDATE()), '10:00:00', '14:00:00', 'Chinandega', 'Calle principal #12, Barrio central, Chinandega', 82, 'Detalles del evento #12', 4700.00, 'Pendiente')
    ) AS e(Nombre_paquete, Nombre, Apellido, Fecha_reserva, Fecha_inicio, Hora_inicio, Hora_fin, Ubicacion, Direccion, Cantidad_de_asistentes, Detalles_adicionales, Costo_total, Estado);

    DECLARE evt_cursor CURSOR FOR SELECT Nombre_paquete, Nombre, Apellido, Fecha_reserva, Fecha_inicio, Hora_inicio, Hora_fin, Ubicacion, Direccion, Cantidad_de_asistentes, Detalles_adicionales, Costo_total, Estado, ServicioIds FROM @EventoData;
    OPEN evt_cursor;
    FETCH NEXT FROM evt_cursor INTO @Nombre_paquete, @Nombre, @Apellido, @Fecha_reserva, @Fecha_inicio, @Hora_inicio, @Hora_fin, @Ubicacion, @Direccion, @Cantidad_de_asistentes, @Detalles_adicionales, @Costo_total, @Estado, @ServicioIds;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @Id_paquete = Id_paquete FROM #Paquetes WHERE Nombre_paquete = @Nombre_paquete;
        SELECT @Id_cliente = Id_cliente FROM #Clientes WHERE Nombre = @Nombre AND Apellido = @Apellido;

        IF @Id_paquete IS NOT NULL AND @Id_cliente IS NOT NULL
        BEGIN
            EXEC Operaciones.AddEvento 
                @Id_paquete = @Id_paquete,
                @Id_cliente = @Id_cliente,
                @Fecha_reserva = @Fecha_reserva,
                @Fecha_inicio = @Fecha_inicio,
                @Hora_inicio = @Hora_inicio,
                @Hora_fin = @Hora_fin,
                @Ubicacion = @Ubicacion,
                @Direccion = @Direccion,
                @Cantidad_de_asistentes = @Cantidad_de_asistentes,
                @Detalles_adicionales = @Detalles_adicionales,
                @Costo_total = @Costo_total,
                @Estado = @Estado,
                @ServicioIds = @ServicioIds;

            INSERT INTO #Eventos
            SELECT Id_evento
            FROM Operaciones.Eventos
            WHERE Id_paquete = @Id_paquete AND Id_cliente = @Id_cliente AND Fecha_inicio = @Fecha_inicio;
        END
        FETCH NEXT FROM evt_cursor INTO @Nombre_paquete, @Nombre, @Apellido, @Fecha_reserva, @Fecha_inicio, @Hora_inicio, @Hora_fin, @Ubicacion, @Direccion, @Cantidad_de_asistentes, @Detalles_adicionales, @Costo_total, @Estado, @ServicioIds;
    END
    CLOSE evt_cursor;
    DEALLOCATE evt_cursor;
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar pagos usando AddPago
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @Evento_Idx INT, @Monto DECIMAL(18,2), @Fecha_pago DATE, @Metodo_pago NVARCHAR(50);
    DECLARE @Id_evento INT;

    DECLARE @PagoData TABLE (Evento_Idx INT, Monto DECIMAL(18,2), Fecha_pago DATE, Metodo_pago NVARCHAR(50));
    INSERT INTO @PagoData (Evento_Idx, Monto, Fecha_pago, Metodo_pago)
    VALUES
        (1, 2500.00, DATEADD(DAY, 10, GETDATE()), 'Efectivo'),
        (2, 2300.00, DATEADD(DAY, 11, GETDATE()), 'Efectivo'),
        (3, 2300.00, DATEADD(DAY, 12, GETDATE()), 'Efectivo'),
        (4, 2550.00, DATEADD(DAY, 13, GETDATE()), 'Efectivo'),
        (5, 2250.00, DATEADD(DAY, 14, GETDATE()), 'Efectivo'),
        (6, 2250.00, DATEADD(DAY, 15, GETDATE()), 'Efectivo'),
        (7, 2500.00, DATEADD(DAY, 16, GETDATE()), 'Efectivo'),
        (8, 2700.00, DATEADD(DAY, 17, GETDATE()), 'Efectivo'),
        (9, 2450.00, DATEADD(DAY, 18, GETDATE()), 'Efectivo'),
        (10, 2600.00, DATEADD(DAY, 19, GETDATE()), 'Efectivo'),
        (11, 2500.00, DATEADD(DAY, 20, GETDATE()), 'Efectivo'),
        (12, 2350.00, DATEADD(DAY, 21, GETDATE()), 'Efectivo');

    DECLARE pay_cursor CURSOR FOR SELECT Evento_Idx, Monto, Fecha_pago, Metodo_pago FROM @PagoData;
    OPEN pay_cursor;
    FETCH NEXT FROM pay_cursor INTO @Evento_Idx, @Monto, @Fecha_pago, @Metodo_pago;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Usar CTE para obtener Id_evento con ROW_NUMBER
        WITH EventoOrdenado AS (
            SELECT Id_evento, ROW_NUMBER() OVER (ORDER BY Id_evento) AS RowNum
            FROM #Eventos
        )
        SELECT @Id_evento = Id_evento
        FROM EventoOrdenado
        WHERE RowNum = @Evento_Idx;

        IF @Id_evento IS NOT NULL
        BEGIN
            EXEC Operaciones.AddPago 
                @Id_evento = @Id_evento,
                @Monto = @Monto,
                @Fecha_pago = @Fecha_pago,
                @Metodo_pago = @Metodo_pago;
        END
        FETCH NEXT FROM pay_cursor INTO @Evento_Idx, @Monto, @Fecha_pago, @Metodo_pago;
    END
    CLOSE pay_cursor;
    DEALLOCATE pay_cursor;
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar asignaciones de empleados a eventos (sin procedimiento, usar INSERT)
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);

    -- Usar CTE para asignar ROW_NUMBER a los eventos
    WITH EventoOrdenado AS (
        SELECT Id_evento, ROW_NUMBER() OVER (ORDER BY Id_evento) AS RowNum
        FROM #Eventos
    )
    INSERT INTO Administracion.Rol_Empleado_Evento (Id_evento, Id_empleado, Id_rol)
    SELECT 
        eo.Id_evento,
        (SELECT Id_empleado FROM #Empleados e WHERE e.Nombre = r.Nombre AND e.Apellido = r.Apellido),
        (SELECT Id_rol FROM #Roles WHERE Nombre_rol = r.Nombre_rol)
    FROM (VALUES
        (1, 'Carlos', 'Ram�rez', 'T�cnico de Sonido'), (1, 'Miguel', 'D�az', 'Especialista en Iluminaci�n'), (1, 'Diego', 'Torres', 'Encargado de Catering'),
        (1, 'Fernando', 'Castillo', 'Animadores'), (1, 'Isabel', 'Vega', 'Animadores'), (1, 'Andr�s', 'Moreno', 'Animadores'),
        (2, 'Rosa', 'Jim�nez', 'T�cnico de Sonido'), (2, 'Santiago', 'Dom�nguez', 'Especialista en Iluminaci�n'), (2, 'Clara', 'Fuentes', 'Encargado de Catering'),
        (2, 'Javier', 'R�os', 'Animadores'), (2, 'Natalia', 'Campos', 'Animadores'), (2, 'Emilio', 'Garc�a', 'Animadores'),
        (3, 'Luis', 'Hern�ndez', 'T�cnico de Sonido'), (3, 'Sof�a', 'L�pez', 'Especialista en Iluminaci�n'), (3, 'Elena', 'Fern�ndez', 'Encargado de Catering'),
        (3, 'Valeria', 'Ortiz', 'Animadores'), (3, 'Juan', 'P�rez', 'Animadores'), (3, 'Miguel', 'D�az', 'Animadores'),
        (4, 'Mar�a', 'G�mez', 'T�cnico de Sonido'), (4, 'Javier', 'R�os', 'Especialista en Iluminaci�n'), (4, 'Natalia', 'Campos', 'Encargado de Catering'),
        (4, 'Emilio', 'Garc�a', 'Animadores'), (4, 'Patricia', 'Soto', 'Animadores'), (4, 'Carlos', 'Ram�rez', 'Animadores'),
        (5, 'Ana', 'Mart�nez', 'Especialista en Iluminaci�n'), (5, 'Rosa', 'Jim�nez', 'Encargado de Catering'),
        (5, 'Santiago', 'Dom�nguez', 'Animadores'), (5, 'Clara', 'Fuentes', 'Animadores'), (5, 'Miguel', 'D�az', 'Animadores'),
        (6, 'Luis', 'Hern�ndez', 'T�cnico de Sonido'), (6, 'Elena', 'Fern�ndez', 'Especialista en Iluminaci�n'), (6, 'Diego', 'Torres', 'Encargado de Catering'),
        (6, 'Valeria', 'Ortiz', 'Animadores'), (6, 'Andr�s', 'Moreno', 'Animadores'), (6, 'Patricia', 'Soto', 'Animadores'),
        (7, 'Carlos', 'Ram�rez', 'T�cnico de Sonido'), (7, 'Luis', 'Hern�ndez', 'Especialista en Iluminaci�n'), (7, 'Miguel', 'D�az', 'Encargado de Catering'),
        (7, 'Isabel', 'Vega', 'Animadores'), (7, 'Andr�s', 'Moreno', 'Animadores'), (7, 'Rosa', 'Jim�nez', 'Animadores'),
        (8, 'Diego', 'Torres', 'T�cnico de Sonido'), (8, 'Valeria', 'Ortiz', 'Especialista en Iluminaci�n'), (8, 'Fernando', 'Castillo', 'Encargado de Catering'),
        (8, 'Clara', 'Fuentes', 'Animadores'), (8, 'Javier', 'R�os', 'Animadores'), (8, 'Natalia', 'Campos', 'Animadores'),
        (9, 'Mar�a', 'G�mez', 'T�cnico de Sonido'), (9, 'Ana', 'Mart�nez', 'Especialista en Iluminaci�n'), (9, 'Sof�a', 'L�pez', 'Encargado de Catering'),
        (9, 'Elena', 'Fern�ndez', 'Animadores'), (9, 'Fernando', 'Castillo', 'Animadores'), (9, 'Isabel', 'Vega', 'Animadores'),
        (10, 'Andr�s', 'Moreno', 'T�cnico de Sonido'), (10, 'Rosa', 'Jim�nez', 'Especialista en Iluminaci�n'), (10, 'Santiago', 'Dom�nguez', 'Encargado de Catering'),
        (10, 'Javier', 'R�os', 'Animadores'), (10, 'Natalia', 'Campos', 'Animadores'), (10, 'Emilio', 'Garc�a', 'Animadores'),
        (11, 'Juan', 'P�rez', 'T�cnico de Sonido'), (11, 'Carlos', 'Ram�rez', 'Especialista en Iluminaci�n'), (11, 'Diego', 'Torres', 'Encargado de Catering'),
        (11, 'Valeria', 'Ortiz', 'Animadores'), (11, 'Isabel', 'Vega', 'Animadores'), (11, 'Andr�s', 'Moreno', 'Animadores'),
        (12, 'Ana', 'Mart�nez', 'T�cnico de Sonido'), (12, 'Miguel', 'D�az', 'Especialista en Iluminaci�n'), (12, 'Rosa', 'Jim�nez', 'Encargado de Catering'),
        (12, 'Natalia', 'Campos', 'Animadores'), (12, 'Clara', 'Fuentes', 'Animadores'), (12, 'Emilio', 'Garc�a', 'Animadores')
    ) AS r(Evento_Idx, Nombre, Apellido, Nombre_rol)
    JOIN EventoOrdenado eo ON eo.RowNum = r.Evento_Idx
    WHERE EXISTS (
        SELECT 1 FROM #Empleados e WHERE e.Nombre = r.Nombre AND e.Apellido = r.Apellido
    ) AND EXISTS (
        SELECT 1 FROM #Roles ro WHERE ro.Nombre_rol = r.Nombre_rol
    );
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Limpiar tablas temporales
DROP TABLE IF EXISTS #Cargos;
DROP TABLE IF EXISTS #Roles;
DROP TABLE IF EXISTS #Empleados;
DROP TABLE IF EXISTS #Servicios;
DROP TABLE IF EXISTS #Paquetes;
DROP TABLE IF EXISTS #Clientes;
DROP TABLE IF EXISTS #Eventos;
GO