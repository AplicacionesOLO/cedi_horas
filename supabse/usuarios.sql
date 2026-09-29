-- ═══════════════════════════════════════════════════════════════════════
-- OLO · Módulo de usuarios (CRUD desde la app)
--
-- Depende de supabse/roles.sql (tablas usuarios, roles, usuarios_roles y
-- las funciones es_admin / mi_rol). Correr DESPUÉS de roles.sql.
--
-- Qué agrega:
--   • RPC listar_usuarios()  → lista con rol para la vista de administración.
--   • RPC asignar_rol(...)    → fija UN rol al usuario (reemplaza los previos).
--   • Índices y grants.
--
-- Idempotente: se puede volver a correr sin romper nada.
--
-- ⚠️ CREAR y ELIMINAR cuentas de acceso (correo/contraseña) se hace en
--    Authentication → Users (necesita la service_role key, que NO va en el
--    navegador). Desde la app se administran: nombre, estado (activo) y rol.
--    Para "dar de baja" a alguien sin borrar su cuenta, poné activo = false:
--    deja de tener acceso porque las políticas exigen es_del_sistema().
-- ═══════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────
-- 1. LISTAR USUARIOS (para la vista de administración)
--    Devuelve una fila por usuario con su rol de mayor privilegio.
--    Solo el admin obtiene la lista completa; otros roles reciben vacío.
-- ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.listar_usuarios()
RETURNS TABLE (
  id        uuid,
  correo    text,
  nombre    text,
  activo    boolean,
  rol       text,
  creado_en timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT
    u.id,
    u.correo,
    u.nombre,
    u.activo,
    COALESCE(
      (SELECT r.clave
         FROM public.usuarios_roles ur
         JOIN public.roles r ON r.id = ur.rol_id
        WHERE ur.usuario_id = u.id
        ORDER BY CASE r.clave WHEN 'admin' THEN 0 WHEN 'operario' THEN 1 ELSE 2 END
        LIMIT 1),
      'ninguno') AS rol,
    u.creado_en
  FROM public.usuarios u
  WHERE public.es_admin()          -- solo el admin ve la lista completa
  ORDER BY u.nombre, u.correo;
$$;

-- ───────────────────────────────────────────────────────────────
-- 2. ASIGNAR ROL (fija un rol único, reemplaza los que tuviera)
--    Uso desde la app: SELECT public.asignar_rol('<uuid>', 'admin');
--    Protección: solo el admin puede cambiar roles.
-- ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.asignar_rol(p_usuario uuid, p_rol text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_rol_id smallint;
BEGIN
  IF NOT public.es_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede cambiar roles.';
  END IF;

  SELECT id INTO v_rol_id FROM public.roles WHERE clave = p_rol;
  IF v_rol_id IS NULL THEN
    RAISE EXCEPTION 'Rol inexistente: %', p_rol;
  END IF;

  -- Un solo rol por usuario: se limpian los previos y se deja el elegido.
  DELETE FROM public.usuarios_roles WHERE usuario_id = p_usuario;
  INSERT INTO public.usuarios_roles (usuario_id, rol_id)
  VALUES (p_usuario, v_rol_id)
  ON CONFLICT DO NOTHING;
END $$;

-- ───────────────────────────────────────────────────────────────
-- 3. ÍNDICES ÚTILES
-- ───────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS ix_usuarios_roles_usuario ON public.usuarios_roles (usuario_id);
CREATE INDEX IF NOT EXISTS ix_usuarios_activo         ON public.usuarios (activo);

-- ───────────────────────────────────────────────────────────────
-- 4. GRANTS
-- ───────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.listar_usuarios()          TO authenticated;
GRANT EXECUTE ON FUNCTION public.asignar_rol(uuid, text)    TO authenticated;

-- ───────────────────────────────────────────────────────────────
-- 5. RECORDATORIOS
-- ───────────────────────────────────────────────────────────────
-- • Crear cuenta:  Authentication → Users → Add user (correo + contraseña).
--   El trigger de roles.sql le crea el perfil y lo deja como 'operario'.
-- • Cambiar nombre / activar-desactivar: desde la app (módulo Usuarios) o:
--     UPDATE public.usuarios SET nombre = 'Nombre Apellido' WHERE correo = 'x@olo.cr';
--     UPDATE public.usuarios SET activo = false            WHERE correo = 'x@olo.cr';
-- • Cambiar rol desde SQL:
--     SELECT public.asignar_rol(
--       (SELECT id FROM public.usuarios WHERE correo = 'x@olo.cr'), 'admin');
-- • Eliminar por completo una cuenta: Authentication → Users → Delete user
--   (el ON DELETE CASCADE limpia public.usuarios y usuarios_roles).
