-- ═══════════════════════════════════════════════════════════════════════
-- OLO · Rol "rh" (Recursos Humanos): SOLO LECTURA
--
-- Un usuario con rol 'rh' puede entrar al sistema y VER reportes (Semana,
-- Embarques, Tablero) pero NO puede crear, editar ni borrar nada.
--
-- La restricción se aplica en la BASE DE DATOS (RLS), no solo en la pantalla:
-- aunque alguien manipule el navegador, Supabase rechaza cualquier escritura
-- hecha por un usuario 'rh'.
--
-- Depende de supabse/roles.sql (y opcionalmente usuarios.sql). Correr DESPUÉS.
-- Idempotente: se puede volver a correr sin romper nada.
--
-- CÓMO CORRERLO
--   Supabase Studio → SQL Editor → New query → pegar todo → Run
-- ═══════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────
-- 1. EL ROL
-- ───────────────────────────────────────────────────────────────
INSERT INTO public.roles (clave, descripcion) VALUES
  ('rh', 'Recursos Humanos: solo lectura. Ve los reportes pero no puede crear, editar ni borrar.')
ON CONFLICT (clave) DO UPDATE SET descripcion = EXCLUDED.descripcion;

-- ───────────────────────────────────────────────────────────────
-- 2. ¿QUIÉN PUEDE ESCRIBIR?
--    Solo admin y operario. 'rh' (y cualquier rol futuro de solo lectura)
--    queda fuera. Se evalúa con el rol de mayor privilegio del usuario.
-- ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.puede_editar()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT public.es_del_sistema() AND public.mi_rol() IN ('admin', 'operario');
$$;

GRANT EXECUTE ON FUNCTION public.puede_editar() TO authenticated;

-- ───────────────────────────────────────────────────────────────
-- 3. RLS de app_estado: leer = cualquier usuario del sistema (incluye rh);
--    insertar / actualizar = solo quien puede editar.
--    (El borrado ya era solo admin en roles.sql.)
-- ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS app_estado_insert ON public.app_estado;
CREATE POLICY app_estado_insert ON public.app_estado
  FOR INSERT TO authenticated WITH CHECK (public.puede_editar());

DROP POLICY IF EXISTS app_estado_update ON public.app_estado;
CREATE POLICY app_estado_update ON public.app_estado
  FOR UPDATE TO authenticated
  USING (public.puede_editar()) WITH CHECK (public.puede_editar());

-- La lectura se mantiene como en roles.sql (es_del_sistema), por si no existía:
DROP POLICY IF EXISTS app_estado_lectura ON public.app_estado;
CREATE POLICY app_estado_lectura ON public.app_estado
  FOR SELECT TO authenticated USING (public.es_del_sistema());

-- ───────────────────────────────────────────────────────────────
-- 4. ASIGNAR EL ROL A lamador@ologistics.com
--    Requisito: la cuenta ya debe existir en Authentication → Users.
--    (No se pueden crear cuentas de acceso desde SQL del esquema public;
--     si todavía no existe, créala primero: Authentication → Add user.)
--    Se hace con INSERT/DELETE directo porque en el SQL Editor no hay sesión
--    (auth.uid() es nulo) y asignar_rol() exige ser admin.
-- ───────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_usuario uuid;
  v_rol     smallint;
BEGIN
  SELECT id INTO v_usuario FROM public.usuarios WHERE lower(correo) = lower('lamador@ologistics.com');

  IF v_usuario IS NULL THEN
    -- Plan B: la cuenta existe en Auth pero el perfil no se creó todavía.
    INSERT INTO public.usuarios (id, correo, nombre)
    SELECT au.id, au.email, COALESCE(au.raw_user_meta_data->>'nombre', split_part(au.email, '@', 1))
    FROM auth.users au
    WHERE lower(au.email) = lower('lamador@ologistics.com')
    ON CONFLICT (id) DO UPDATE SET correo = EXCLUDED.correo
    RETURNING id INTO v_usuario;
  END IF;

  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'No existe la cuenta lamador@ologistics.com en Authentication → Users. Creala primero y volvé a correr este script.';
  END IF;

  SELECT id INTO v_rol FROM public.roles WHERE clave = 'rh';

  -- Un solo rol: se quitan los previos (p. ej. el 'operario' que pone el trigger).
  DELETE FROM public.usuarios_roles WHERE usuario_id = v_usuario;
  INSERT INTO public.usuarios_roles (usuario_id, rol_id) VALUES (v_usuario, v_rol);

  -- Aseguramos que la cuenta esté activa.
  UPDATE public.usuarios SET activo = true WHERE id = v_usuario;

  RAISE NOTICE 'Rol rh asignado a lamador@ologistics.com (%).', v_usuario;
END $$;

-- ───────────────────────────────────────────────────────────────
-- 5. VERIFICACIÓN
-- ───────────────────────────────────────────────────────────────
-- Debe mostrar: lamador@ologistics.com | rh | activo = true
SELECT u.correo, r.clave AS rol, u.activo
FROM public.usuarios u
JOIN public.usuarios_roles ur ON ur.usuario_id = u.id
JOIN public.roles r           ON r.id = ur.rol_id
WHERE lower(u.correo) = lower('lamador@ologistics.com');

-- Políticas de app_estado (insert/update deben usar puede_editar):
SELECT policyname, cmd FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'app_estado'
ORDER BY cmd, policyname;

-- ───────────────────────────────────────────────────────────────
-- PARA ASIGNAR 'rh' A OTRA PERSONA MÁS ADELANTE
--   Desde la app (pestaña Usuarios, como admin): Editar → Rol → rh.
--   O por SQL, cambiando el correo:
--     DELETE FROM public.usuarios_roles
--       WHERE usuario_id = (SELECT id FROM public.usuarios WHERE correo = 'otra@ologistics.com');
--     INSERT INTO public.usuarios_roles (usuario_id, rol_id)
--       SELECT u.id, r.id FROM public.usuarios u, public.roles r
--       WHERE u.correo = 'otra@ologistics.com' AND r.clave = 'rh';
-- ───────────────────────────────────────────────────────────────
