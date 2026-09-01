-- ═══════════════════════════════════════════════════════════════════════
-- OLO · Almacenamiento del estado de la aplicación (frontend actual)
--
-- El frontend (out/cedis-horas.jsx) maneja TODO su estado como un único
-- documento JSON (turnos, colaboradores, clientes, presupuestos, tarifa…).
-- Esta tabla lo persiste en Supabase para que los datos vivan en la nube
-- y se compartan entre dispositivos, sin reescribir la app.
--
-- CÓMO CORRERLO
--   Supabase Studio → SQL Editor → New query → pegar todo → Run
--
-- Es idempotente: se puede volver a correr sin romper nada.
--
-- NOTA sobre seguridad:
--   Este esquema usa una fila única compartida por todo el CEDIS, legible y
--   escribible con la clave anon (sin login). Es lo que hace funcionar la app
--   tal cual está hoy. Si más adelante activás login de Supabase, migrá al
--   modelo normalizado de supabase_migracion.sql (tablas + RPC + RLS por rol).
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.app_estado (
  clave        text PRIMARY KEY,          -- p.ej. 'cedis:datos:v2'
  datos        jsonb NOT NULL DEFAULT '{}'::jsonb,
  actualizado  timestamptz NOT NULL DEFAULT now()
);

-- Sella la fecha de actualización en cada escritura.
CREATE OR REPLACE FUNCTION public.fn_app_estado_touch()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.actualizado := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS tg_app_estado_touch ON public.app_estado;
CREATE TRIGGER tg_app_estado_touch
  BEFORE INSERT OR UPDATE ON public.app_estado
  FOR EACH ROW EXECUTE FUNCTION public.fn_app_estado_touch();

-- ───────────────────────────────────────────────────────────────
-- RLS: la app funciona sin login, con la clave anon.
-- Permitimos leer/escribir a anon y authenticated SOLO en esta tabla.
-- ───────────────────────────────────────────────────────────────
ALTER TABLE public.app_estado ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_estado_lectura ON public.app_estado;
CREATE POLICY app_estado_lectura ON public.app_estado
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS app_estado_insert ON public.app_estado;
CREATE POLICY app_estado_insert ON public.app_estado
  FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS app_estado_update ON public.app_estado;
CREATE POLICY app_estado_update ON public.app_estado
  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.app_estado TO anon, authenticated;
