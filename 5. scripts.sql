USE ShowtimeDB;
GO


-- Vistas Mejoradas

-- Vista TotalEventosNoFinalizadosMesActual
-- Descripción: Muestra la cantidad, monto total pendiente y paquetes de eventos no finalizados en el mes actual.
-- Uso: SELECT * FROM TotalEventosNoFinalizadosMesActual; para obtener un resumen de eventos futuros en el mes actual.
CREATE OR ALTER VIEW TotalEventosNoFinalizadosMesActual AS
SELECT 
    COUNT(*) AS CantidadEventos,
    ISNULL(SUM(Costo_total), 0) AS MontoTotalPendiente,
    STRING_AGG(P.Nombre_paquete, ', ') AS Paquetes
FROM Operaciones.Eventos E
LEFT JOIN Operaciones.Paquetes P ON E.Id_paquete = P.Id_paquete
WHERE MONTH(E.Fecha_inicio) = MONTH(GETDATE())
  AND YEAR(E.Fecha_inicio) = YEAR(GETDATE())
  AND E.Fecha_inicio >= GETDATE()
  AND E.Estado IN ('Pendiente', 'Reservado', 'Incompleto')
GROUP BY MONTH(E.Fecha_inicio), YEAR(E.Fecha_inicio);
GO

-- Vista vw_ReservacionesPorMes
-- Descripción: Agrupa las reservas de eventos por mes y año, mostrando la cantidad y los ingresos estimados.
-- Uso: SELECT * FROM vw_ReservacionesPorMes ORDER BY Cantidad_Reservas DESC; para analizar la demanda de eventos por período.
CREATE OR ALTER VIEW vw_ReservacionesPorMes AS
SELECT 
    MONTH(E.Fecha_reserva) AS Mes, 
    YEAR(E.Fecha_reserva) AS Año, 
    COUNT(*) AS Cantidad_Reservas,
    ISNULL(SUM(E.Costo_total), 0) AS IngresosEstimados
FROM Operaciones.Eventos E
WHERE E.Estado IN ('Pendiente', 'Reservado', 'Incompleto', 'Finalizado')
GROUP BY YEAR(E.Fecha_reserva), MONTH(E.Fecha_reserva);
GO

-- Vista vw_IngresosFinalizadosPorMes
-- Descripción: Calcula los ingresos reales de eventos finalizados por mes y año, incluyendo los paquetes utilizados.
-- Uso: SELECT * FROM vw_IngresosFinalizadosPorMes; para revisar los ingresos generados por eventos completados.
CREATE OR ALTER VIEW vw_IngresosFinalizadosPorMes AS
SELECT 
    YEAR(E.Fecha_reserva) AS Año,
    MONTH(E.Fecha_reserva) AS Mes,
    ISNULL(SUM(P.Monto), 0) AS IngresosMensuales,
    STRING_AGG(Pq.Nombre_paquete, ', ') AS PaquetesPrincipales
FROM Operaciones.Eventos E
JOIN Operaciones.Pagos P ON E.Id_evento = P.Id_evento
LEFT JOIN Operaciones.Paquetes Pq ON E.Id_paquete = Pq.Id_paquete
WHERE E.Estado = 'Finalizado'
GROUP BY YEAR(E.Fecha_reserva), MONTH(E.Fecha_reserva);
GO

-- Vista vw_DisponibilidadEmpleados
-- Descripción: Lista los empleados disponibles, mostrando su estado y número de eventos asignados futuros.
-- Uso: SELECT * FROM vw_DisponibilidadEmpleados; para identificar empleados disponibles para asignación.
CREATE VIEW vw_DisponibilidadEmpleados AS
SELECT 
    E.Id_empleado,
    E.Nombre,
    E.Apellido,
    ES.Tipo_estado,
    COUNT(REE.Id_evento) AS EventosAsignados
FROM Administracion.Empleados E
JOIN Administracion.Estado_Empleado ES ON E.Estado_Empleado = ES.Id_estado
LEFT JOIN Administracion.Rol_Empleado_Evento REE ON E.Id_empleado = REE.Id_empleado
LEFT JOIN Operaciones.Eventos EV ON REE.Id_evento = EV.Id_evento
    AND EV.Fecha_inicio >= GETDATE()
    AND EV.Estado NOT IN ('Finalizado', 'Cancelado')
GROUP BY E.Id_empleado, E.Nombre, E.Apellido, ES.Tipo_estado
HAVING COUNT(REE.Id_evento) = 0 OR ES.Tipo_estado = 'Disponible';
GO

-- Vista vw_InventarioUtileria
-- Descripción: Muestra la utilería disponible, su cantidad, y los servicios y paquetes asociados.
-- Uso: SELECT * FROM vw_InventarioUtileria; para revisar el inventario de utilería disponible.
CREATE VIEW vw_InventarioUtileria AS
SELECT 
    U.Id_utileria,
    U.Nombre AS NombreUtileria,
    U.Cantidad,
    S.Nombre_servicio,
    P.Nombre_paquete
FROM Inventario.Utileria U
LEFT JOIN Inventario.Servicio_Utileria SU ON U.Id_utileria = SU.Id_utileria
LEFT JOIN Operaciones.Servicios S ON SU.Id_servicio = S.Id_servicio
LEFT JOIN Operaciones.Paquete_Servicios PS ON S.Id_servicio = PS.Id_servicio
LEFT JOIN Operaciones.Paquetes P ON PS.Id_paquete = P.Id_paquete
WHERE U.Cantidad > 0;
GO

-- Funciones Mejoradas

-- Función CalcularPagoRestante
-- Descripción: Calcula el monto pendiente y el porcentaje pagado para un evento específico.
-- Uso: SELECT * FROM dbo.CalcularPagoRestante(1); donde 1 es el Id_evento.
CREATE OR ALTER FUNCTION dbo.CalcularPagoRestante (@IdEvento INT)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        ISNULL(E.Costo_total - ISNULL(SUM(P.Monto), 0), 0) AS PagoRestante,
        CASE WHEN E.Costo_total > 0 
             THEN ISNULL(SUM(P.Monto) / E.Costo_total * 100, 0) 
             ELSE 0 END AS PorcentajePagado
    FROM Operaciones.Eventos E
    LEFT JOIN Operaciones.Pagos P ON E.Id_evento = P.Id_evento
    WHERE E.Id_evento = @IdEvento
    GROUP BY E.Costo_total
);
GO

-- Función fn_PaquetesMasDemandados
-- Descripción: Devuelve los 5 paquetes más reservados en el mes actual, con cantidad de reservas e ingresos estimados.
-- Uso: SELECT * FROM fn_PaquetesMasDemandados(); para analizar la popularidad de paquetes.
CREATE OR ALTER FUNCTION fn_PaquetesMasDemandados ()
RETURNS TABLE
AS
RETURN
(
    SELECT TOP 5
        P.Nombre_paquete,
        COUNT(E.Id_evento) AS Cantidad_Reservas,
        ISNULL(SUM(E.Costo_total), 0) AS IngresosEstimados
    FROM Operaciones.Paquetes P
    JOIN Operaciones.Eventos E ON P.Id_paquete = E.Id_paquete
    WHERE MONTH(E.Fecha_reserva) = MONTH(GETDATE())
      AND YEAR(E.Fecha_reserva) = YEAR(GETDATE())
      AND E.Estado IN ('Pendiente', 'Reservado', 'Incompleto', 'Finalizado')
    GROUP BY P.Nombre_paquete
    ORDER BY Cantidad_Reservas DESC
);
GO

-- Función fn_CostoPromedioPaquete
-- Descripción: Calcula el costo promedio de eventos reservados en un mes y año específicos.
-- Uso: SELECT dbo.fn_CostoPromedioPaquete(5, 2025); para el promedio de mayo 2025.
CREATE FUNCTION fn_CostoPromedioPaquete (@Mes INT, @Año INT)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @CostoPromedio DECIMAL(18,2);
    SELECT @CostoPromedio = AVG(E.Costo_total)
    FROM Operaciones.Eventos E
    JOIN Operaciones.Paquetes P ON E.Id_paquete = P.Id_paquete
    WHERE MONTH(E.Fecha_reserva) = @Mes
      AND YEAR(E.Fecha_reserva) = @Año
      AND E.Estado IN ('Reservado', 'Finalizado');
    RETURN ISNULL(@CostoPromedio, 0);
END;
GO

-- Función fn_ProximosEventosEmpleado
-- Descripción: Lista los eventos futuros asignados a un empleado, incluyendo fecha, ubicación y rol.
-- Uso: SELECT * FROM fn_ProximosEventosEmpleado(1); donde 1 es el Id_empleado.
CREATE FUNCTION fn_ProximosEventosEmpleado (@IdEmpleado INT)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        E.Id_evento,
        E.Fecha_inicio,
        E.Ubicacion,
        R.Nombre_rol
    FROM Operaciones.Eventos E
    JOIN Administracion.Rol_Empleado_Evento REE ON E.Id_evento = REE.Id_evento
    JOIN Administracion.Roles R ON REE.Id_rol = R.Id_rol
    WHERE REE.Id_empleado = @IdEmpleado
      AND E.Fecha_inicio >= GETDATE()
      AND E.Estado NOT IN ('Finalizado', 'Cancelado')
);
GO

-- Procedimientos Mejorados

-- Procedimiento asignar_empleado_disponible
-- Descripción: Asigna un empleado a un evento si está disponible, actualiza su estado y registra la acción.
-- Uso: EXEC asignar_empleado_disponible @p_evento_id = 1, @p_empleado_id = 2, @p_rol_id = 3;
CREATE OR ALTER PROCEDURE asignar_empleado_disponible 
    @p_evento_id INT,
    @p_empleado_id INT,
    @p_rol_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Operaciones.Eventos WHERE Id_evento = @p_evento_id)
            THROW 50001, 'El evento no existe.', 1;
        IF NOT EXISTS (SELECT 1 FROM Administracion.Empleados WHERE Id_empleado = @p_empleado_id)
            THROW 50002, 'El empleado no existe.', 1;
        IF NOT EXISTS (SELECT 1 FROM Administracion.Roles WHERE Id_rol = @p_rol_id)
            THROW 50003, 'El rol no existe.', 1;

        DECLARE @empleado_disponible BIT;
        SELECT @empleado_disponible = CASE 
            WHEN EXISTS (
                SELECT 1
                FROM Administracion.Rol_Empleado_Evento RE
                JOIN Operaciones.Eventos E ON RE.Id_evento = E.Id_evento
                WHERE RE.Id_empleado = @p_empleado_id
                  AND E.Fecha_inicio >= CAST(GETDATE() AS DATE)
                  AND E.Estado NOT IN ('Finalizado', 'Cancelado')
            ) THEN 0 ELSE 1 END;

        IF @empleado_disponible = 1
        BEGIN
            INSERT INTO Administracion.Rol_Empleado_Evento (Id_evento, Id_empleado, Id_rol)
            VALUES (@p_evento_id, @p_empleado_id, @p_rol_id);

            UPDATE Administracion.Empleados
            SET Estado_Empleado = (SELECT Id_estado FROM Administracion.Estado_Empleado WHERE Tipo_estado = 'En evento')
            WHERE Id_empleado = @p_empleado_id;

            INSERT INTO Auditoria.EmpleadoLog (Id_empleado, Accion, Fecha)
            VALUES (@p_empleado_id, 'Asignado a evento ' + CAST(@p_evento_id AS NVARCHAR), GETDATE());
        END
        ELSE
            THROW 50004, 'El empleado no está disponible.', 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50000, @ErrorMessage, 1;
    END CATCH
END;
GO

-- Procedimiento sp_GenerarReporteFinanciero
-- Descripción: Genera un reporte financiero por período, detallando eventos, ingresos y montos pendientes.
-- Uso: EXEC sp_GenerarReporteFinanciero @FechaInicio = '2025-01-01', @FechaFin = '2025-12-31';
CREATE PROCEDURE sp_GenerarReporteFinanciero
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        E.Estado,
        COUNT(E.Id_evento) AS CantidadEventos,
        ISNULL(SUM(E.Costo_total), 0) AS IngresosEsperados,
        ISNULL(SUM(P.Monto), 0) AS IngresosRecibidos,
        ISNULL(SUM(E.Costo_total - ISNULL(P.Monto, 0)), 0) AS PendientePorCobrar
    FROM Operaciones.Eventos E
    LEFT JOIN (
        SELECT Id_evento, SUM(Monto) AS Monto
        FROM Operaciones.Pagos
        GROUP BY Id_evento
    ) P ON E.Id_evento = P.Id_evento
    WHERE E.Fecha_reserva BETWEEN @FechaInicio AND @FechaFin
    GROUP BY E.Estado;
END;
GO

-- Procedimiento sp_ReasignarEmpleado
-- Descripción: Reasigna un empleado de un evento a otro, validando disponibilidad y registrando la acción.
-- Uso: EXEC sp_ReasignarEmpleado @IdEventoActual = 1, @IdEventoNuevo = 2, @IdEmpleado = 3, @IdRol = 4;
CREATE PROCEDURE sp_ReasignarEmpleado
    @IdEventoActual INT,
    @IdEventoNuevo INT,
    @IdEmpleado INT,
    @IdRol INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        EXEC asignar_empleado_disponible @IdEventoNuevo, @IdEmpleado, @IdRol;
        DELETE FROM Administracion.Rol_Empleado_Evento
        WHERE Id_evento = @IdEventoActual AND Id_empleado = @IdEmpleado;

        INSERT INTO Auditoria.EmpleadoLog (Id_empleado, Accion, Fecha)
        VALUES (@IdEmpleado, 'Reasignado de evento ' + CAST(@IdEventoActual AS NVARCHAR) + ' a ' + CAST(@IdEventoNuevo AS NVARCHAR), GETDATE());
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50000, @ErrorMessage, 1;
    END CATCH
END;
GO

-- Triggers Mejorados

-- Trigger prevent_same_day_employee_assignment
-- Descripción: Impide asignar un empleado a eventos que se superponen en fecha y horario, proporcionando un mensaje de error detallado.
-- Funcionamiento: Se activa al intentar insertar en Rol_Empleado_Evento y verifica conflictos antes de permitir la inserción.
CREATE OR ALTER TRIGGER prevent_same_day_employee_assignment
ON Administracion.Rol_Empleado_Evento
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Operaciones.Eventos E1 ON i.Id_evento = E1.Id_evento
        JOIN Administracion.Rol_Empleado_Evento RE ON RE.Id_empleado = i.Id_empleado
        JOIN Operaciones.Eventos E2 ON RE.Id_evento = E2.Id_evento
        WHERE E2.Fecha_inicio = E1.Fecha_inicio
          AND (E2.Hora_inicio < E1.Hora_fin AND E2.Hora_fin > E1.Hora_inicio)
    )
    BEGIN
        DECLARE @ErrorMsg NVARCHAR(4000) = 'El empleado ya está asignado a otro evento en el mismo día y horario: ' + 
            (SELECT STRING_AGG(E2.Ubicacion, ', ') 
             FROM Operaciones.Eventos E2 
             JOIN Administracion.Rol_Empleado_Evento RE ON RE.Id_evento = E2.Id_evento 
             WHERE RE.Id_empleado = (SELECT Id_empleado FROM inserted));
        RAISERROR (@ErrorMsg, 16, 1);
        ROLLBACK TRANSACTION;
    END
    ELSE
    BEGIN
        INSERT INTO Administracion.Rol_Empleado_Evento (Id_evento, Id_empleado, Id_rol)
        SELECT Id_evento, Id_empleado, Id_rol
        FROM inserted;
    END
END;
GO

-- Trigger trg_RestarCantidadPaquete
-- Descripción: Reduce la cantidad disponible de un paquete al crear un evento y registra la acción.
-- Funcionamiento: Se activa tras insertar un evento, valida la disponibilidad del paquete y actualiza su cantidad.
CREATE OR ALTER TRIGGER trg_RestarCantidadPaquete
ON Operaciones.Eventos
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Id_paquete INT, @Cantidad INT;
    SELECT @Id_paquete = Id_paquete FROM inserted;
    IF @Id_paquete IS NOT NULL
    BEGIN
        SELECT @Cantidad = Cantidad FROM Operaciones.Paquetes WHERE Id_paquete = @Id_paquete;
        IF @Cantidad <= 0
            RAISERROR ('El paquete no tiene disponibilidad.', 16, 1);
        ELSE
        BEGIN
            UPDATE Operaciones.Paquetes
            SET Cantidad = Cantidad - 1,
                Disponibilidad = CASE WHEN Cantidad - 1 > 0 THEN 1 ELSE 0 END
            WHERE Id_paquete = @Id_paquete;

            INSERT INTO Auditoria.InventarioLog (Id_paquete, Accion, Fecha)
            VALUES (@Id_paquete, 'Resta por evento', GETDATE());
        END
    END
END;
GO

-- Trigger trg_AumentarCantidadPaquete
-- Descripción: Aumenta la cantidad disponible de un paquete cuando un evento se finaliza o cancela, y registra la acción.
-- Funcionamiento: Se activa tras actualizar un evento a 'Finalizado' o 'Cancelado' y restaura la disponibilidad del paquete.
CREATE OR ALTER TRIGGER trg_AumentarCantidadPaquete
ON Operaciones.Eventos
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Id_paquete INT, @Estado NVARCHAR(20);
    SELECT @Id_paquete = Id_paquete, @Estado = Estado FROM inserted;
    IF @Id_paquete IS NOT NULL AND @Estado IN ('Finalizado', 'Cancelado')
    BEGIN
        UPDATE Operaciones.Paquetes
        SET Cantidad = Cantidad + 1,
            Disponibilidad = 1
        WHERE Id_paquete = @Id_paquete;

        INSERT INTO Auditoria.InventarioLog (Id_paquete, Accion, Fecha)
        VALUES (@Id_paquete, 'Aumento por ' + @Estado, GETDATE());
    END
END;
GO

-- Trigger trg_ActualizarEstadoEvento
-- Descripción: Actualiza el estado de un evento según los pagos realizados y registra los cambios.
-- Funcionamiento: Se activa tras insertar o actualizar un pago, evalúa el monto pagado y las fechas para determinar el estado del evento.
CREATE OR ALTER TRIGGER trg_ActualizarEstadoEvento
ON Operaciones.Pagos
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Operaciones.Eventos
    SET Estado = CASE 
        WHEN ISNULL(p.SumaPagos, 0) < (0.5 * e.Costo_total) AND GETDATE() <= DATEADD(DAY, 7, e.Fecha_reserva) THEN 'Pendiente'
        WHEN ISNULL(p.SumaPagos, 0) >= (0.5 * e.Costo_total) AND GETDATE() <= DATEADD(DAY, 7, e.Fecha_reserva) THEN 'Reservado'
        WHEN ISNULL(p.SumaPagos, 0) < e.Costo_total AND GETDATE() < DATEADD(DAY, -1, e.Fecha_inicio) THEN 'Incompleto'
        WHEN ISNULL(p.SumaPagos, 0) = e.Costo_total AND GETDATE() <= DATEADD(DAY, -1, e.Fecha_inicio) THEN 'Saldado'
        WHEN ISNULL(p.SumaPagos, 0) < e.Costo_total AND GETDATE() > e.Fecha_inicio THEN 'Incompleto'
        WHEN ISNULL(p.SumaPagos, 0) = e.Costo_total AND GETDATE() > e.Fecha_inicio THEN 'Finalizado'
        ELSE e.Estado
    END
    FROM Operaciones.Eventos e
    JOIN (
        SELECT Id_evento, SUM(Monto) AS SumaPagos
        FROM Operaciones.Pagos
        GROUP BY Id_evento
    ) p ON e.Id_evento = p.Id_evento
    JOIN inserted i ON i.Id_evento = e.Id_evento;

    INSERT INTO Auditoria.EventoLog (Id_evento, Accion, Fecha)
    SELECT i.Id_evento, 'Cambio de estado a ' + e.Estado, GETDATE()
    FROM inserted i
    JOIN Operaciones.Eventos e ON i.Id_evento = e.Id_evento;
END;
GO

-- Trigger TRG_ActualizarEstadoEventosPendientes
-- Descripción: Cancela eventos pendientes sin al menos 50% de pago tras un período configurable y registra la acción.
-- Funcionamiento: Se activa tras insertar o actualizar pagos, verifica eventos pendientes y los cancela si superan el período de corte.
CREATE OR ALTER TRIGGER TRG_ActualizarEstadoEventosPendientes
ON Operaciones.Pagos
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    DECLARE @DiasCorte INT = COALESCE((SELECT CAST(Valor AS INT) FROM Configuraciones WHERE Clave = 'DiasCorteCancelacion'), 7);
    DECLARE @FechaCorte DATE = DATEADD(DAY, -@DiasCorte, GETDATE());

    UPDATE Operaciones.Eventos
    SET Estado = 'Cancelado'
    WHERE Estado = 'Pendiente'
      AND Fecha_reserva <= @FechaCorte
      AND NOT EXISTS (
          SELECT 1
          FROM Operaciones.Pagos
          WHERE Pagos.Id_evento = Operaciones.Eventos.Id_evento
            AND Pagos.Monto >= 0.5 * Operaciones.Eventos.Costo_total
      );

    INSERT INTO Auditoria.EventoLog (Id_evento, Accion, Fecha)
    SELECT Id_evento, 'Cancelación automática por falta de pago', GETDATE()
    FROM Operaciones.Eventos
    WHERE Estado = 'Cancelado' AND Fecha_reserva <= @FechaCorte;

    COMMIT TRANSACTION;
END;
GO

-- Trigger trg_EventoFinalizadoOCancelado
-- Descripción: Cambia el estado de empleados a 'Disponible' cuando un evento se finaliza o cancela, si no tienen otros eventos activos.
-- Funcionamiento: Se activa tras actualizar el estado de un evento y registra los cambios en el log de empleados.
CREATE OR ALTER TRIGGER trg_EventoFinalizadoOCancelado
ON Operaciones.Eventos
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(Estado)
    BEGIN
        UPDATE Administracion.Empleados
        SET Estado_Empleado = (SELECT Id_estado FROM Administracion.Estado_Empleado WHERE Tipo_estado = 'Disponible')
        FROM Administracion.Empleados E
        JOIN Administracion.Rol_Empleado_Evento REE ON E.Id_empleado = REE.Id_empleado
        JOIN inserted I ON REE.Id_evento = I.Id_evento
        WHERE I.Estado IN ('Finalizado', 'Cancelado')
          AND NOT EXISTS (
              SELECT 1
              FROM Administracion.Rol_Empleado_Evento RE
              JOIN Operaciones.Eventos E2 ON RE.Id_evento = E2.Id_evento
              WHERE RE.Id_empleado = E.Id_empleado
                AND E2.Estado NOT IN ('Finalizado', 'Cancelado')
          );

        INSERT INTO Auditoria.EmpleadoLog (Id_empleado, Accion, Fecha)
        SELECT REE.Id_empleado, 'Cambio a Disponible por ' + I.Estado, GETDATE()
        FROM Administracion.Rol_Empleado_Evento REE
        JOIN inserted I ON REE.Id_evento = I.Id_evento
        WHERE I.Estado IN ('Finalizado', 'Cancelado');
    END
END;
GO

-- Trigger trg_ActualizarInventarioUtileria
-- Descripción: Reduce la cantidad de utilería asignada a un servicio en un evento y registra la acción.
-- Funcionamiento: Se activa tras insertar un servicio en un evento, actualiza el inventario de utilería y crea un log.
CREATE TRIGGER trg_ActualizarInventarioUtileria
ON Operaciones.Evento_Servicios
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Inventario.Utileria
    SET Cantidad = Cantidad - 1
    FROM Inventario.Utileria U
    JOIN Inventario.Servicio_Utileria SU ON U.Id_utileria = SU.Id_utileria
    JOIN inserted I ON SU.Id_servicio = I.Id_servicio
    WHERE U.Cantidad > 0;

    INSERT INTO Auditoria.InventarioLog (Id_utileria, Accion, Fecha)
    SELECT SU.Id_utileria, 'Resta por evento', GETDATE()
    FROM Inventario.Servicio_Utileria SU
    JOIN inserted I ON SU.Id_servicio = I.Id_servicio;
END;
GO

-- Trigger trg_RestaurarUtileriaEvento
-- Descripción: Restaura la cantidad de utilería cuando un evento se finaliza o cancela, y registra la acción.
-- Funcionamiento: Se activa tras actualizar un evento a 'Finalizado' o 'Cancelado', incrementa el inventario y crea un log.
CREATE TRIGGER trg_RestaurarUtileriaEvento
ON Operaciones.Eventos
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(Estado)
    BEGIN
        UPDATE Inventario.Utileria
        SET Cantidad = Cantidad + 1
        FROM Inventario.Utileria U
        JOIN Inventario.Servicio_Utileria SU ON U.Id_utileria = SU.Id_utileria
        JOIN Operaciones.Evento_Servicios ES ON SU.Id_servicio = ES.Id_servicio
        JOIN inserted I ON ES.Id_evento = I.Id_evento
        WHERE I.Estado IN ('Finalizado', 'Cancelado');

        INSERT INTO Auditoria.InventarioLog (Id_utileria, Accion, Fecha)
        SELECT SU.Id_utileria, 'Aumento por ' + I.Estado, GETDATE()
        FROM Inventario.Servicio_Utileria SU
        JOIN Operaciones.Evento_Servicios ES ON SU.Id_servicio = ES.Id_servicio
        JOIN inserted I ON ES.Id_evento = I.Id_evento
        WHERE I.Estado IN ('Finalizado', 'Cancelado');
    END
END;
GO