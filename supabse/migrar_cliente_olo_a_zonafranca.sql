-- ═══════════════════════════════════════════════════════════════════════
-- OLO · Migración puntual: reasignar el cliente "OLO" → "Zona Franca"
--
-- Mueve TODOS los turnos cuyo cliente sea "OLO" al cliente "Zona Franca",
-- quita "OLO" del catálogo de clientes y deja una entrada en la bitácora.
--
-- El estado de la app vive como un único documento JSON en public.app_estado
-- (clave 'cedis:datos:v2'). Este script edita ese JSON in-place.
--
-- CÓMO CORRERLO
--   Supabase Studio → SQL Editor → New query → pegar todo → Run
--
-- SEGURIDAD
--   • Hacé un respaldo antes (ver PASO 0).
--   • Es idempotente: volver a correrlo no hace nada si ya no quedan "OLO".
--   • Cambiá ORIGEN/DESTINO abajo si necesitás otra reasignación.
-- ═══════════════════════════════════════════════════════════════════════

-- Parámetros de la migración (cambialos si hace falta).
--   ORIGEN  = cliente que se elimina/absorbe
--   DESTINO = cliente al que pasan los registros
-- (se usan como literales en el script; editá las dos apariciones de cada uno)

-- ───────────────────────────────────────────────────────────────
-- PASO 0 · RESPALDO (recomendado). Guarda una copia con otra clave.
-- ───────────────────────────────────────────────────────────────
INSERT INTO public.app_estado (clave, datos)
SELECT 'cedis:datos:v2:backup:' || to_char(now(), 'YYYYMMDD_HH24MISS'), datos
FROM public.app_estado
WHERE clave = 'cedis:datos:v2';

-- ───────────────────────────────────────────────────────────────
-- PASO 1 · ¿Cuántos turnos tiene "OLO" hoy? (diagnóstico previo)
-- ───────────────────────────────────────────────────────────────
SELECT count(*) AS turnos_olo
FROM public.app_estado ae,
     jsonb_array_elements(ae.datos->'turnos') AS t
WHERE ae.clave = 'cedis:datos:v2'
  AND t->>'cliente' = 'OLO';

-- ───────────────────────────────────────────────────────────────
-- PASO 2 · MIGRACIÓN
--   a) turnos: cliente 'OLO' → 'Zona Franca'
--   b) clientes: quitar 'OLO' y asegurar que 'Zona Franca' esté presente
--   c) bitácora: registrar el cambio
-- ───────────────────────────────────────────────────────────────
WITH estado AS (
  SELECT datos FROM public.app_estado WHERE clave = 'cedis:datos:v2'
),
-- a) Reasignar el cliente en cada turno.
turnos_nuevos AS (
  SELECT COALESCE(jsonb_agg(
           CASE WHEN t->>'cliente' = 'OLO'
                THEN jsonb_set(t, '{cliente}', '"Zona Franca"'::jsonb)
                ELSE t END
         ), '[]'::jsonb) AS arr
  FROM estado, jsonb_array_elements(estado.datos->'turnos') AS t
),
-- b) Catálogo de clientes sin 'OLO' y con 'Zona Franca' garantizado.
clientes_sin_olo AS (
  SELECT COALESCE(jsonb_agg(c ORDER BY ord), '[]'::jsonb) AS arr
  FROM estado,
       jsonb_array_elements_text(estado.datos->'clientes') WITH ORDINALITY AS x(c, ord)
  WHERE c <> 'OLO'
),
clientes_nuevos AS (
  SELECT CASE
           WHEN (SELECT arr FROM clientes_sin_olo) @> '["Zona Franca"]'::jsonb
           THEN (SELECT arr FROM clientes_sin_olo)
           ELSE (SELECT arr FROM clientes_sin_olo) || '["Zona Franca"]'::jsonb
         END AS arr
),
-- c) Nueva entrada de bitácora (al frente del arreglo).
conteo AS (
  SELECT count(*) AS n
  FROM estado, jsonb_array_elements(estado.datos->'turnos') AS t
  WHERE t->>'cliente' = 'OLO'
),
bitacora_nueva AS (
  SELECT (
    jsonb_build_array(
      jsonb_build_object(
        'id',      'b' || floor(extract(epoch from now())*1000)::bigint::text,
        'ts',      to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'usuario', 'migración SQL',
        'rol',     'admin',
        'accion',  'Reasignó',
        'entidad', 'Cliente',
        'detalle', 'OLO → Zona Franca en ' || (SELECT n FROM conteo) || ' turno(s)'
      )
    ) || COALESCE(estado.datos->'bitacora', '[]'::jsonb)
  ) AS arr
  FROM estado
)
UPDATE public.app_estado ae
SET datos = (SELECT datos FROM estado)
          || jsonb_build_object('turnos',   (SELECT arr FROM turnos_nuevos))
          || jsonb_build_object('clientes', (SELECT arr FROM clientes_nuevos))
          || jsonb_build_object('bitacora', (SELECT arr FROM bitacora_nueva))
WHERE ae.clave = 'cedis:datos:v2';

-- ───────────────────────────────────────────────────────────────
-- PASO 3 · VERIFICACIÓN
--   turnos_olo debe dar 0; turnos_zf debe incluir los que estaban en OLO.
-- ───────────────────────────────────────────────────────────────
SELECT
  count(*) FILTER (WHERE t->>'cliente' = 'OLO')          AS turnos_olo,
  count(*) FILTER (WHERE t->>'cliente' = 'Zona Franca')  AS turnos_zona_franca
FROM public.app_estado ae,
     jsonb_array_elements(ae.datos->'turnos') AS t
WHERE ae.clave = 'cedis:datos:v2';

-- ¿Quedó 'OLO' en el catálogo? (debe dar 'false')
SELECT (datos->'clientes') @> '["OLO"]'::jsonb AS olo_en_catalogo,
       (datos->'clientes') @> '["Zona Franca"]'::jsonb AS zona_franca_en_catalogo
FROM public.app_estado WHERE clave = 'cedis:datos:v2';

-- ───────────────────────────────────────────────────────────────
-- SI ALGO SALE MAL · restaurar desde el respaldo del PASO 0
--   (reemplazá la clave por la que haya creado el PASO 0):
--
--   UPDATE public.app_estado
--   SET datos = (SELECT datos FROM public.app_estado
--                WHERE clave = 'cedis:datos:v2:backup:AAAAMMDD_HHMMSS')
--   WHERE clave = 'cedis:datos:v2';
-- ───────────────────────────────────────────────────────────────
