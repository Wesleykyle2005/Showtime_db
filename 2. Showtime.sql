USE ShowtimeDB;
-- Tabla Clientes
CREATE TABLE Operaciones.Clientes (
    Id_cliente INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellido VARCHAR(100) NOT NULL,
    Telefono VARCHAR(20) NOT NULL,
    Correo_electronico VARCHAR(100),
    CONSTRAINT UC_Correo UNIQUE (Correo_electronico),
    CONSTRAINT UC_Telefono UNIQUE (Telefono)
);

-- Tabla Paquetes
CREATE TABLE Operaciones.Paquetes (
    Id_paquete INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_paquete VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(MAX),
    Cantidad INT,
    Disponibilidad BIT NOT NULL,
    Costo DECIMAL(18, 2) NOT NULL,
    CONSTRAINT CHK_Cantidad CHECK (Cantidad >= 0),
    CONSTRAINT CHK_Costo CHECK (Costo > 0)
);

-- Tabla Eventos
CREATE TABLE Operaciones.Eventos (
    Id_evento INT IDENTITY(1,1) PRIMARY KEY,
    Id_paquete INT,
    Id_cliente INT NOT NULL,
    Fecha_reserva DATE NOT NULL,
    Fecha_inicio DATE NOT NULL,
    Hora_inicio TIME NOT NULL,
    Hora_fin TIME NOT NULL,
    Ubicacion VARCHAR(255) NOT NULL,
    Direccion VARCHAR(MAX) NOT NULL,
    Cantidad_de_asistentes INT NOT NULL,
    Detalles_adicionales VARCHAR(MAX),
    Costo_total DECIMAL(18, 2) NOT NULL,
    Estado VARCHAR(20) NOT NULL DEFAULT 'Pendiente',
    CONSTRAINT CHK_Fecha_Hora_Evento CHECK (Fecha_inicio > Fecha_reserva AND Hora_fin > Hora_inicio),
    CONSTRAINT CHK_Cantidad_Asistentes CHECK (Cantidad_de_asistentes > 0),
    CONSTRAINT CHK_Precio_del_Paquete CHECK (Costo_total > 0),
    CONSTRAINT FK_Eventos_Clientes FOREIGN KEY (Id_cliente) REFERENCES Operaciones.Clientes(Id_cliente),
    CONSTRAINT FK_Evento_Paquete FOREIGN KEY (Id_paquete) REFERENCES Operaciones.Paquetes(Id_paquete)
);

-- Tabla Servicios
CREATE TABLE Operaciones.Servicios (
    Id_servicio INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_servicio VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(MAX),
    Costo DECIMAL(18, 2) NOT NULL,
    CONSTRAINT CHK_Costo_Servicio CHECK (Costo > 0)
);

-- Tabla Pagos
CREATE TABLE Operaciones.Pagos (
    Id_pago INT IDENTITY(1,1) PRIMARY KEY,
    Id_evento INT NOT NULL,
    Monto DECIMAL(18, 2) NOT NULL,
    Fecha_pago DATE NOT NULL,
    Metodo_pago VARCHAR(50) NOT NULL,
    CONSTRAINT CHK_Costo_total CHECK (Monto > 0),
    CONSTRAINT FK_Pagos_ReservacionEvento FOREIGN KEY (Id_evento) REFERENCES Operaciones.Eventos(Id_evento)
);

-- Tabla Evento_Servicios
CREATE TABLE Operaciones.Evento_Servicios (
    Id_evento_servicios INT IDENTITY(1,1) PRIMARY KEY,
    Id_evento INT NOT NULL,
    Id_servicio INT NOT NULL,
    CONSTRAINT FK_Evento_Servicios_Eventos FOREIGN KEY (Id_evento) REFERENCES Operaciones.Eventos(Id_evento),
    CONSTRAINT FK_Evento_Servicios_Servicios FOREIGN KEY (Id_servicio) REFERENCES Operaciones.Servicios(Id_servicio)
);

-- Tabla Paquete_Servicios
CREATE TABLE Operaciones.Paquete_Servicios (
    Id_paquete_servicios INT IDENTITY(1,1) PRIMARY KEY,
    Id_paquete INT NOT NULL,
    Id_servicio INT NOT NULL,
    CONSTRAINT FK_Paquete_Servicios_Paquetes FOREIGN KEY (Id_paquete) REFERENCES Operaciones.Paquetes(Id_paquete),
    CONSTRAINT FK_Paquete_Servicios_Servicios FOREIGN KEY (Id_servicio) REFERENCES Operaciones.Servicios(Id_servicio)
);



---




-- Tabla Estado_Empleado
CREATE TABLE Administracion.Estado_Empleado (
    Id_estado INT IDENTITY(1,1) PRIMARY KEY,
    Tipo_estado VARCHAR(50) NOT NULL
);

-- Tabla Empleados
CREATE TABLE Administracion.Empleados (
    Id_empleado INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellido VARCHAR(100) NOT NULL,
    Telefono VARCHAR(20) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    Estado_Empleado INT NOT NULL DEFAULT 1,
    CONSTRAINT UC_Email UNIQUE (Email),
    CONSTRAINT UC_telefono_Empleado UNIQUE (Telefono),
    CONSTRAINT FK_Empleados_Estado_Empleado FOREIGN KEY (Estado_Empleado) REFERENCES Administracion.Estado_Empleado(Id_estado)
);

-- Tabla Cargos
CREATE TABLE Administracion.Cargos (
    Id_cargo INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_cargo VARCHAR(100) NOT NULL,
    Descripción VARCHAR(MAX)
);


-- Tabla Usuarios
CREATE TABLE Administracion.Usuarios (
    Id_usuario INT IDENTITY(1,1) PRIMARY KEY,
    Id_empleado INT NOT NULL,
    Id_Cargo INT NOT NULL,
    Nombre_usuario VARCHAR(50) NOT NULL,
    Contraseña VARCHAR(255) NOT NULL,
    UniqueHash VARCHAR(36) NOT NULL DEFAULT NEWID(), -- Unique salt for password hashing
    Estado BIT NOT NULL DEFAULT 1,
    CONSTRAINT UC_NombreUsuario UNIQUE (Nombre_usuario),
    CONSTRAINT FK_Usuarios_Empleados FOREIGN KEY (Id_empleado) REFERENCES Administracion.Empleados(Id_empleado),
    CONSTRAINT FK_Usuarios_Cargos FOREIGN KEY (Id_Cargo) REFERENCES Administracion.Cargos(Id_cargo)
);
GO

-- Tabla Roles
CREATE TABLE Administracion.Roles (
    Id_rol INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_rol VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(MAX)
);

-- Tabla Rol_Empleado_Evento
CREATE TABLE Administracion.Rol_Empleado_Evento (
    Id_rol_empleado_evento INT IDENTITY(1,1) PRIMARY KEY,
    Id_evento INT NOT NULL,
    Id_empleado INT NOT NULL,
    Id_rol INT NOT NULL,
    CONSTRAINT FK_Rol_Empleado_Evento_Eventos FOREIGN KEY (Id_evento) REFERENCES Operaciones.Eventos(Id_evento),
    CONSTRAINT FK_Rol_Empleado_Evento_Empleados FOREIGN KEY (Id_empleado) REFERENCES Administracion.Empleados(Id_empleado),
    CONSTRAINT FK_Rol_Empleado_Evento_Roles FOREIGN KEY (Id_rol) REFERENCES Administracion.Roles(Id_rol)
);



-- Tabla Utileria
CREATE TABLE Inventario.Utileria (
    Id_utileria INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Cantidad INT,
    CONSTRAINT CHK_Cantidad_Positive CHECK (Cantidad >= 0)
);

-- Tabla Servicio_Utileria
CREATE TABLE Inventario.Servicio_Utileria (
    Id_servicio_utileria INT IDENTITY(1,1) PRIMARY KEY,
    Id_servicio INT NOT NULL,
    Id_utileria INT NOT NULL,
    CONSTRAINT FK_Servicio_Utileria_Servicio FOREIGN KEY (Id_servicio) REFERENCES Operaciones.Servicios(Id_servicio),
    CONSTRAINT FK_Servicio_Utileria_Utileria FOREIGN KEY (Id_utileria) REFERENCES Inventario.Utileria(Id_utileria)
);


