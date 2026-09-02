-- ═══════════════════════════════════════════════════════════════════════
-- OLO · Diagnóstico "no veo la data"
-- Corré estas consultas en el SQL Editor de Supabase para encontrar la causa.
-- ═══════════════════════════════════════════════════════════════════════

-- 1) ¿Existe la tabla de estado y tiene datos?
SELECT clave, actualizado,
       jsonb_array_length(COALESCE(datos->'turnos','[]'::jsonb))        AS turnos,
       jsonb_array_length(COALESCE(datos->'colaboradores','[]'::jsonb)) AS colaboradores
FROM public.app_estado;
-- Si no devuelve filas: nunca se guardó (probablemente el guardado lo bloqueó el RLS).

-- 2) ¿Qué usuarios y roles hay?
SELECT u.correo, u.activo, r.clave AS rol
FROM public.usuarios u
LEFT JOIN public.usuarios_roles ur ON ur.usuario_id = u.id
LEFT JOIN public.roles r           ON r.id = ur.rol_id
ORDER BY u.correo;
-- Si tu correo aparece con rol NULL: no tenés rol → el RLS te bloquea todo.
-- Si tu correo NO aparece: el trigger no creó tu usuario (te registraste antes de roles.sql).

-- 3) ¿Hay usuarios en Auth que no quedaron en public.usuarios?
SELECT au.email
FROM auth.users au
LEFT JOIN public.usuarios pu ON pu.id = au.id
WHERE pu.id IS NULL;

-- ───────────────────────────────────────────────────────────────
-- ARREGLOS
-- ───────────────────────────────────────────────────────────────

-- A) Traer a public.usuarios cualquier cuenta de Auth que falte,
--    y darle rol 'operario' por defecto.
INSERT INTO public.usuarios (id, correo, nombre)
SELECT au.id, au.email, COALESCE(au.raw_user_meta_data->>'nombre', split_part(au.email,'@',1))
FROM auth.users au
ON CONFLICT (id) DO UPDATE SET correo = EXCLUDED.correo;

INSERT INTO public.usuarios_roles (usuario_id, rol_id)
SELECT u.id, r.id
FROM public.usuarios u
CROSS JOIN public.roles r
WHERE r.clave = 'operario'
ON CONFLICT DO NOTHING;

-- B) Volver admin a tu usuario (cambiá el correo):
WITH u AS (SELECT id FROM public.usuarios WHERE correo = 'TU-CORREO@ejemplo.com'),
     r AS (SELECT id FROM public.roles WHERE clave = 'admin')
INSERT INTO public.usuarios_roles (usuario_id, rol_id)
SELECT u.id, r.id FROM u, r
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- C) Verificar de nuevo el punto 2. Cuando tu correo tenga rol,
--    recargá la app: ya deberías ver y guardar datos.
