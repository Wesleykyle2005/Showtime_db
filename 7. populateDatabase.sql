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

-- Crear tablas temporales físicas para mantener datos entre secciones
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
        EXEC Administracion.AddCargo @Nombre_cargo = 'Gerente', @Descripción = 'Acceso completo al sistema.';
        INSERT INTO #Cargos SELECT Id_cargo, 'Gerente' FROM Administracion.Cargos WHERE Nombre_cargo = 'Gerente';
    END
    IF NOT EXISTS (SELECT 1 FROM #Cargos WHERE Nombre_cargo = 'Bodeguero')
    BEGIN
        EXEC Administracion.AddCargo @Nombre_cargo = 'Bodeguero', @Descripción = 'Acceso solo a administrar la utilería.';
        INSERT INTO #Cargos SELECT Id_cargo, 'Bodeguero' FROM Administracion.Cargos WHERE Nombre_cargo = 'Bodeguero';
    END
    IF NOT EXISTS (SELECT 1 FROM #Cargos WHERE Nombre_cargo = 'Empleado')
    BEGIN
        EXEC Administracion.AddCargo @Nombre_cargo = 'Empleado', @Descripción = 'Solo puede hacer registros de eventos, pagos y asignar empleados a eventos.';
        INSERT INTO #Cargos SELECT Id_cargo, 'Empleado' FROM Administracion.Cargos WHERE Nombre_cargo = 'Empleado';
    END
    IF NOT EXISTS (SELECT 1 FROM #Cargos WHERE Nombre_cargo = 'Recursos Humanos')
    BEGIN
        EXEC Administracion.AddCargo @Nombre_cargo = 'Recursos Humanos', @Descripción = 'Acceso a administrar clientes y empleados.';
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
    WHERE Nombre_rol IN ('Decorador', 'Especialista en Iluminación', 'DJ o Músico', 'Fotógrafo/Videógrafo', 
                         'Encargado de Catering', 'Técnico de Sonido', 'Animadores', 'Botargueros', 'Administrador');

    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Decorador')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Decorador', @Descripcion = 'Encargado de diseñar y montar la decoración temática del evento.';
        INSERT INTO #Roles SELECT Id_rol, 'Decorador' FROM Administracion.Roles WHERE Nombre_rol = 'Decorador';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Especialista en Iluminación')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Especialista en Iluminación', @Descripcion = 'Configura y supervisa las luces y efectos visuales del evento.';
        INSERT INTO #Roles SELECT Id_rol, 'Especialista en Iluminación' FROM Administracion.Roles WHERE Nombre_rol = 'Especialista en Iluminación';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'DJ o Músico')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'DJ o Músico', @Descripcion = 'Encargado de la música y el entretenimiento durante el evento.';
        INSERT INTO #Roles SELECT Id_rol, 'DJ o Músico' FROM Administracion.Roles WHERE Nombre_rol = 'DJ o Músico';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Fotógrafo/Videógrafo')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Fotógrafo/Videógrafo', @Descripcion = 'Documenta el evento a través de fotos y videos.';
        INSERT INTO #Roles SELECT Id_rol, 'Fotógrafo/Videógrafo' FROM Administracion.Roles WHERE Nombre_rol = 'Fotógrafo/Videógrafo';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Encargado de Catering')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Encargado de Catering', @Descripcion = 'Supervisa la preparación y el servicio de alimentos y bebidas.';
        INSERT INTO #Roles SELECT Id_rol, 'Encargado de Catering' FROM Administracion.Roles WHERE Nombre_rol = 'Encargado de Catering';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Técnico de Sonido')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Técnico de Sonido', @Descripcion = 'Configura y opera los sistemas de audio para el evento.';
        INSERT INTO #Roles SELECT Id_rol, 'Técnico de Sonido' FROM Administracion.Roles WHERE Nombre_rol = 'Técnico de Sonido';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Animadores')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Animadores', @Descripcion = 'Encargados de entretener a los invitados con actividades temáticas y juegos.';
        INSERT INTO #Roles SELECT Id_rol, 'Animadores' FROM Administracion.Roles WHERE Nombre_rol = 'Animadores';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Botargueros')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Botargueros', @Descripcion = 'Personas que usan botargas o disfraces para animar eventos y captar la atención de los asistentes.';
        INSERT INTO #Roles SELECT Id_rol, 'Botargueros' FROM Administracion.Roles WHERE Nombre_rol = 'Botargueros';
    END
    IF NOT EXISTS (SELECT 1 FROM #Roles WHERE Nombre_rol = 'Administrador')
    BEGIN
        EXEC Administracion.AddRol @Nombre_rol = 'Administrador', @Descripcion = 'Supervisa el funcionamiento general de la empresa y la gestión de los eventos.';
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
    DECLARE @Contraseña NVARCHAR(64);
    DECLARE @Cargo NVARCHAR(100);

    DECLARE @EmpleadoData TABLE (Nombre NVARCHAR(100), Apellido NVARCHAR(100), Cargo NVARCHAR(100));
    INSERT INTO @EmpleadoData (Nombre, Apellido, Cargo) VALUES
        ('Juan', 'Pérez', 'Gerente'), ('María', 'Gómez', 'Bodeguero'), ('Carlos', 'Ramírez', 'Bodeguero'),
        ('Ana', 'Martínez', 'Gerente'), ('Luis', 'Hernández', 'Bodeguero'), ('Sofía', 'López', 'Gerente'),
        ('Miguel', 'Díaz', 'Bodeguero'), ('Elena', 'Fernández', 'Bodeguero'), ('Diego', 'Torres', 'Bodeguero'),
        ('Valeria', 'Ortiz', 'Gerente'), ('Fernando', 'Castillo', 'Empleado'), ('Isabel', 'Vega', 'Empleado'),
        ('Andrés', 'Moreno', 'Empleado'), ('Rosa', 'Jiménez', 'Empleado'), ('Santiago', 'Domínguez', 'Recursos Humanos'),
        ('Clara', 'Fuentes', 'Recursos Humanos'), ('Javier', 'Ríos', 'Recursos Humanos'), ('Natalia', 'Campos', 'Recursos Humanos'),
        ('Emilio', 'García', 'Recursos Humanos'), ('Patricia', 'Soto', 'Recursos Humanos');

    DECLARE emp_cursor CURSOR FOR SELECT Nombre, Apellido, Cargo FROM @EmpleadoData;
    OPEN emp_cursor;
    FETCH NEXT FROM emp_cursor INTO @Nombre, @Apellido, @Cargo;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Generar correo y teléfono únicos
        EXEC Operaciones.GenerateUniqueContactInfo 
            @Nombre = @Nombre, 
            @Apellido = @Apellido, 
            @Email = @Email OUTPUT, 
            @Phone = @Phone OUTPUT;

        -- Obtener Id_cargo desde #Cargos usando el nombre del cargo
        SELECT @Id_cargo = Id_cargo FROM #Cargos WHERE Nombre_cargo = @Cargo;

        -- Generar nombre de usuario y contraseña
        SET @Nombre_usuario = LOWER(CONCAT(@Nombre, '.', REPLACE(@Apellido, ' ', '')));
        SET @Contraseña = CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT('password', @Nombre, @Apellido)), 2);

        -- Insertar empleado
        EXEC Administracion.AddEmpleado 
            @Nombre = @Nombre, 
            @Apellido = @Apellido, 
            @Telefono = @Phone, 
            @Email = @Email, 
            @Estado_Empleado = @Id_estado, 
            @Nombre_usuario = @Nombre_usuario, 
            @Contraseña = @Contraseña, 
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
    SET @Contraseña = CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', '12345678'), 2);

    IF NOT EXISTS (SELECT 1 FROM Administracion.Usuarios WHERE Nombre_usuario = 'Admin')
    BEGIN
        EXEC Administracion.AddEmpleado 
            @Nombre = @Nombre, 
            @Apellido = @Apellido, 
            @Telefono = @Phone, 
            @Email = @Email, 
            @Estado_Empleado = @Id_estado, 
            @Nombre_usuario = @Nombre_usuario, 
            @Contraseña = @Contraseña, 
            @Id_Cargo = @Id_cargo;
    END
END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE();
    THROW 50000, @ErrorMessage, 1;
END CATCH
GO

-- Insertar utilería (sin procedimiento, usar INSERT)
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    INSERT INTO Inventario.Utileria (Nombre, Cantidad)
    SELECT Nombre, Cantidad
    FROM (VALUES
        ('Traje de Barney', 3), ('Traje de Baby Bop', 3), ('Traje de BJ', 3),
        ('Traje de Peppa Pig', 3), ('Traje de George Pig', 3), ('Traje de Mamá Pig', 3),
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
        ('Altavoz', 10), ('Micrófono', 10), ('Mesa de mezclas', 5), ('Cables de audio', 30),
        ('Silla plegable decorada', 200), ('Fundas de sillas', 200), ('Cintas decorativas', 200), ('Cojines adicionales', 50),
        ('Mesa redonda', 40), ('Mantel temático', 40), ('Centros de mesa temáticos', 40), ('Cubiertos y platos', 200),
        ('Calentadores de alimentos', 10), ('Bandejas para servir', 30), ('Jarras de bebidas', 30), ('Cucharones y pinzas', 20),
        ('Luces LED', 30), ('Reflectores', 10), ('Panel de control de iluminación', 2), ('Soportes de luces', 15)
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
        ('Animacion_Barney', 'Animación temática con el personaje de Barney.', 1500.00, NULL),
        ('Animacion_PeppaPig', 'Animación temática con el personaje de Peppa Pig.', 1400.00, NULL),
        ('Animacion_Backyardigans', 'Animación temática con los personajes de Backyardigans.', 1450.00, NULL),
        ('Animacion_Miraculous', 'Animación temática con Ladybug y Cat Noir.', 1600.00, NULL),
        ('Animacion_PawPatrol', 'Animación temática con los cachorros de Paw Patrol.', 1500.00, NULL),
        ('Animacion_Frozen', 'Animación temática con Elsa, Anna y Olaf.', 1700.00, NULL),
        ('Animacion_ScoobyDoo', 'Animación temática con Scooby-Doo y sus amigos.', 1550.00, NULL),
        ('Animacion_Cars', 'Animación temática con los personajes de Cars.', 1400.00, NULL),
        ('Animacion_MickeyMouse', 'Animación temática con Mickey Mouse y sus amigos.', 1500.00, NULL),
        ('Animacion_Minion', 'Animación temática con los Minions.', 1400.00, NULL),
        ('Animacion_SpongeBob', 'Animación temática con Bob Esponja y sus amigos.', 1500.00, NULL),
        ('Animacion_SesameStreet', 'Animación temática con los personajes de Plaza Sésamo.', 1450.00, NULL),
        ('Animacion_ToyStory', 'Animación temática con Woody, Buzz y amigos.', 1600.00, NULL),
        ('Animacion_SuperMario', 'Animación temática con Mario, Luigi y compañía.', 1550.00, NULL),
        ('Animacion_Pokemon', 'Animación temática con Ash, Pikachu y amigos.', 1500.00, NULL),
        ('Servicio_Sonido', 'Equipo de sonido para música y presentaciones.', 2000.00, NULL),
        ('Servicio_Sillas', 'Renta de sillas decoradas según la temática.', 1000.00, NULL),
        ('Servicio_Mesas', 'Renta de mesas decoradas para la ocasión.', 1200.00, NULL),
        ('Servicio_Alimentos', 'Servicio de alimentos y bebidas temáticos.', 3000.00, NULL),
        ('Servicio_Iluminacion', 'Iluminación especial según la temática.', 1800.00, NULL);

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

-- Insertar relación servicio-utilería (sin procedimiento, usar INSERT)
BEGIN TRY
    DECLARE @ErrorMessage NVARCHAR(4000);
    INSERT INTO Inventario.Servicio_Utileria (Id_servicio, Id_utileria)
    SELECT s.Id_servicio, u.Id_utileria
    FROM Operaciones.Servicios s
    JOIN Inventario.Utileria u ON s.Nombre_servicio + '_' + u.Nombre IN (
        SELECT CONCAT(s2.Nombre_servicio, '_', u2.Nombre)
        FROM (VALUES
            ('Animacion_Barney', 'Traje de Barney'), ('Animacion_Barney', 'Traje de Baby Bop'), ('Animacion_Barney', 'Traje de BJ'),
            ('Animacion_PeppaPig', 'Traje de Peppa Pig'), ('Animacion_PeppaPig', 'Traje de George Pig'), ('Animacion_PeppaPig', 'Traje de Mamá Pig'),
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
            ('Servicio_Sonido', 'Altavoz'), ('Servicio_Sonido', 'Micrófono'), ('Servicio_Sonido', 'Mesa de mezclas'), ('Servicio_Sonido', 'Cables de audio'),
            ('Servicio_Sillas', 'Silla plegable decorada'), ('Servicio_Sillas', 'Fundas de sillas'), ('Servicio_Sillas', 'Cintas decorativas'), ('Servicio_Sillas', 'Cojines adicionales'),
            ('Servicio_Mesas', 'Mesa redonda'), ('Servicio_Mesas', 'Mantel temático'), ('Servicio_Mesas', 'Centros de mesa temáticos'), ('Servicio_Mesas', 'Cubiertos y platos'),
            ('Servicio_Alimentos', 'Calentadores de alimentos'), ('Servicio_Alimentos', 'Bandejas para servir'), ('Servicio_Alimentos', 'Jarras de bebidas'), ('Servicio_Alimentos', 'Cucharones y pinzas'),
            ('Servicio_Iluminacion', 'Luces LED'), ('Servicio_Iluminacion', 'Reflectores'), ('Servicio_Iluminacion', 'Panel de control de iluminación'), ('Servicio_Iluminacion', 'Soportes de luces')
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
        ('Paquete_Barney', 'Un show temático de Barney con música, decoración y animación.', 3, 1, 5000.00),
        ('Paquete_PeppaPig', 'Espectáculo basado en Peppa Pig con juegos, decoración y animación.', 3, 1, 4500.00),
        ('Paquete_Backyardigans', 'Fiesta con temática de Backyardigans y actividades interactivas.', 3, 1, 4700.00),
        ('Paquete_Miraculous', 'Evento temático de Ladybug y Cat Noir con juegos y música.', 3, 1, 5200.00),
        ('Paquete_PawPatrol', 'Celebración con temática de Paw Patrol, personajes y animación.', 3, 1, 4800.00),
        ('Paquete_Frozen', 'Show temático de Frozen con canciones y decoración invernal.', 3, 1, 5500.00),
        ('Paquete_ScoobyDoo', 'Fiesta con temática de Scooby-Doo, misterios y diversión.', 3, 1, 4900.00),
        ('Paquete_Cars', 'Celebración inspirada en Cars, con juegos y decoración automovilística.', 3, 1, 4600.00),
        ('Paquete_MickeyMouse', 'Espectáculo basado en Mickey Mouse y sus amigos.', 3, 1, 5100.00),
        ('Paquete_Minion', 'Fiesta con temática de Minions, juegos y disfraces.', 3, 1, 4800.00),
        ('Paquete_SpongeBob', 'Evento temático de Bob Esponja con actividades acuáticas y animación.', 3, 1, 5300.00),
        ('Paquete_SesameStreet', 'Celebración con personajes de Plaza Sésamo, decoración y actividades.', 3, 1, 4700.00),
        ('Paquete_ToyStory', 'Fiesta con Woody, Buzz y más personajes de Toy Story.', 3, 1, 5400.00),
        ('Paquete_SuperMario', 'Evento con temática de Mario Bros, juegos y desafíos interactivos.', 3, 1, 5000.00),
        ('Paquete_Pokemon', 'Celebración temática de Pokémon, con animación y juegos creativos.', 3, 1, 5200.00)
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
        ('Juan', 'Pérez'), ('Ana', 'López'), ('Carlos', 'Martínez'), ('María', 'González'), ('Pedro', 'Hernández'),
        ('Lucía', 'Rodríguez'), ('Jorge', 'Sánchez'), ('Laura', 'Ramírez'), ('David', 'Torres'), ('Elena', 'Vázquez');

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
        ('Paquete_Barney', 'Juan', 'Pérez', CAST(GETDATE() AS DATE), DATEADD(DAY, 30, GETDATE()), '18:00:00', '22:00:00', 'Managua', 'Calle principal #1, Barrio central, Managua', 70, 'Detalles del evento #1', 5000.00, 'Pendiente'),
        ('Paquete_Cars', 'Lucía', 'Rodríguez', DATEADD(DAY, 3, GETDATE()), DATEADD(DAY, 33, GETDATE()), '08:00:00', '12:00:00', 'Rivas', 'Calle principal #2, Barrio central, Rivas', 41, 'Detalles del evento #2', 4600.00, 'Pendiente'),
        ('Paquete_Cars', 'María', 'González', DATEADD(DAY, 5, GETDATE()), DATEADD(DAY, 35, GETDATE()), '08:00:00', '12:00:00', 'Jinotega', 'Calle principal #3, Barrio central, Jinotega', 56, 'Detalles del evento #3', 4600.00, 'Pendiente'),
        ('Paquete_MickeyMouse', 'Elena', 'Vázquez', DATEADD(DAY, 7, GETDATE()), DATEADD(DAY, 37, GETDATE()), '11:00:00', '15:00:00', 'Madriz', 'Calle principal #4, Barrio central, Madriz', 78, 'Detalles del evento #4', 5100.00, 'Pendiente'),
        ('Paquete_PeppaPig', 'Pedro', 'Hernández', CAST(GETDATE() AS DATE), DATEADD(DAY, 30, GETDATE()), '20:00:00', '23:00:00', 'Río San Juan', 'Calle principal #5, Barrio central, Río San Juan', 58, 'Detalles del evento #5', 4500.00, 'Pendiente'),
        ('Paquete_PeppaPig', 'María', 'González', DATEADD(DAY, 2, GETDATE()), DATEADD(DAY, 32, GETDATE()), '20:00:00', '22:00:00', 'Boaco', 'Calle principal #6, Barrio central, Boaco', 59, 'Detalles del evento #6', 4500.00, 'Pendiente'),
        ('Paquete_SuperMario', 'Lucía', 'Rodríguez', DATEADD(DAY, -3, GETDATE()), DATEADD(DAY, 27, GETDATE()), '14:00:00', '18:00:00', 'Río San Juan', 'Calle principal #7, Barrio central, Río San Juan', 57, 'Detalles del evento #7', 5000.00, 'Pendiente'),
        ('Paquete_ToyStory', 'Elena', 'Vázquez', CAST(GETDATE() AS DATE), DATEADD(DAY, 30, GETDATE()), '18:00:00', '22:00:00', 'Madriz', 'Calle principal #8, Barrio central, Madriz', 23, 'Detalles del evento #8', 5400.00, 'Pendiente'),
        ('Paquete_ScoobyDoo', 'Lucía', 'Rodríguez', DATEADD(DAY, 6, GETDATE()), DATEADD(DAY, 36, GETDATE()), '19:00:00', '23:00:00', 'Rivas', 'Calle principal #9, Barrio central, Rivas', 73, 'Detalles del evento #9', 4900.00, 'Pendiente'),
        ('Paquete_Miraculous', 'Laura', 'Ramírez', DATEADD(DAY, 2, GETDATE()), DATEADD(DAY, 32, GETDATE()), '09:00:00', '13:00:00', 'Estelí', 'Calle principal #10, Barrio central, Estelí', 28, 'Detalles del evento #10', 5200.00, 'Pendiente'),
        ('Paquete_Barney', 'Ana', 'López', DATEADD(DAY, -3, GETDATE()), DATEADD(DAY, 27, GETDATE()), '20:00:00', '22:00:00', 'Madriz', 'Calle principal #11, Barrio central, Madriz', 53, 'Detalles del evento #11', 5000.00, 'Pendiente'),
        ('Paquete_SesameStreet', 'Juan', 'Pérez', DATEADD(DAY, 1, GETDATE()), DATEADD(DAY, 31, GETDATE()), '10:00:00', '14:00:00', 'Chinandega', 'Calle principal #12, Barrio central, Chinandega', 82, 'Detalles del evento #12', 4700.00, 'Pendiente')
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
        (1, 'Carlos', 'Ramírez', 'Técnico de Sonido'), (1, 'Miguel', 'Díaz', 'Especialista en Iluminación'), (1, 'Diego', 'Torres', 'Encargado de Catering'),
        (1, 'Fernando', 'Castillo', 'Animadores'), (1, 'Isabel', 'Vega', 'Animadores'), (1, 'Andrés', 'Moreno', 'Animadores'),
        (2, 'Rosa', 'Jiménez', 'Técnico de Sonido'), (2, 'Santiago', 'Domínguez', 'Especialista en Iluminación'), (2, 'Clara', 'Fuentes', 'Encargado de Catering'),
        (2, 'Javier', 'Ríos', 'Animadores'), (2, 'Natalia', 'Campos', 'Animadores'), (2, 'Emilio', 'García', 'Animadores'),
        (3, 'Luis', 'Hernández', 'Técnico de Sonido'), (3, 'Sofía', 'López', 'Especialista en Iluminación'), (3, 'Elena', 'Fernández', 'Encargado de Catering'),
        (3, 'Valeria', 'Ortiz', 'Animadores'), (3, 'Juan', 'Pérez', 'Animadores'), (3, 'Miguel', 'Díaz', 'Animadores'),
        (4, 'María', 'Gómez', 'Técnico de Sonido'), (4, 'Javier', 'Ríos', 'Especialista en Iluminación'), (4, 'Natalia', 'Campos', 'Encargado de Catering'),
        (4, 'Emilio', 'García', 'Animadores'), (4, 'Patricia', 'Soto', 'Animadores'), (4, 'Carlos', 'Ramírez', 'Animadores'),
        (5, 'Ana', 'Martínez', 'Especialista en Iluminación'), (5, 'Rosa', 'Jiménez', 'Encargado de Catering'),
        (5, 'Santiago', 'Domínguez', 'Animadores'), (5, 'Clara', 'Fuentes', 'Animadores'), (5, 'Miguel', 'Díaz', 'Animadores'),
        (6, 'Luis', 'Hernández', 'Técnico de Sonido'), (6, 'Elena', 'Fernández', 'Especialista en Iluminación'), (6, 'Diego', 'Torres', 'Encargado de Catering'),
        (6, 'Valeria', 'Ortiz', 'Animadores'), (6, 'Andrés', 'Moreno', 'Animadores'), (6, 'Patricia', 'Soto', 'Animadores'),
        (7, 'Carlos', 'Ramírez', 'Técnico de Sonido'), (7, 'Luis', 'Hernández', 'Especialista en Iluminación'), (7, 'Miguel', 'Díaz', 'Encargado de Catering'),
        (7, 'Isabel', 'Vega', 'Animadores'), (7, 'Andrés', 'Moreno', 'Animadores'), (7, 'Rosa', 'Jiménez', 'Animadores'),
        (8, 'Diego', 'Torres', 'Técnico de Sonido'), (8, 'Valeria', 'Ortiz', 'Especialista en Iluminación'), (8, 'Fernando', 'Castillo', 'Encargado de Catering'),
        (8, 'Clara', 'Fuentes', 'Animadores'), (8, 'Javier', 'Ríos', 'Animadores'), (8, 'Natalia', 'Campos', 'Animadores'),
        (9, 'María', 'Gómez', 'Técnico de Sonido'), (9, 'Ana', 'Martínez', 'Especialista en Iluminación'), (9, 'Sofía', 'López', 'Encargado de Catering'),
        (9, 'Elena', 'Fernández', 'Animadores'), (9, 'Fernando', 'Castillo', 'Animadores'), (9, 'Isabel', 'Vega', 'Animadores'),
        (10, 'Andrés', 'Moreno', 'Técnico de Sonido'), (10, 'Rosa', 'Jiménez', 'Especialista en Iluminación'), (10, 'Santiago', 'Domínguez', 'Encargado de Catering'),
        (10, 'Javier', 'Ríos', 'Animadores'), (10, 'Natalia', 'Campos', 'Animadores'), (10, 'Emilio', 'García', 'Animadores'),
        (11, 'Juan', 'Pérez', 'Técnico de Sonido'), (11, 'Carlos', 'Ramírez', 'Especialista en Iluminación'), (11, 'Diego', 'Torres', 'Encargado de Catering'),
        (11, 'Valeria', 'Ortiz', 'Animadores'), (11, 'Isabel', 'Vega', 'Animadores'), (11, 'Andrés', 'Moreno', 'Animadores'),
        (12, 'Ana', 'Martínez', 'Técnico de Sonido'), (12, 'Miguel', 'Díaz', 'Especialista en Iluminación'), (12, 'Rosa', 'Jiménez', 'Encargado de Catering'),
        (12, 'Natalia', 'Campos', 'Animadores'), (12, 'Clara', 'Fuentes', 'Animadores'), (12, 'Emilio', 'García', 'Animadores')
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