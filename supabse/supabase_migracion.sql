-- ═══════════════════════════════════════════════════════════════════════
-- OLO · Horas de personal externo — CEDIS Costa Rica
-- Migración para Supabase (PostgreSQL 15+)
--
-- CÓMO CORRERLO
--   Supabase Studio → SQL Editor → New query → pegar todo → Run
--   o bien:  supabase db push   (guardándolo en supabase/migrations/)
--
-- Se entrega SIN DATOS OPERATIVOS: no hay turnos, embarques ni presupuestos.
-- Solo se cargan los catálogos fijos (departamentos, clientes y la tarifa
-- vigente de ₡2.750/hora), que el sistema necesita para poder registrar.
-- Si tampoco los querés, comentá el bloque 9 al final.
--
-- Es idempotente: se puede volver a correr sin romper nada.
-- ═══════════════════════════════════════════════════════════════════════

-- Sin extensiones: gen_random_uuid() es nativo desde PostgreSQL 13.
-- (No se instala pgcrypto a propósito: metería 30 funciones en public que el
--  linter de seguridad de Supabase marca por no tener search_path fijo.)

-- ───────────────────────────────────────────────────────────────
-- 1. PERFILES  (se enlazan a auth.users de Supabase)
-- ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.perfil (
  id         uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre     text NOT NULL DEFAULT '',
  correo     text,
  rol        text NOT NULL DEFAULT 'supervisor'
             CHECK (rol IN ('supervisor','auditor','gerente','admin')),
  activo     boolean NOT NULL DEFAULT true,
  creado_en  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.perfil IS
  'supervisor: registra turnos · auditor: solo lectura · gerente: además presupuestos · admin: todo';

-- Al registrarse un usuario nuevo en Supabase Auth se le crea el perfil.
CREATE OR REPLACE FUNCTION public.fn_nuevo_usuario()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.perfil (id, nombre, correo)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'nombre', split_part(NEW.email,'@',1)), NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS tg_nuevo_usuario ON auth.users;
CREATE TRIGGER tg_nuevo_usuario
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.fn_nuevo_usuario();

-- SECURITY DEFINER a propósito: si leyera perfil bajo RLS, las políticas que
-- la usan entrarían en recursión infinita.
CREATE OR REPLACE FUNCTION public.rol_actual()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$ SELECT COALESCE((SELECT p.rol FROM public.perfil p WHERE p.id = auth.uid() AND p.activo), 'ninguno'); $$;

-- Tener sesión en Supabase no basta: hace falta un perfil activo en el CEDIS.
CREATE OR REPLACE FUNCTION public.es_del_cedis()
RETURNS boolean
LANGUAGE sql STABLE SET search_path = ''
AS $$ SELECT public.rol_actual() <> 'ninguno'; $$;

CREATE OR REPLACE FUNCTION public.puede_escribir()
RETURNS boolean
LANGUAGE sql STABLE SET search_path = ''
AS $$ SELECT public.rol_actual() IN ('supervisor','gerente','admin'); $$;

CREATE OR REPLACE FUNCTION public.puede_administrar()
RETURNS boolean
LANGUAGE sql STABLE SET search_path = ''
AS $$ SELECT public.rol_actual() IN ('gerente','admin'); $$;

-- ───────────────────────────────────────────────────────────────
-- 2. CATÁLOGOS
-- ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.departamento (
  id       smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre   text NOT NULL UNIQUE,
  orden    smallint NOT NULL DEFAULT 100,   -- controla el orden de los chips en el formulario
  activo   boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.cliente (
  id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre        text NOT NULL UNIQUE,
  codigo_cuenta text,
  activo        boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.proveedor (
  id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre          text NOT NULL UNIQUE,
  cedula_juridica text,
  activo          boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.colaborador (
  id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre_completo text NOT NULL,
  identificacion  text UNIQUE,               -- cédula o DIMEX: evita duplicar homónimos
  proveedor_id    integer REFERENCES public.proveedor(id) ON DELETE SET NULL,
  telefono        text,
  activo          boolean NOT NULL DEFAULT true,
  creado_en       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_colaborador_nombre
  ON public.colaborador USING gin (to_tsvector('spanish', nombre_completo));

-- Tarifa por período. No se edita: se cierra la vigente y se abre una nueva.
CREATE TABLE IF NOT EXISTS public.tarifa (
  id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  proveedor_id  integer REFERENCES public.proveedor(id) ON DELETE CASCADE,  -- NULL = tarifa general
  monto_crc     numeric(10,2) NOT NULL CHECK (monto_crc > 0),
  vigente_desde date NOT NULL,
  vigente_hasta date,
  CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_tarifa_vigente
  ON public.tarifa (COALESCE(proveedor_id, 0)) WHERE vigente_hasta IS NULL;

-- ───────────────────────────────────────────────────────────────
-- 3. FUNCIONES DEL CICLO VIERNES → JUEVES
-- ───────────────────────────────────────────────────────────────

-- EXTRACT(DOW): 0=domingo … 5=viernes … 6=sábado
CREATE OR REPLACE FUNCTION public.inicio_ciclo(f date)
RETURNS date
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE SET search_path = ''
AS $$ SELECT f - ((EXTRACT(DOW FROM f)::int - 5 + 7) % 7); $$;

CREATE OR REPLACE FUNCTION public.fin_ciclo(f date)
RETURNS date
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE SET search_path = ''
AS $$ SELECT public.inicio_ciclo(f) + 6; $$;

-- offset 0 = ciclo en curso · −1 = el recién cerrado (el que toca auditar)
CREATE OR REPLACE FUNCTION public.ciclo(f date DEFAULT CURRENT_DATE, offset_semanas int DEFAULT 0,
                                        OUT desde date, OUT hasta date)
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = ''
AS $$ SELECT public.inicio_ciclo(f) + offset_semanas * 7,
             public.inicio_ciclo(f) + offset_semanas * 7 + 6; $$;

-- ───────────────────────────────────────────────────────────────
-- 4. OPERACIÓN
-- ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.embarque (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo       text NOT NULL,
  tipo         text NOT NULL DEFAULT 'contenedor'
               CHECK (tipo IN ('contenedor','embarque','pallet','furgon')),
  cliente_id   integer REFERENCES public.cliente(id) ON DELETE SET NULL,
  fecha_arribo date,
  cerrado      boolean NOT NULL DEFAULT false,
  creado_en    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (codigo, fecha_arribo)
);
CREATE INDEX IF NOT EXISTS ix_embarque_codigo ON public.embarque (upper(codigo));

-- Un turno = una persona, un día, una entrada y una salida.
CREATE TABLE IF NOT EXISTS public.turno (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fecha           date NOT NULL,
  departamento_id smallint NOT NULL REFERENCES public.departamento(id),
  colaborador_id  integer  NOT NULL REFERENCES public.colaborador(id),
  cliente_id      integer  NOT NULL REFERENCES public.cliente(id),
  hora_entrada    time NOT NULL,
  hora_salida     time NOT NULL,
  descanso_min    smallint NOT NULL DEFAULT 0 CHECK (descanso_min BETWEEN 0 AND 480),

  -- Entrada y salida iguales no son un turno de 24 h, son un error de digitación.
  CONSTRAINT turno_horas_distintas CHECK (hora_salida <> hora_entrada),

  -- Tarifa congelada al registrar: si mañana sube, el histórico no se mueve.
  tarifa_hora_crc numeric(10,2) NOT NULL,

  -- Horas netas: suma 24 h si el turno cruza medianoche y descuenta el descanso.
  horas_totales numeric(6,2) GENERATED ALWAYS AS (
    round((
      ( EXTRACT(EPOCH FROM (hora_salida - hora_entrada))
        + CASE WHEN hora_salida < hora_entrada THEN 86400 ELSE 0 END
        - descanso_min * 60 ) / 3600.0
    )::numeric, 2)
  ) STORED,

  nota            text,
  registrado_por  uuid REFERENCES public.perfil(id) ON DELETE SET NULL,
  creado_en       timestamptz NOT NULL DEFAULT now(),
  actualizado_en  timestamptz NOT NULL DEFAULT now(),

  UNIQUE (colaborador_id, fecha, hora_entrada)
);
CREATE INDEX IF NOT EXISTS ix_turno_fecha        ON public.turno (fecha);
CREATE INDEX IF NOT EXISTS ix_turno_cliente      ON public.turno (cliente_id, fecha);
CREATE INDEX IF NOT EXISTS ix_turno_departamento ON public.turno (departamento_id, fecha);
CREATE INDEX IF NOT EXISTS ix_turno_colaborador  ON public.turno (colaborador_id, fecha);

-- N:M — el requerimiento de varios embarques por día por colaborador.
CREATE TABLE IF NOT EXISTS public.turno_embarque (
  turno_id        uuid NOT NULL REFERENCES public.turno(id)    ON DELETE CASCADE,
  embarque_id     uuid NOT NULL REFERENCES public.embarque(id) ON DELETE RESTRICT,
  horas_asignadas numeric(5,2) CHECK (horas_asignadas IS NULL OR horas_asignadas >= 0),
  PRIMARY KEY (turno_id, embarque_id)
);
CREATE INDEX IF NOT EXISTS ix_turno_embarque_emb ON public.turno_embarque (embarque_id);

CREATE TABLE IF NOT EXISTS public.presupuesto (
  id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  anio            smallint NOT NULL CHECK (anio BETWEEN 2020 AND 2100),
  mes             smallint NOT NULL CHECK (mes BETWEEN 1 AND 12),
  departamento_id smallint REFERENCES public.departamento(id) ON DELETE CASCADE, -- NULL = global
  monto_crc       numeric(14,2) NOT NULL CHECK (monto_crc >= 0),
  aprobado_por    uuid REFERENCES public.perfil(id) ON DELETE SET NULL,
  aprobado_en     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_presupuesto_global
  ON public.presupuesto (anio, mes) WHERE departamento_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_presupuesto_depto
  ON public.presupuesto (anio, mes, departamento_id) WHERE departamento_id IS NOT NULL;

-- ───────────────────────────────────────────────────────────────
-- 5. REGLAS DE INTEGRIDAD
-- ───────────────────────────────────────────────────────────────

-- Asigna la tarifa vigente si el cliente no la manda, y sella actualizado_en.
CREATE OR REPLACE FUNCTION public.fn_tarifa_vigente()
RETURNS trigger
LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF NEW.tarifa_hora_crc IS NULL THEN
    SELECT t.monto_crc INTO NEW.tarifa_hora_crc
      FROM public.tarifa t
      LEFT JOIN public.colaborador c ON c.id = NEW.colaborador_id
     WHERE (t.proveedor_id IS NOT DISTINCT FROM c.proveedor_id OR t.proveedor_id IS NULL)
       AND NEW.fecha >= t.vigente_desde
       AND (t.vigente_hasta IS NULL OR NEW.fecha <= t.vigente_hasta)
     ORDER BY t.proveedor_id NULLS LAST
     LIMIT 1;
  END IF;
  IF NEW.tarifa_hora_crc IS NULL THEN
    RAISE EXCEPTION 'No hay tarifa vigente para el % . Cargá una en la tabla tarifa.', NEW.fecha;
  END IF;
  NEW.actualizado_en := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS tg_tarifa_vigente ON public.turno;
CREATE TRIGGER tg_tarifa_vigente BEFORE INSERT OR UPDATE ON public.turno
  FOR EACH ROW EXECUTE FUNCTION public.fn_tarifa_vigente();

-- Una persona no puede tener dos turnos traslapados el mismo día.
CREATE OR REPLACE FUNCTION public.fn_sin_solape()
RETURNS trigger
LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.turno t
     WHERE t.colaborador_id = NEW.colaborador_id
       AND t.fecha = NEW.fecha
       AND t.id <> NEW.id
       AND (NEW.hora_entrada, NEW.hora_salida) OVERLAPS (t.hora_entrada, t.hora_salida)
  ) THEN
    RAISE EXCEPTION 'El colaborador ya tiene un turno que se traslapa ese día';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS tg_sin_solape ON public.turno;
CREATE TRIGGER tg_sin_solape BEFORE INSERT OR UPDATE ON public.turno
  FOR EACH ROW EXECUTE FUNCTION public.fn_sin_solape();

-- El reparto por embarque no puede exceder la jornada.
CREATE OR REPLACE FUNCTION public.fn_valida_reparto()
RETURNS trigger
LANGUAGE plpgsql SET search_path = ''
AS $$
DECLARE v_asignadas numeric; v_jornada numeric;
BEGIN
  SELECT COALESCE(SUM(te.horas_asignadas), 0) INTO v_asignadas
    FROM public.turno_embarque te WHERE te.turno_id = COALESCE(NEW.turno_id, OLD.turno_id);
  SELECT t.horas_totales INTO v_jornada
    FROM public.turno t WHERE t.id = COALESCE(NEW.turno_id, OLD.turno_id);
  IF v_jornada IS NOT NULL AND v_asignadas > v_jornada + 0.01 THEN
    RAISE EXCEPTION 'El reparto por embarque (% h) excede la jornada del turno (% h)', v_asignadas, v_jornada;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS tg_valida_reparto ON public.turno_embarque;
CREATE CONSTRAINT TRIGGER tg_valida_reparto
  AFTER INSERT OR UPDATE ON public.turno_embarque
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION public.fn_valida_reparto();

-- ───────────────────────────────────────────────────────────────
-- 6. VISTAS  (security_invoker: respetan el RLS de quien consulta)
-- ───────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW public.v_turno WITH (security_invoker = on) AS
SELECT t.id, t.fecha,
       public.inicio_ciclo(t.fecha)              AS ciclo_desde,
       public.fin_ciclo(t.fecha)                 AS ciclo_hasta,
       to_char(t.fecha, 'YYYY-MM')               AS anio_mes,
       t.departamento_id, d.nombre  AS departamento,
       t.cliente_id,      cl.nombre AS cliente,
       t.colaborador_id,  co.nombre_completo AS colaborador,
       pr.nombre AS proveedor,
       t.hora_entrada, t.hora_salida, t.descanso_min,
       t.horas_totales, t.tarifa_hora_crc,
       round(t.horas_totales * t.tarifa_hora_crc) AS costo_crc,
       t.nota, t.registrado_por, t.creado_en,
       (SELECT count(*) FROM public.turno_embarque te WHERE te.turno_id = t.id) AS n_embarques,
       (SELECT string_agg(e.codigo, ' | ' ORDER BY e.codigo)
          FROM public.turno_embarque te
          JOIN public.embarque e ON e.id = te.embarque_id
         WHERE te.turno_id = t.id) AS embarques
  FROM public.turno t
  JOIN public.departamento d ON d.id  = t.departamento_id
  JOIN public.cliente cl     ON cl.id = t.cliente_id
  JOIN public.colaborador co ON co.id = t.colaborador_id
  LEFT JOIN public.proveedor pr ON pr.id = co.proveedor_id;

-- Serie semanal: base del tablero y del algoritmo de proyección.
CREATE OR REPLACE VIEW public.v_ciclo_semanal WITH (security_invoker = on) AS
SELECT ciclo_desde, ciclo_hasta,
       count(*)                       AS turnos,
       count(DISTINCT colaborador_id) AS personas,
       sum(horas_totales)             AS horas,
       sum(costo_crc)                 AS costo_crc,
       round(avg(horas_totales), 2)   AS horas_por_turno
  FROM public.v_turno
 GROUP BY ciclo_desde, ciclo_hasta;

CREATE OR REPLACE VIEW public.v_ciclo_cliente WITH (security_invoker = on) AS
SELECT ciclo_desde, ciclo_hasta, cliente,
       sum(horas_totales) AS horas, sum(costo_crc) AS costo_crc,
       round(100 * sum(costo_crc) / NULLIF(sum(sum(costo_crc)) OVER (PARTITION BY ciclo_desde), 0), 1) AS pct
  FROM public.v_turno GROUP BY 1, 2, 3;

CREATE OR REPLACE VIEW public.v_ciclo_departamento WITH (security_invoker = on) AS
SELECT ciclo_desde, ciclo_hasta, departamento,
       sum(horas_totales) AS horas, sum(costo_crc) AS costo_crc
  FROM public.v_turno GROUP BY 1, 2, 3;

CREATE OR REPLACE VIEW public.v_mes WITH (security_invoker = on) AS
SELECT anio_mes,
       sum(horas_totales) AS horas,
       sum(costo_crc)     AS costo_crc,
       count(*)           AS turnos
  FROM public.v_turno GROUP BY anio_mes;

-- ───────────────────────────────────────────────────────────────
-- 7. FUNCIONES QUE CONSUME LA APLICACIÓN  (supabase.rpc)
-- ───────────────────────────────────────────────────────────────

-- Registra el turno y sus N embarques en una sola transacción.
-- p_embarques: [{"codigo":"MSCU1234567","horas":5.5,"tipo":"contenedor"}, …]
-- Los parámetros van en integer, no smallint: PostgREST y supabase-js mandan
-- los números JSON como integer y no hacen la conversión implícita al resolver
-- la firma. El casteo se hace adentro.
CREATE OR REPLACE FUNCTION public.registrar_turno(
  p_fecha date, p_departamento_id integer, p_colaborador_id integer, p_cliente_id integer,
  p_hora_entrada time, p_hora_salida time, p_descanso_min integer DEFAULT 0,
  p_nota text DEFAULT NULL, p_embarques jsonb DEFAULT '[]'::jsonb
) RETURNS public.turno
LANGUAGE plpgsql SET search_path = ''
AS $$
DECLARE v_turno public.turno; v_emb jsonb; v_id uuid;
BEGIN
  INSERT INTO public.turno (fecha, departamento_id, colaborador_id, cliente_id,
                            hora_entrada, hora_salida, descanso_min, nota,
                            registrado_por, tarifa_hora_crc)
  VALUES (p_fecha, p_departamento_id::smallint, p_colaborador_id, p_cliente_id,
          p_hora_entrada, p_hora_salida, COALESCE(p_descanso_min,0)::smallint, p_nota,
          auth.uid(), NULL)
  RETURNING * INTO v_turno;

  IF v_turno.horas_totales <= 0 THEN
    RAISE EXCEPTION 'El turno resulta en cero horas. Revisá entrada, salida y descanso.';
  END IF;

  FOR v_emb IN SELECT * FROM jsonb_array_elements(COALESCE(p_embarques,'[]'::jsonb)) LOOP
    CONTINUE WHEN COALESCE(trim(v_emb->>'codigo'), '') = '';
    INSERT INTO public.embarque (codigo, tipo, cliente_id, fecha_arribo)
    VALUES (upper(trim(v_emb->>'codigo')), COALESCE(v_emb->>'tipo','contenedor'), p_cliente_id, p_fecha)
    ON CONFLICT (codigo, fecha_arribo) DO UPDATE SET cliente_id = EXCLUDED.cliente_id
    RETURNING id INTO v_id;

    INSERT INTO public.turno_embarque (turno_id, embarque_id, horas_asignadas)
    VALUES (v_turno.id, v_id, NULLIF(v_emb->>'horas','')::numeric)
    ON CONFLICT (turno_id, embarque_id) DO UPDATE SET horas_asignadas = EXCLUDED.horas_asignadas;
  END LOOP;

  RETURN v_turno;
END $$;

-- Auditoría del ciclo. p_offset −1 = el recién cerrado (el que toca revisar).
CREATE OR REPLACE FUNCTION public.resumen_ciclo(p_offset integer DEFAULT -1)
RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = ''
AS $$
DECLARE d date; h date; res jsonb;
BEGIN
  SELECT c.desde, c.hasta INTO d, h FROM public.ciclo(CURRENT_DATE, p_offset) c;

  SELECT jsonb_build_object(
    'ciclo',   jsonb_build_object('desde', d, 'hasta', h, 'offset', p_offset, 'abierto', p_offset >= 0),
    'resumen', COALESCE((SELECT to_jsonb(s) FROM public.v_ciclo_semanal s WHERE s.ciclo_desde = d),
                        jsonb_build_object('turnos',0,'personas',0,'horas',0,'costo_crc',0)),
    'por_cliente',      COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.costo_crc DESC)
                                    FROM public.v_ciclo_cliente x WHERE x.ciclo_desde = d), '[]'::jsonb),
    'por_departamento', COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.costo_crc DESC)
                                    FROM public.v_ciclo_departamento x WHERE x.ciclo_desde = d), '[]'::jsonb),
    'por_colaborador',  COALESCE((SELECT jsonb_agg(y ORDER BY (y->>'costo_crc')::numeric DESC) FROM (
                                    SELECT jsonb_build_object('colaborador', v.colaborador,
                                             'turnos', count(*), 'horas', sum(v.horas_totales),
                                             'costo_crc', sum(v.costo_crc)) AS y
                                      FROM public.v_turno v WHERE v.fecha BETWEEN d AND h
                                     GROUP BY v.colaborador) q), '[]'::jsonb),
    'detalle',          COALESCE((SELECT jsonb_agg(to_jsonb(v) ORDER BY v.fecha, v.hora_entrada)
                                    FROM public.v_turno v WHERE v.fecha BETWEEN d AND h), '[]'::jsonb)
  ) INTO res;
  RETURN res;
END $$;

-- Serie de los últimos N ciclos CERRADOS: entrada del algoritmo de proyección.
CREATE OR REPLACE FUNCTION public.serie_semanal(p_n integer DEFAULT 8)
RETURNS TABLE (ciclo_desde date, ciclo_hasta date, horas numeric, costo_crc numeric, personas bigint)
LANGUAGE sql STABLE SET search_path = ''
AS $$
  -- i = cuántos ciclos hacia atrás. i=1 es el recién cerrado.
  -- Se genera la rejilla completa para que las semanas sin movimiento
  -- aparezcan en cero y no se pierda la forma de la serie.
  SELECT (public.inicio_ciclo(CURRENT_DATE) - s.i * 7)::date,
         (public.inicio_ciclo(CURRENT_DATE) - s.i * 7 + 6)::date,
         COALESCE(sum(v.horas_totales), 0)::numeric,
         COALESCE(sum(v.costo_crc), 0)::numeric,
         count(DISTINCT v.colaborador_id)
    FROM generate_series(p_n, 1, -1) AS s(i)
    LEFT JOIN public.v_turno v
           ON v.fecha BETWEEN (public.inicio_ciclo(CURRENT_DATE) - s.i * 7)
                          AND (public.inicio_ciclo(CURRENT_DATE) - s.i * 7 + 6)
   GROUP BY s.i
   ORDER BY s.i DESC;
$$;

-- Ejecución presupuestaria con cierre proyectado por ritmo de gasto.
CREATE OR REPLACE FUNCTION public.ejecucion_presupuesto(p_anio integer, p_mes integer)
RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = ''
AS $$
DECLARE
  v_pres numeric := 0; v_gasto numeric := 0; v_horas numeric := 0;
  v_dias int; v_transc int; v_ritmo numeric; v_proy numeric; v_pct_proy numeric;
BEGIN
  SELECT COALESCE(p.monto_crc, 0) INTO v_pres FROM public.presupuesto p
   WHERE p.anio = p_anio AND p.mes = p_mes AND p.departamento_id IS NULL;

  SELECT COALESCE(m.costo_crc,0), COALESCE(m.horas,0) INTO v_gasto, v_horas
    FROM public.v_mes m WHERE m.anio_mes = to_char(make_date(p_anio, p_mes, 1), 'YYYY-MM');

  v_dias := EXTRACT(DAY FROM (date_trunc('month', make_date(p_anio,p_mes,1)) + interval '1 month - 1 day'))::int;
  v_transc := CASE WHEN date_trunc('month', CURRENT_DATE) = date_trunc('month', make_date(p_anio,p_mes,1))
                   THEN GREATEST(1, EXTRACT(DAY FROM CURRENT_DATE)::int) ELSE v_dias END;
  v_ritmo := COALESCE(v_gasto,0) / v_transc;
  v_proy  := v_ritmo * v_dias;
  v_pct_proy := CASE WHEN v_pres > 0 THEN v_proy / v_pres ELSE 0 END;

  RETURN jsonb_build_object(
    'anio', p_anio, 'mes', p_mes,
    'presupuesto', v_pres, 'gastado', v_gasto, 'horas', v_horas,
    'disponible', v_pres - v_gasto,
    'dias', v_dias, 'dias_transcurridos', v_transc,
    'ritmo_diario', round(v_ritmo),
    'cierre_proyectado', round(v_proy),
    'pct', CASE WHEN v_pres > 0 THEN round(v_gasto / v_pres, 4) ELSE 0 END,
    'pct_proyectado', round(v_pct_proy, 4),
    'estado', CASE WHEN v_pres <= 0 THEN 'sin'
                   WHEN v_pct_proy > 1.05 THEN 'excedido'
                   WHEN v_pct_proy > 0.95 THEN 'limite'
                   ELSE 'meta' END);
END $$;

-- ───────────────────────────────────────────────────────────────
-- 8. SEGURIDAD A NIVEL DE FILA (RLS)
--    Obligatorio en Supabase: sin esto, la clave anon deja leer todo.
-- ───────────────────────────────────────────────────────────────

ALTER TABLE public.perfil         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departamento   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cliente        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proveedor      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.colaborador    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tarifa         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.embarque       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.turno          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.turno_embarque ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presupuesto    ENABLE ROW LEVEL SECURITY;

-- Perfil: cada quien ve el suyo; gerencia y admin ven todos.
DROP POLICY IF EXISTS perfil_lectura ON public.perfil;
CREATE POLICY perfil_lectura ON public.perfil FOR SELECT TO authenticated
  USING (id = auth.uid() OR public.puede_administrar());
DROP POLICY IF EXISTS perfil_propio ON public.perfil;
CREATE POLICY perfil_propio ON public.perfil FOR UPDATE TO authenticated
  USING (id = auth.uid()) WITH CHECK (id = auth.uid() AND rol = public.rol_actual());
DROP POLICY IF EXISTS perfil_admin ON public.perfil;
CREATE POLICY perfil_admin ON public.perfil FOR ALL TO authenticated
  USING (public.puede_administrar()) WITH CHECK (public.puede_administrar());

-- Catálogos: los lee cualquier usuario autenticado; los edita gerencia o admin.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['departamento','cliente','proveedor','colaborador','tarifa'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I_lectura ON public.%I', t, t);
    EXECUTE format('CREATE POLICY %I_lectura ON public.%I FOR SELECT TO authenticated USING (public.es_del_cedis())', t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I_escritura ON public.%I', t, t);
    EXECUTE format('CREATE POLICY %I_escritura ON public.%I FOR ALL TO authenticated
                    USING (public.puede_administrar()) WITH CHECK (public.puede_administrar())', t, t);
  END LOOP;
END $$;

-- El colaborador lo puede dar de alta el supervisor desde el formulario.
DROP POLICY IF EXISTS colaborador_alta ON public.colaborador;
CREATE POLICY colaborador_alta ON public.colaborador FOR INSERT TO authenticated
  WITH CHECK (public.puede_escribir());

-- Turnos: los ve todo el CEDIS; los registra quien puede escribir.
DROP POLICY IF EXISTS turno_lectura ON public.turno;
CREATE POLICY turno_lectura ON public.turno FOR SELECT TO authenticated USING (public.es_del_cedis());

DROP POLICY IF EXISTS turno_alta ON public.turno;
CREATE POLICY turno_alta ON public.turno FOR INSERT TO authenticated
  WITH CHECK (public.puede_escribir());

-- Corrección solo dentro del ciclo en curso o el recién cerrado: pasado ese punto,
-- el dato ya se auditó y solo gerencia lo toca.
DROP POLICY IF EXISTS turno_edicion ON public.turno;
CREATE POLICY turno_edicion ON public.turno FOR UPDATE TO authenticated
  USING (public.puede_administrar()
         OR (public.puede_escribir() AND fecha >= public.inicio_ciclo(CURRENT_DATE) - 7))
  WITH CHECK (public.puede_administrar()
         OR (public.puede_escribir() AND fecha >= public.inicio_ciclo(CURRENT_DATE) - 7));

DROP POLICY IF EXISTS turno_baja ON public.turno;
CREATE POLICY turno_baja ON public.turno FOR DELETE TO authenticated
  USING (public.puede_administrar()
         OR (registrado_por = auth.uid() AND fecha >= public.inicio_ciclo(CURRENT_DATE) - 7));

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['embarque','turno_embarque'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I_lectura ON public.%I', t, t);
    EXECUTE format('CREATE POLICY %I_lectura ON public.%I FOR SELECT TO authenticated USING (public.es_del_cedis())', t, t);
    EXECUTE format('DROP POLICY IF EXISTS %I_escritura ON public.%I', t, t);
    EXECUTE format('CREATE POLICY %I_escritura ON public.%I FOR ALL TO authenticated
                    USING (public.puede_escribir()) WITH CHECK (public.puede_escribir())', t, t);
  END LOOP;
END $$;

-- Presupuesto: lo ve cualquiera; solo gerencia lo carga.
DROP POLICY IF EXISTS presupuesto_lectura ON public.presupuesto;
CREATE POLICY presupuesto_lectura ON public.presupuesto FOR SELECT TO authenticated USING (public.es_del_cedis());
DROP POLICY IF EXISTS presupuesto_escritura ON public.presupuesto;
CREATE POLICY presupuesto_escritura ON public.presupuesto FOR ALL TO authenticated
  USING (public.puede_administrar()) WITH CHECK (public.puede_administrar());

-- Permisos base (las políticas siguen mandando por encima de esto).
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;

-- ───────────────────────────────────────────────────────────────
-- 9. CATÁLOGOS INICIALES
--     No son datos operativos. Comentá este bloque si querés
--     la base literalmente vacía y cargarlos desde la aplicación.
-- ───────────────────────────────────────────────────────────────

INSERT INTO public.departamento (nombre, orden) VALUES
  ('Recepción', 10), ('Valor agregado', 20), ('Crossdock', 30), ('Pesado', 40),
  ('Alisto', 50), ('Despacho', 60), ('Zona Franca', 70), ('El Coco', 80)
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO public.cliente (nombre) VALUES
  ('EPA'), ('Cofersa'), ('Zona Franca'), ('OLO')
ON CONFLICT (nombre) DO NOTHING;

-- Tarifa vigente: ₡2.750 por hora por colaborador.
INSERT INTO public.tarifa (proveedor_id, monto_crc, vigente_desde)
SELECT NULL, 2750.00, date_trunc('year', CURRENT_DATE)::date
WHERE NOT EXISTS (SELECT 1 FROM public.tarifa WHERE proveedor_id IS NULL AND vigente_hasta IS NULL);

-- ───────────────────────────────────────────────────────────────
-- 10. DESPUÉS DE CORRER ESTO
-- ───────────────────────────────────────────────────────────────
--
-- a) Creá tu usuario en Authentication → Users. El trigger le arma el perfil
--    con rol 'supervisor'. Para ascenderlo:
--       UPDATE public.perfil SET rol = 'admin' WHERE correo = 'vos@olo.cr';
--
-- b) Desde la app (supabase-js):
--       await supabase.rpc('registrar_turno', {
--         p_fecha: '2026-09-01', p_departamento_id: 1, p_colaborador_id: 5,
--         p_cliente_id: 1, p_hora_entrada: '07:00', p_hora_salida: '16:30',
--         p_descanso_min: 30,
--         p_embarques: [{ codigo: 'MSCU1234567', horas: 5.5 },
--                       { codigo: 'TGHU9087654', horas: 3.5 }] });
--
--       await supabase.rpc('resumen_ciclo', { p_offset: -1 });      // auditoría del viernes
--       await supabase.rpc('serie_semanal', { p_n: 8 });            // insumo de la proyección
--       await supabase.rpc('ejecucion_presupuesto', { p_anio: 2026, p_mes: 9 });
--
-- c) La proyección estadística corre en el cliente, no acá: es un cálculo puro
--    sobre la serie que devuelve serie_semanal().
