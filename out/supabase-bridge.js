/* ─────────────────────────────────────────────────────────────
   OLO · Puente hacia Supabase
   Inicializa el cliente supabase-js con la config de supabase-config.js.
   Deja el cliente en window.supabase para que la app / el adaptador lo usen.

   Requiere cargar antes, en el <head> de index.html:
     <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
     <script src="./supabase-config.js"></script>
     <script src="./supabase-bridge.js"></script>
   ───────────────────────────────────────────────────────────── */
(function () {
  "use strict";

  if (!window.supabase || typeof window.supabase.createClient !== "function") {
    console.error(
      "[supabase-bridge] No se cargó supabase-js. Agregá el <script> del CDN antes de este archivo."
    );
    return;
  }
  if (!window.SUPABASE_URL || !window.SUPABASE_ANON_KEY) {
    console.error("[supabase-bridge] Falta SUPABASE_URL o SUPABASE_ANON_KEY (revisá supabase-config.js).");
    return;
  }

  // Cliente único para toda la app.
  var client = window.supabase.createClient(window.SUPABASE_URL, window.SUPABASE_ANON_KEY, {
    auth: { persistSession: true, autoRefreshToken: true },
  });

  // Reemplaza el objeto para exponer directamente el cliente conectado.
  window.supabase = client;

  /* Helpers de autenticación — la base exige sesión válida (RLS). */
  window.oloAuth = {
    async entrar(correo, clave) {
      var r = await client.auth.signInWithPassword({ email: correo, password: clave });
      if (r.error) throw r.error;
      return r.data;
    },
    async salir() {
      await client.auth.signOut();
    },
    async sesion() {
      var r = await client.auth.getSession();
      return r.data.session;
    },
  };

  /* Atajos a las funciones RPC de la base (ver CONECTAR_SUPABASE.md, paso 3). */
  window.oloApi = {
    registrarTurno: function (args) {
      return client.rpc("registrar_turno", args);
    },
    resumenCiclo: function (offset) {
      return client.rpc("resumen_ciclo", { p_offset: offset == null ? -1 : offset });
    },
    serieSemanal: function (n) {
      return client.rpc("serie_semanal", { p_n: n == null ? 8 : n });
    },
    ejecucionPresupuesto: function (anio, mes) {
      return client.rpc("ejecucion_presupuesto", { p_anio: anio, p_mes: mes });
    },
    catalogos: async function () {
      var out = {};
      var q = await Promise.all([
        client.from("departamento").select("id,nombre,orden,activo").eq("activo", true).order("orden"),
        client.from("cliente").select("id,nombre,activo").eq("activo", true).order("nombre"),
        client.from("colaborador").select("id,nombre_completo,activo").eq("activo", true).order("nombre_completo"),
        client.from("tarifa").select("monto_crc").is("vigente_hasta", null).limit(1),
      ]);
      out.departamentos = q[0].data || [];
      out.clientes = q[1].data || [];
      out.colaboradores = q[2].data || [];
      out.tarifa = q[3].data && q[3].data[0] ? Number(q[3].data[0].monto_crc) : 2750;
      return out;
    },
  };

  /* ───────────────────────────────────────────────────────────
     window.storage — puente para el bundle compilado (out/index.html)
     El bundle guarda su estado con window.storage.get/set(clave).
     Lo redirigimos a la tabla public.app_estado de Supabase, con
     respaldo en localStorage para uso offline.
     (Correr antes el SQL: supabse/app_estado.sql)
     ─────────────────────────────────────────────────────────── */
  window.storage = {
    async get(clave) {
      try {
        var r = await client.from("app_estado").select("datos").eq("clave", clave).maybeSingle();
        if (!r.error && r.data && r.data.datos != null) {
          return { value: JSON.stringify(r.data.datos) };
        }
        if (!r.error) return null; // conectó, sin fila
        console.warn("[supabase-bridge] storage.get:", r.error.message);
      } catch (e) {
        console.warn("[supabase-bridge] storage.get sin conexión:", e);
      }
      try {
        var l = localStorage.getItem(clave);
        return l ? { value: l } : null;
      } catch (e2) {
        return null;
      }
    },
    async set(clave, valorStr) {
      try { localStorage.setItem(clave, valorStr); } catch (e) {}
      var datos;
      try { datos = JSON.parse(valorStr); } catch (e) { datos = valorStr; }
      try {
        var r = await client
          .from("app_estado")
          .upsert({ clave: clave, datos: datos }, { onConflict: "clave" });
        if (r.error) console.warn("[supabase-bridge] storage.set:", r.error.message);
      } catch (e3) {
        console.warn("[supabase-bridge] storage.set sin conexión:", e3);
      }
    },
  };

  console.info("[supabase-bridge] Cliente Supabase listo. window.storage conectado a app_estado.");
})();
