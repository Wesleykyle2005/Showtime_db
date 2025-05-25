USE ShowtimeDB;
GO
CREATE OR ALTER PROCEDURE Administracion.AuthenticateUser
(
    @Nombre_usuario NVARCHAR(50),
    @Contraseña NVARCHAR(100)
)
AS
BEGIN
    SELECT 
        u.Id_usuario,
        u.Nombre_usuario,
        u.Id_Cargo,
        c.Nombre_cargo
    FROM Administracion.Usuarios u
    JOIN Administracion.Cargos c ON u.Id_Cargo = c.Id_cargo
    WHERE u.Nombre_usuario = @Nombre_usuario
    AND u.Contraseña = HASHBYTES('SHA2_256', @Contraseña + u.UniqueHash)
    AND u.Estado = 1
END
GO


CREATE OR ALTER PROCEDURE Administracion.GetUserProfile
(
    @Id_usuario int
)
AS
BEGIN
    SELECT 
        u.Nombre_usuario,
        u.Id_Cargo,
        c.Nombre_cargo,
        e.Nombre AS Nombre_empleado,
        e.Apellido AS Apellido_empleado
    FROM Administracion.Usuarios u
    JOIN Administracion.Cargos c ON u.Id_Cargo = c.Id_cargo
    JOIN Administracion.Empleados e ON u.Id_empleado = e.Id_empleado
    WHERE u.Id_usuario = @Id_usuario
    AND u.Estado = 1
END
GO


/*
----

USE ShowtimeDB;
GO

-- Step 1: Ensure prerequisite tables have data
-- Insert a sample employee status
INSERT INTO Administracion.Estado_Empleado (Tipo_estado)
VALUES ('Disponible');
GO

-- Insert a sample employee
INSERT INTO Administracion.Empleados (Nombre, Apellido, Telefono, Email, Estado_Empleado)
VALUES ('Juan', 'Pérez', '1234567890', 'juan.perez@example.com', 1);
GO

-- Insert a sample cargo
INSERT INTO Administracion.Cargos (Nombre_cargo, Descripción)
VALUES ('Administrador', 'Rol con acceso completo al sistema');
GO

-- Step 2: Insert a test user
DECLARE @Nombre_usuario NVARCHAR(50) = 'juanperez';
DECLARE @Contraseña NVARCHAR(100) = 'SecurePass123';
DECLARE @UniqueHash NVARCHAR(36) = NEWID();
DECLARE @HashedPassword VARBINARY(32);

-- Generate hashed password
SET @HashedPassword = HASHBYTES('SHA2_256', @Contraseña + @UniqueHash);

-- Insert user
INSERT INTO Administracion.Usuarios (Id_empleado, Id_Cargo, Nombre_usuario, Contraseña, UniqueHash, Estado)
VALUES (1, 1, @Nombre_usuario, @HashedPassword, @UniqueHash, 1);
GO

-- Step 3: Test login
EXEC Administracion.AuthenticateUser 'juanperez', 'SecurePass123';
GO

-- Step 4: Test profile retrieval
-- Assuming the inserted user has Id_usuario = 1
EXEC Administracion.GetUserProfile 1;
GO


EXEC Administracion.AuthenticateUser 'juanperez', 'WrongPass';

UPDATE Administracion.Usuarios SET Estado = 0 WHERE Nombre_usuario = 'juanperez';

EXEC Administracion.AuthenticateUser 'juanperez', 'SecurePass123';


EXEC Administracion.AuthenticateUser 'nonexistent', 'SecurePass123'


*/