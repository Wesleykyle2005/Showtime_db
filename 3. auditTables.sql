USE ShowtimeDB;
GO

-- Tablas de Auditor�a y Configuraciones

-- Tabla Auditoria.EventoLog
-- Descripci�n: Almacena un registro de cambios de estado y acciones cr�ticas en eventos para auditor�a.
-- Uso: Se llena autom�ticamente por triggers como trg_ActualizarEstadoEvento y TRG_ActualizarEstadoEventosPendientes.
CREATE TABLE Auditoria.EventoLog (
    Id_log INT IDENTITY(1,1) PRIMARY KEY,
    Id_evento INT NOT NULL,
    Accion NVARCHAR(200) NOT NULL,
    Fecha DATETIME NOT NULL,
    CONSTRAINT FK_EventoLog_Eventos FOREIGN KEY (Id_evento) REFERENCES Operaciones.Eventos(Id_evento)
);
GO

-- Tabla Auditoria.InventarioLog
-- Descripci�n: Registra cambios en la cantidad y disponibilidad de paquetes y utiler�a para seguimiento de inventario.
-- Uso: Se llena autom�ticamente por triggers como trg_RestarCantidadPaquete, trg_AumentarCantidadPaquete, trg_ActualizarInventarioUtileria y trg_RestaurarUtileriaEvento.
CREATE TABLE Auditoria.InventarioLog (
    Id_log INT IDENTITY(1,1) PRIMARY KEY,
    Id_paquete INT,
    Id_utileria INT,
    Accion NVARCHAR(200) NOT NULL,
    Fecha DATETIME NOT NULL,
    CONSTRAINT FK_InventarioLog_Paquetes FOREIGN KEY (Id_paquete) REFERENCES Operaciones.Paquetes(Id_paquete),
    CONSTRAINT FK_InventarioLog_Utileria FOREIGN KEY (Id_utileria) REFERENCES Inventario.Utileria(Id_utileria)
);
GO

-- Tabla Auditoria.EmpleadoLog
-- Descripci�n: Registra cambios en el estado de los empleados, como asignaciones o cambios de disponibilidad.
-- Uso: Se llena autom�ticamente por triggers como trg_EventoFinalizadoOCancelado y el procedimiento asignar_empleado_disponible.
CREATE TABLE Auditoria.EmpleadoLog (
    Id_log INT IDENTITY(1,1) PRIMARY KEY,
    Id_empleado INT NOT NULL,
    Accion NVARCHAR(200) NOT NULL,
    Fecha DATETIME NOT NULL,
    CONSTRAINT FK_EmpleadoLog_Empleados FOREIGN KEY (Id_empleado) REFERENCES Administracion.Empleados(Id_empleado)
);
GO


CREATE TABLE Configuraciones (
    Id_config INT IDENTITY(1,1) PRIMARY KEY,
    Clave NVARCHAR(100) NOT NULL UNIQUE,
    Valor NVARCHAR(100) NOT NULL,
    Descripcion NVARCHAR(500)
);
GO
-- Tabla Configuraciones
-- Descripci�n: Almacena par�metros configurables, como los d�as de corte para cancelaci�n autom�tica de eventos.
-- Uso: Consulta la tabla para obtener valores (ej., SELECT Valor FROM Configuraciones WHERE Clave = 'DiasCorteCancelacion').
INSERT INTO Configuraciones (Clave, Valor, Descripcion)
VALUES ('DiasCorteCancelacion', '7', 'D�as antes de cancelar eventos pendientes sin pago');
GO