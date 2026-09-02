-- ═══════════════════════════════════════════════════════════════════════
-- OLO · Login y roles
--
-- Usa la autenticación nativa de Supabase (auth.users). Vos creás los
-- correos y contraseñas en Authentication → Users; acá se definen los roles
-- y la relación usuario↔rol.
--
-- Roles:
--   admin    → ve todo el sistema (incluye "borrar todos los registros").
--   operario → ve todo MENOS el borrado masivo, y en Ajustes solo puede
--              agregar colaboradores externos.
--
-- CÓMO CORRERLO
--   Supabase Studio → SQL Editor → New query → pegar todo → Run
--   Idempotente: se puede volver a correr sin romper nada.
-- ═══════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────
-- 1. TABLAS
-- ───────────────────────────────────────────────────────────────

-- Catálogo de roles.
CREATE TABLE IF NOT EXISTS public.roles (
  id          smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave       text NOT NULL UNIQUE,          -- 'admin' | 'operario'
  descripcion text NOT NULL DEFAULT ''
);

INSERT INTO public.roles (clave, descripcion) VALUES
  ('admin',    'Acceso total al sistema, incluye borrado masivo de registros.'),
  ('operario', 'Ve todo menos el borrado masivo; en Ajustes solo agrega colaboradores externos.')
ON CONFLICT (clave) DO NOTHING;

-- Espejo local de los usuarios de Supabase Auth (auth.users).
-- Los correos/contraseñas los seguís creando en Authentication → Users.
CREATE TABLE IF NOT EXISTS public.usuarios (
  id         uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  correo     text,
  nombre     text NOT NULL DEFAULT '',
  activo     boolean NOT NULL DEFAULT true,
  creado_en  timestamptz NOT NULL DEFAULT now()
);

-- Relación usuario ↔ rol (permite varios roles por usuario si hiciera falta).
CREATE TABLE IF NOT EXISTS public.usuarios_roles (
  usuario_id uuid     NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  rol_id     smallint NOT NULL REFERENCES public.roles(id)    ON DELETE CASCADE,
  asignado_en timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (usuario_id, rol_id)
);

-- ───────────────────────────────────────────────────────────────
-- 2. ALTA AUTOMÁTICA DE USUARIO
--    Cuando creás un usuario en Authentication → Users, el trigger le arma
--    la fila en public.usuarios y le asigna el rol 'operario' por defecto.
--    (Al admin lo ascendés vos con el UPDATE del final.)
-- ───────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_nuevo_usuario_roles()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_rol_operario smallint;
BEGIN
  INSERT INTO public.usuarios (id, correo, nombre)
  VALUES (NEW.id, NEW.email,
          COALESCE(NEW.raw_user_meta_data->>'nombre', split_part(NEW.email, '@', 1)))
  ON CONFLICT (id) DO UPDATE SET correo = EXCLUDED.correo;

  SELECT id INTO v_rol_operario FROM public.roles WHERE clave = 'operario';
  IF v_rol_operario IS NOT NULL THEN
    INSERT INTO public.usuarios_roles (usuario_id, rol_id)
    VALUES (NEW.id, v_rol_operario)
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS tg_nuevo_usuario_roles ON auth.users;
CREATE TRIGGER tg_nuevo_usuario_roles
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.fn_nuevo_usuario_roles();

-- Backfill: registra usuarios que ya existían antes de correr esto.
INSERT INTO public.usuarios (id, correo, nombre)
SELECT u.id, u.email, COALESCE(u.raw_user_meta_data->>'nombre', split_part(u.email, '@', 1))
FROM auth.users u
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.usuarios_roles (usuario_id, rol_id)
SELECT u.id, r.id
FROM auth.users u
CROSS JOIN public.roles r
WHERE r.clave = 'operario'
ON CONFLICT DO NOTHING;

-- ───────────────────────────────────────────────────────────────
-- 3. HELPERS DE ROL (usados por RLS y por la app)
-- ───────────────────────────────────────────────────────────────

-- Rol de mayor privilegio del usuario actual. 'admin' gana sobre 'operario'.
CREATE OR REPLACE FUNCTION public.mi_rol()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT COALESCE(
    (SELECT r.clave
       FROM public.usuarios_roles ur
       JOIN public.roles r ON r.id = ur.rol_id
      WHERE ur.usuario_id = auth.uid()
      ORDER BY CASE r.clave WHEN 'admin' THEN 0 WHEN 'operario' THEN 1 ELSE 2 END
      LIMIT 1),
    'ninguno');
$$;

CREATE OR REPLACE FUNCTION public.es_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$ SELECT public.mi_rol() = 'admin'; $$;

-- ¿El usuario actual pertenece al sistema? (tiene algún rol y está activo)
CREATE OR REPLACE FUNCTION public.es_del_sistema()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios u
    JOIN public.usuarios_roles ur ON ur.usuario_id = u.id
    WHERE u.id = auth.uid() AND u.activo
  );
$$;

-- Función cómoda para que la app lea su propio perfil tras iniciar sesión.
CREATE OR REPLACE FUNCTION public.mi_perfil()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'id',     u.id,
    'correo', u.correo,
    'nombre', u.nombre,
    'activo', u.activo,
    'rol',    public.mi_rol(),
    'es_admin', public.es_admin()
  )
  FROM public.usuarios u
  WHERE u.id = auth.uid();
$$;

-- ───────────────────────────────────────────────────────────────
-- 4. RLS
-- ───────────────────────────────────────────────────────────────

ALTER TABLE public.roles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios_roles ENABLE ROW LEVEL SECURITY;

-- Roles: cualquier usuario autenticado del sistema los puede leer.
DROP POLICY IF EXISTS roles_lectura ON public.roles;
CREATE POLICY roles_lectura ON public.roles
  FOR SELECT TO authenticated USING (public.es_del_sistema());

-- Usuarios: cada quien ve su fila; el admin ve y administra todas.
DROP POLICY IF EXISTS usuarios_propio ON public.usuarios;
CREATE POLICY usuarios_propio ON public.usuarios
  FOR SELECT TO authenticated USING (id = auth.uid() OR public.es_admin());

DROP POLICY IF EXISTS usuarios_admin ON public.usuarios;
CREATE POLICY usuarios_admin ON public.usuarios
  FOR ALL TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());

-- Usuarios_roles: cada quien ve los suyos; solo el admin los cambia.
DROP POLICY IF EXISTS usuarios_roles_propio ON public.usuarios_roles;
CREATE POLICY usuarios_roles_propio ON public.usuarios_roles
  FOR SELECT TO authenticated USING (usuario_id = auth.uid() OR public.es_admin());

DROP POLICY IF EXISTS usuarios_roles_admin ON public.usuarios_roles;
CREATE POLICY usuarios_roles_admin ON public.usuarios_roles
  FOR ALL TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON public.roles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.usuarios, public.usuarios_roles TO authenticated;
GRANT EXECUTE ON FUNCTION public.mi_rol, public.es_admin, public.es_del_sistema, public.mi_perfil TO authenticated;

-- ───────────────────────────────────────────────────────────────
-- 5. PROTEGER app_estado CON LOGIN
--    Ahora que hay autenticación, cerramos la tabla de estado a usuarios
--    del sistema (antes estaba abierta a anon). Corré esto DESPUÉS de
--    haber corrido app_estado.sql.
-- ───────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS app_estado_lectura ON public.app_estado;
DROP POLICY IF EXISTS app_estado_insert  ON public.app_estado;
DROP POLICY IF EXISTS app_estado_update  ON public.app_estado;

CREATE POLICY app_estado_lectura ON public.app_estado
  FOR SELECT TO authenticated USING (public.es_del_sistema());
CREATE POLICY app_estado_insert ON public.app_estado
  FOR INSERT TO authenticated WITH CHECK (public.es_del_sistema());
CREATE POLICY app_estado_update ON public.app_estado
  FOR UPDATE TO authenticated USING (public.es_del_sistema()) WITH CHECK (public.es_del_sistema());

-- Solo el admin puede borrar la fila de estado (borrado masivo).
DROP POLICY IF EXISTS app_estado_delete ON public.app_estado;
CREATE POLICY app_estado_delete ON public.app_estado
  FOR DELETE TO authenticated USING (public.es_admin());

-- Quitamos el acceso anónimo que dejaba app_estado.sql.
REVOKE ALL ON public.app_estado FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_estado TO authenticated;

-- ───────────────────────────────────────────────────────────────
-- 6. DESPUÉS DE CORRER ESTO
-- ───────────────────────────────────────────────────────────────
--
-- a) Creá los usuarios en Authentication → Users (correo + contraseña).
--    Cada uno queda como 'operario' automáticamente.
--
-- b) Para volver admin a alguien (cambiá el correo):
--
--    WITH u AS (SELECT id FROM public.usuarios WHERE correo = 'admin@olo.cr'),
--         r AS (SELECT id FROM public.roles WHERE clave = 'admin')
--    INSERT INTO public.usuarios_roles (usuario_id, rol_id)
--    SELECT u.id, r.id FROM u, r
--    ON CONFLICT (usuario_id, rol_id) DO NOTHING;
--
--    -- y si querés quitarle el rol operario para dejarlo solo admin:
--    DELETE FROM public.usuarios_roles ur
--    USING public.usuarios u, public.roles r
--    WHERE ur.usuario_id = u.id AND ur.rol_id = r.id
--      AND u.correo = 'admin@olo.cr' AND r.clave = 'operario';
--
-- c) Ver quién tiene qué rol:
--    SELECT u.correo, r.clave FROM public.usuarios_roles ur
--    JOIN public.usuarios u ON u.id = ur.usuario_id
--    JOIN public.roles r    ON r.id = ur.rol_id
--    ORDER BY u.correo;
