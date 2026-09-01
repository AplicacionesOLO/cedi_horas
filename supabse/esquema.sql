-- ═══════════════════════════════════════════════════════════════════════
-- CEDIS · Control de horas de personal externo (descarga de contenedores)
-- PostgreSQL 14+  ·  Moneda CRC  ·  Ciclo operativo VIERNES → JUEVES
-- ═══════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()

-- ───────────────────────────────────────────────────────────────
-- 1. CATÁLOGOS
-- ───────────────────────────────────────────────────────────────

CREATE TABLE departamento (
  id            smallserial PRIMARY KEY,
  nombre        text        NOT NULL UNIQUE,      -- Recepción, Congelados, Secos…
  centro_costo  text,
  activo        boolean     NOT NULL DEFAULT true
);

CREATE TABLE cliente (
  id            serial PRIMARY KEY,
  nombre        text   NOT NULL UNIQUE,
  codigo_cuenta text,                             -- cuenta contable / SAP
  activo        boolean NOT NULL DEFAULT true
);

-- Empresa de outsourcing que provee el personal (permite negociar tarifas distintas)
CREATE TABLE proveedor (
  id            serial PRIMARY KEY,
  nombre        text   NOT NULL UNIQUE,
  cedula_juridica text,
  activo        boolean NOT NULL DEFAULT true
);

CREATE TABLE colaborador (
  id             serial PRIMARY KEY,
  nombre_completo text  NOT NULL,
  identificacion text UNIQUE,                     -- cédula o DIMEX (evita duplicados por homónimo)
  proveedor_id   int REFERENCES proveedor(id),
  telefono       text,
  activo         boolean NOT NULL DEFAULT true,
  creado_en      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_colaborador_nombre ON colaborador USING gin (to_tsvector('spanish', nombre_completo));

CREATE TABLE usuario (
  id       serial PRIMARY KEY,
  nombre   text NOT NULL,
  correo   text NOT NULL UNIQUE,
  rol      text NOT NULL DEFAULT 'supervisor'
           CHECK (rol IN ('supervisor','auditor','gerente','admin')),
  activo   boolean NOT NULL DEFAULT true
);

-- Tarifa vigente por período. Nunca se edita: se cierra y se abre una nueva.
CREATE TABLE tarifa (
  id            serial PRIMARY KEY,
  proveedor_id  int REFERENCES proveedor(id),     -- NULL = tarifa general
  monto_crc     numeric(10,2) NOT NULL CHECK (monto_crc > 0),
  vigente_desde date NOT NULL,
  vigente_hasta date,                             -- NULL = vigente
  CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde)
);
CREATE UNIQUE INDEX ux_tarifa_vigente
  ON tarifa (COALESCE(proveedor_id, 0)) WHERE vigente_hasta IS NULL;

INSERT INTO tarifa (proveedor_id, monto_crc, vigente_desde) VALUES (NULL, 2750.00, '2024-01-01');

-- ───────────────────────────────────────────────────────────────
-- 2. OPERACIÓN
-- ───────────────────────────────────────────────────────────────

-- Embarque / contenedor. Un embarque se trabaja entre varias personas y una
-- persona trabaja varios embarques en el día  ⇒  relación N:M vía turno_embarque.
CREATE TABLE embarque (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo      text NOT NULL,                      -- MSCU1234567, BL, n.º de embarque
  tipo        text NOT NULL DEFAULT 'contenedor'
              CHECK (tipo IN ('contenedor','embarque','pallet','furgon')),
  cliente_id  int  REFERENCES cliente(id),
  fecha_arribo date,
  cerrado      boolean NOT NULL DEFAULT false,
  UNIQUE (codigo, fecha_arribo)
);
CREATE INDEX ix_embarque_codigo ON embarque (upper(codigo));

-- Un turno = una persona, un día, una entrada y una salida.
CREATE TABLE turno (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fecha           date NOT NULL,
  departamento_id smallint NOT NULL REFERENCES departamento(id),
  colaborador_id  int      NOT NULL REFERENCES colaborador(id),
  cliente_id      int      NOT NULL REFERENCES cliente(id),
  hora_entrada    time NOT NULL,
  hora_salida     time NOT NULL,
  descanso_min    smallint NOT NULL DEFAULT 0 CHECK (descanso_min BETWEEN 0 AND 480),

  -- Entrada y salida iguales no son un turno de 24 h, son un error de digitación.
  CONSTRAINT turno_horas_distintas CHECK (hora_salida <> hora_entrada),

  -- Congelamos la tarifa al momento del registro: si mañana sube, el histórico no se mueve.
  tarifa_hora_crc numeric(10,2) NOT NULL,

  -- Horas netas. Suma 24 h cuando el turno cruza medianoche y resta el descanso.
  horas_totales numeric(6,2) GENERATED ALWAYS AS (
    round((
      ( EXTRACT(EPOCH FROM (hora_salida - hora_entrada))
        + CASE WHEN hora_salida < hora_entrada THEN 86400 ELSE 0 END
        - descanso_min * 60 ) / 3600.0
    )::numeric, 2)
  ) STORED,

  nota            text,
  registrado_por  int REFERENCES usuario(id),
  creado_en       timestamptz NOT NULL DEFAULT now(),
  actualizado_en  timestamptz NOT NULL DEFAULT now(),

  -- Una persona no puede tener dos turnos idénticos el mismo día
  UNIQUE (colaborador_id, fecha, hora_entrada)
);
CREATE INDEX ix_turno_fecha        ON turno (fecha);
CREATE INDEX ix_turno_cliente      ON turno (cliente_id, fecha);
CREATE INDEX ix_turno_departamento ON turno (departamento_id, fecha);

-- Tabla puente N:M — el requerimiento de "N embarques por día por colaborador".
-- horas_asignadas permite repartir la jornada entre contenedores para costeo por cuenta.
CREATE TABLE turno_embarque (
  turno_id       uuid NOT NULL REFERENCES turno(id)    ON DELETE CASCADE,
  embarque_id    uuid NOT NULL REFERENCES embarque(id) ON DELETE RESTRICT,
  horas_asignadas numeric(5,2) CHECK (horas_asignadas IS NULL OR horas_asignadas >= 0),
  PRIMARY KEY (turno_id, embarque_id)
);

-- ───────────────────────────────────────────────────────────────
-- 3. PRESUPUESTO
-- ───────────────────────────────────────────────────────────────

CREATE TABLE presupuesto (
  id              serial PRIMARY KEY,
  anio            smallint NOT NULL CHECK (anio BETWEEN 2020 AND 2100),
  mes             smallint NOT NULL CHECK (mes BETWEEN 1 AND 12),
  departamento_id smallint REFERENCES departamento(id),   -- NULL = presupuesto global del CEDIS
  monto_crc       numeric(14,2) NOT NULL CHECK (monto_crc >= 0),
  aprobado_por    int REFERENCES usuario(id),
  aprobado_en     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (anio, mes, departamento_id)
);

-- ───────────────────────────────────────────────────────────────
-- 4. FUNCIONES DEL CICLO VIERNES → JUEVES
-- ───────────────────────────────────────────────────────────────

-- Viernes que abre el ciclo al que pertenece la fecha.
-- EXTRACT(DOW): 0=domingo … 5=viernes … 6=sábado
CREATE OR REPLACE FUNCTION inicio_ciclo(f date) RETURNS date
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS $$
  SELECT f - ((EXTRACT(DOW FROM f)::int - 5 + 7) % 7);
$$;

CREATE OR REPLACE FUNCTION fin_ciclo(f date) RETURNS date
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS $$
  SELECT inicio_ciclo(f) + 6;                       -- jueves
$$;

-- Ciclo desplazado: 0 = el que contiene la fecha (en curso), -1 = el recién cerrado.
CREATE OR REPLACE FUNCTION ciclo(f date, offset_semanas int DEFAULT 0,
                                 OUT desde date, OUT hasta date)
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT inicio_ciclo(f) + offset_semanas * 7,
         inicio_ciclo(f) + offset_semanas * 7 + 6;
$$;

-- Ciclo que corresponde auditar hoy: siempre el último cerrado.
CREATE OR REPLACE FUNCTION ciclo_auditoria(OUT desde date, OUT hasta date)
LANGUAGE sql STABLE AS $$ SELECT desde, hasta FROM ciclo(CURRENT_DATE, -1); $$;

-- Índice funcional: los reportes filtran casi siempre por ciclo, no por fecha suelta.
CREATE INDEX ix_turno_ciclo ON turno (inicio_ciclo(fecha));

-- ───────────────────────────────────────────────────────────────
-- 5. REGLAS DE INTEGRIDAD
-- ───────────────────────────────────────────────────────────────

-- Las horas repartidas entre embarques no pueden exceder la jornada.
CREATE OR REPLACE FUNCTION fn_valida_reparto() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_asignadas numeric; v_jornada numeric;
BEGIN
  SELECT COALESCE(SUM(horas_asignadas), 0) INTO v_asignadas
    FROM turno_embarque WHERE turno_id = COALESCE(NEW.turno_id, OLD.turno_id);
  SELECT horas_totales INTO v_jornada
    FROM turno WHERE id = COALESCE(NEW.turno_id, OLD.turno_id);
  IF v_asignadas > v_jornada + 0.01 THEN
    RAISE EXCEPTION 'El reparto por embarque (% h) excede la jornada del turno (% h)',
      v_asignadas, v_jornada;
  END IF;
  RETURN NEW;
END $$;

CREATE CONSTRAINT TRIGGER tg_valida_reparto
  AFTER INSERT OR UPDATE ON turno_embarque
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION fn_valida_reparto();

-- Una persona no puede estar en dos turnos solapados el mismo día.
CREATE OR REPLACE FUNCTION fn_sin_solape() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM turno t
     WHERE t.colaborador_id = NEW.colaborador_id
       AND t.fecha = NEW.fecha
       AND t.id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
       AND (NEW.hora_entrada, NEW.hora_salida) OVERLAPS (t.hora_entrada, t.hora_salida)
  ) THEN
    RAISE EXCEPTION 'El colaborador ya tiene un turno que se traslapa ese día';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER tg_sin_solape BEFORE INSERT OR UPDATE ON turno
  FOR EACH ROW EXECUTE FUNCTION fn_sin_solape();

-- Asigna la tarifa vigente si el cliente de la API no la envía.
CREATE OR REPLACE FUNCTION fn_tarifa_vigente() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tarifa_hora_crc IS NULL THEN
    SELECT t.monto_crc INTO NEW.tarifa_hora_crc
      FROM tarifa t
      LEFT JOIN colaborador c ON c.id = NEW.colaborador_id
     WHERE (t.proveedor_id IS NOT DISTINCT FROM c.proveedor_id OR t.proveedor_id IS NULL)
       AND NEW.fecha >= t.vigente_desde
       AND (t.vigente_hasta IS NULL OR NEW.fecha <= t.vigente_hasta)
     ORDER BY t.proveedor_id NULLS LAST
     LIMIT 1;
  END IF;
  NEW.actualizado_en := now();
  RETURN NEW;
END $$;

CREATE TRIGGER tg_tarifa_vigente BEFORE INSERT OR UPDATE ON turno
  FOR EACH ROW EXECUTE FUNCTION fn_tarifa_vigente();

-- ───────────────────────────────────────────────────────────────
-- 6. VISTAS DE REPORTE
-- ───────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_turno AS
SELECT t.id, t.fecha,
       inicio_ciclo(t.fecha)                     AS ciclo_desde,
       fin_ciclo(t.fecha)                        AS ciclo_hasta,
       to_char(t.fecha, 'YYYY-MM')               AS anio_mes,
       d.nombre  AS departamento,
       cl.nombre AS cliente,
       co.nombre_completo AS colaborador,
       pr.nombre AS proveedor,
       t.hora_entrada, t.hora_salida, t.descanso_min,
       t.horas_totales,
       t.tarifa_hora_crc,
       round(t.horas_totales * t.tarifa_hora_crc) AS costo_crc,
       t.nota,
       (SELECT count(*) FROM turno_embarque te WHERE te.turno_id = t.id) AS n_embarques,
       (SELECT string_agg(e.codigo, ' | ' ORDER BY e.codigo)
          FROM turno_embarque te JOIN embarque e ON e.id = te.embarque_id
         WHERE te.turno_id = t.id) AS embarques
  FROM turno t
  JOIN departamento d  ON d.id  = t.departamento_id
  JOIN cliente cl      ON cl.id = t.cliente_id
  JOIN colaborador co  ON co.id = t.colaborador_id
  LEFT JOIN proveedor pr ON pr.id = co.proveedor_id;

-- Serie semanal: la base del dashboard y del algoritmo de proyección.
CREATE OR REPLACE VIEW v_ciclo_semanal AS
SELECT ciclo_desde, ciclo_hasta,
       count(*)                              AS turnos,
       count(DISTINCT colaborador)           AS personas,
       sum(horas_totales)                    AS horas,
       sum(costo_crc)                        AS costo_crc,
       round(avg(horas_totales), 2)          AS horas_por_turno
  FROM v_turno
 GROUP BY ciclo_desde, ciclo_hasta
 ORDER BY ciclo_desde;

CREATE OR REPLACE VIEW v_ciclo_cliente AS
SELECT ciclo_desde, ciclo_hasta, cliente,
       sum(horas_totales) AS horas, sum(costo_crc) AS costo_crc,
       round(100 * sum(costo_crc) / NULLIF(sum(sum(costo_crc)) OVER (PARTITION BY ciclo_desde), 0), 1) AS pct
  FROM v_turno GROUP BY 1,2,3;

CREATE OR REPLACE VIEW v_ciclo_departamento AS
SELECT ciclo_desde, ciclo_hasta, departamento,
       sum(horas_totales) AS horas, sum(costo_crc) AS costo_crc
  FROM v_turno GROUP BY 1,2,3;

-- Presupuesto contra ejecución, con cierre proyectado por ritmo de gasto.
CREATE OR REPLACE VIEW v_presupuesto_ejecucion AS
WITH real AS (
  SELECT anio_mes, sum(costo_crc) AS gastado, sum(horas_totales) AS horas
    FROM v_turno GROUP BY anio_mes
)
SELECT p.anio, p.mes,
       to_char(make_date(p.anio, p.mes, 1), 'YYYY-MM') AS anio_mes,
       p.monto_crc                                     AS presupuesto,
       COALESCE(r.gastado, 0)                          AS gastado,
       COALESCE(r.horas, 0)                            AS horas,
       p.monto_crc - COALESCE(r.gastado, 0)            AS disponible,
       round(100 * COALESCE(r.gastado,0) / NULLIF(p.monto_crc,0), 1) AS pct_ejecucion,
       -- ritmo diario × días del mes = cierre proyectado
       round(
         COALESCE(r.gastado,0)
         / GREATEST(1, LEAST(
             EXTRACT(DAY FROM (date_trunc('month', make_date(p.anio,p.mes,1))
                               + interval '1 month - 1 day'))::int,
             CASE WHEN date_trunc('month', CURRENT_DATE) = date_trunc('month', make_date(p.anio,p.mes,1))
                  THEN EXTRACT(DAY FROM CURRENT_DATE)::int
                  ELSE 99 END))
         * EXTRACT(DAY FROM (date_trunc('month', make_date(p.anio,p.mes,1))
                             + interval '1 month - 1 day'))::int
       ) AS cierre_proyectado
  FROM presupuesto p
  LEFT JOIN real r ON r.anio_mes = to_char(make_date(p.anio, p.mes, 1), 'YYYY-MM')
 WHERE p.departamento_id IS NULL;

-- ───────────────────────────────────────────────────────────────
-- 7. CONSULTAS DE USO FRECUENTE
-- ───────────────────────────────────────────────────────────────

-- Auditoría del viernes: el ciclo recién cerrado, línea por línea.
--   SELECT * FROM v_turno
--    WHERE (fecha, fecha) OVERLAPS (SELECT desde, hasta FROM ciclo_auditoria());
--
-- Resumen del ciclo a auditar:
--   SELECT * FROM v_ciclo_semanal
--    WHERE ciclo_desde = (SELECT desde FROM ciclo_auditoria());
--
-- Serie para proyección (últimos 8 ciclos cerrados):
--   SELECT ciclo_desde, horas, costo_crc FROM v_ciclo_semanal
--    WHERE ciclo_hasta < inicio_ciclo(CURRENT_DATE)
--    ORDER BY ciclo_desde DESC LIMIT 8;

-- ───────────────────────────────────────────────────────────────
-- 8. SEMILLA MÍNIMA
-- ───────────────────────────────────────────────────────────────
INSERT INTO departamento (nombre) VALUES
  ('Recepción'), ('Congelados'), ('Refrigerados'), ('Secos'), ('Abarrotes'), ('Devoluciones')
ON CONFLICT DO NOTHING;
