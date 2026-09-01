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
| `supabse/app_estado.sql` | ✅ **Corré este** para conectar el frontend actual. Crea la tabla que guarda el estado JSON. |
| `supabse/supabase_migracion.sql` | Modelo normalizado completo (tablas + RPC + RLS por rol + login). Para la versión "en serio" con autenticación. Opcional por ahora. |
| `supabse/esquema.sql` | ⚠️ Versión para Postgres propio + Express. **NO lo corras en Supabase.** |
| `out/supabase-config.js` | Tu URL y anon key. |
| `out/supabase-bridge.js` | Inicializa el cliente y conecta `window.storage` a la tabla `app_estado`. |

### Dos niveles de integración

- **Nivel 1 — Ahora (lo que dejé listo):** el frontend guarda/lee su estado en `app_estado`. Simple, funciona sin login. Corré **`supabse/app_estado.sql`**.
- **Nivel 2 — Después (opcional):** migrar al modelo normalizado con login por usuario, roles y RPC. Corré `supabse/supabase_migracion.sql` y reescribí la app para usar las RPC. Ver la última sección.

---

## PASO 1 · Correr el SQL en Supabase

1. Entrá a tu proyecto: https://supabase.com/dashboard/project/habdqtkjwprqxpofqloc
2. Menú izquierdo → **SQL Editor** → **New query**.
3. Abrí el archivo **`supabse/app_estado.sql`** de este repo, copiá **todo** el contenido y pegalo en el editor.
4. Click en **Run** (o `Ctrl+Enter`).

Debería terminar sin errores. Es idempotente: si lo corrés de nuevo no rompe nada.

> ❌ No corras `supabse/esquema.sql` (es para un Postgres propio con Express).
> El `supabse/supabase_migracion.sql` es opcional por ahora (modelo con login; ver la última sección).

### Qué crea `app_estado.sql`
- Tabla `app_estado(clave, datos jsonb, actualizado)` donde vive el estado de la app.
- Políticas RLS que permiten a la clave anon leer/escribir esa tabla (la app funciona sin login).

---

## PASO 2 · Abrir la app

Abrí `out/index.html` en el navegador (o servilo con cualquier hosting estático: Vercel, Netlify, Nginx…).

Al cargar, el `supabase-bridge.js` conecta el almacenamiento de la app a la tabla `app_estado`. Abrí la consola del navegador (F12): deberías ver

```
[supabase-bridge] Cliente Supabase listo. window.storage conectado a app_estado.
```

Registrá un turno desde la pestaña **Registrar**. Se guardará en Supabase.

---

## PASO 3 · Verificar que quedó guardado en Supabase

En el **SQL Editor**:

```sql
SELECT clave, actualizado, jsonb_array_length(datos->'turnos') AS turnos
FROM public.app_estado;
```

Deberías ver la fila `cedis:datos:v2` con el número de turnos que registraste. Si abrís la app en otro navegador o dispositivo, verás los mismos datos.

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
