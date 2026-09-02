# Conectar el sistema OLO/CEDIS a Supabase

Guía paso a paso para dejar el sistema corriendo contra tu base de datos de Supabase.

- **Proyecto Supabase:** `https://habdqtkjwprqxpofqloc.supabase.co`
- **SQL a correr para arrancar:** `supabse/app_estado.sql`

---

## Cómo quedó conectado

El frontend (`out/cedis-horas.jsx` y su versión compilada `out/index.html`) maneja **todo su estado como un único documento JSON** (turnos, colaboradores, clientes, presupuestos, tarifa). Para conectarlo a Supabase sin reescribir la app, se guarda ese documento en una tabla `app_estado` de tu base de datos.

Así, los datos ya no viven solo en el navegador: viven en Supabase y se comparten entre dispositivos. Si no hay conexión, la app sigue funcionando contra `localStorage` y sincroniza cuando vuelve.

### Piezas del repo

| Pieza | Para qué |
|---|---|
| `supabse/app_estado.sql` | ✅ **Corré 1º.** Crea la tabla que guarda el estado JSON del frontend. |
| `supabse/roles.sql` | ✅ **Corré 2º.** Login + roles (`usuarios`, `roles`, `usuarios_roles`) y cierra `app_estado` para que exija sesión. |
| `supabse/supabase_migracion.sql` | Modelo normalizado avanzado (tablas + RPC). Opcional, no hace falta para que corra. |
| `supabse/esquema.sql` | ⚠️ Versión para Postgres propio + Express. **NO lo corras en Supabase.** |
| `out/supabase-config.js` | Tu URL y anon key. |
| `out/supabase-bridge.js` | Cliente Supabase + login (`window.oloAuth`) + `window.storage` sobre `app_estado`. |
| `out/cedis-horas.jsx` | Código fuente de la app (login, roles, registro, tablero…). |
| `out/index.html` | Carga el `.jsx`, lo transpila en el navegador con Babel y monta la app. |

### Roles

| Rol | Qué ve |
|---|---|
| **admin** | Todo el sistema, incluido el botón de **borrar todos los registros** y todos los ajustes. |
| **operario** | Todo **menos** el borrado masivo. En **Ajustes** solo ve **agregar colaboradores externos**. |

Los correos y contraseñas los creás vos en Supabase (Authentication → Users). Cada usuario nuevo queda como **operario**; al admin lo asignás con un SQL (ver PASO 3).

---

## PASO 1 · Correr los SQL en Supabase (en orden)

1. Entrá a tu proyecto: https://supabase.com/dashboard/project/habdqtkjwprqxpofqloc
2. Menú izquierdo → **SQL Editor** → **New query**.
3. Pegá y **Run** el contenido de **`supabse/app_estado.sql`**.
4. Nueva query. Pegá y **Run** el contenido de **`supabse/roles.sql`**.

Ambos son idempotentes: se pueden volver a correr sin romper nada.

> ❌ No corras `supabse/esquema.sql` (es para un Postgres propio con Express).

Después de esto la base exige sesión: sin login no se lee ni escribe nada.

---

## PASO 2 · Crear los usuarios (correo y contraseña)

Vos creás las cuentas:

1. Dashboard → **Authentication** → **Users** → **Add user** → **Create new user**.
2. Poné correo y contraseña. Repetí por cada persona.
3. Cada usuario nuevo queda automáticamente con rol **operario**.

> Consejo: en Authentication → Providers → Email, dejá **Confirm email** en OFF si querés que entren sin confirmar el correo, o creá los usuarios con "Auto Confirm User".

---

## PASO 3 · Asignar el rol admin

En **SQL Editor**, cambiá el correo por el de quien será admin:

```sql
WITH u AS (SELECT id FROM public.usuarios WHERE correo = 'admin@olo.cr'),
     r AS (SELECT id FROM public.roles WHERE clave = 'admin')
INSERT INTO public.usuarios_roles (usuario_id, rol_id)
SELECT u.id, r.id FROM u, r
ON CONFLICT (usuario_id, rol_id) DO NOTHING;
```

Para ver quién tiene qué rol:

```sql
SELECT u.correo, r.clave
FROM public.usuarios_roles ur
JOIN public.usuarios u ON u.id = ur.usuario_id
JOIN public.roles r    ON r.id = ur.rol_id
ORDER BY u.correo;
```

---

## PASO 4 · Abrir la app

La app transpila el JSX en el navegador, así que **hay que servirla con un servidor web** (no abrir el `.html` con doble clic / `file://`).

Desde la carpeta del proyecto:

```bash
npx serve out
# o:  npx http-server out -p 3000
```

Abrí la URL que muestre (p.ej. http://localhost:3000). Vas a ver la **pantalla de login**. Entrá con uno de los correos del PASO 2.

- Si entrás como **admin**: ves todo, incluido "borrar todos los registros" y todos los ajustes.
- Si entrás como **operario**: no ves el borrado masivo, y en **Ajustes** solo ves "Colaboradores externos".

La etiqueta del rol y el botón **Salir** aparecen arriba a la derecha.

---

## PASO 5 · Verificar que quedó guardado en Supabase

En el **SQL Editor**:

```sql
SELECT clave, actualizado, jsonb_array_length(datos->'turnos') AS turnos
FROM public.app_estado;
```

Deberías ver la fila `cedis:datos:v2` con los turnos registrados. Si abrís la app en otro dispositivo con otra cuenta del CEDIS, ves los mismos datos.

---

## Sobre las llaves

- **anon key** → es pública, va en el navegador. Está en `out/supabase-config.js`. Es segura de exponer porque el RLS protege los datos.
- **service_role key** → **NUNCA** la pongas en el frontend ni la subas al repo. Salta todo el RLS. Guardala solo en variables de entorno de servidor si algún día montás un backend.

⚠️ Recomendación de seguridad: como compartiste ambas llaves en texto, considerá **rotarlas** desde Dashboard → **Project Settings → API** cuando termines de configurar. La anon podés dejarla; la service_role conviene rotarla sí o sí.

---

## Nivel 2 (opcional) · Modelo normalizado con login

Lo de arriba deja la app corriendo contra Supabase ya. Cuando quieras "hacerlo en serio" con usuarios, roles y auditoría por fila, está el segundo modelo:

1. Corré `supabse/supabase_migracion.sql` (crea `turno`, `colaborador`, `presupuesto`, etc., con RLS por rol y funciones RPC).
2. Creá tu usuario en **Authentication → Users**; el trigger le arma el perfil como `supervisor`.
3. Ascendelo a admin:
   ```sql
   UPDATE public.perfil SET rol = 'admin' WHERE correo = 'TU-CORREO@ejemplo.com';
   ```
4. Reescribí el frontend para usar login (`supabase.auth.signInWithPassword`) y las RPC ya expuestas en `window.oloApi` (`registrarTurno`, `resumenCiclo`, `serieSemanal`, `ejecucionPresupuesto`).

Diferencia clave: el frontend actual usa **nombres** (departamento/cliente/colaborador como texto); el modelo normalizado usa **IDs**. Migrar implica mapear nombres↔IDs y manejar sesión. Por eso el Nivel 1 (tabla `app_estado`) es el arranque recomendado.

Las RPC del Nivel 2 se pueden probar directo en el SQL Editor:

```sql
SELECT public.resumen_ciclo(-1);
SELECT * FROM public.serie_semanal(8);
SELECT public.ejecucion_presupuesto(2026, 9);
```
