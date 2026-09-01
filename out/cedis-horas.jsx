import React, { useState, useEffect, useMemo, useRef } from "react";
import {
  ResponsiveContainer, ComposedChart, Bar, Line, Area, XAxis, YAxis,
  CartesianGrid, Tooltip, ReferenceLine, Cell, LineChart
} from "recharts";

/* ═══════════════════════════════════════════════════════════════
   MARCA OLO — único punto de cambio de la identidad visual.
   Colores muestreados del logo y de la aplicación de movilidad.
   ═══════════════════════════════════════════════════════════════ */
const MARCA = {
  logo: "data:image/png;base64,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",   // logo OLO incrustado, fondo transparente

  fuentes: "https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500&display=swap",
  display: "'Poppins',ui-sans-serif,system-ui,sans-serif",
  cuerpo:  "'Poppins',ui-sans-serif,system-ui,-apple-system,sans-serif",
  dato:    "'Poppins',ui-sans-serif,system-ui,sans-serif",              // cifras (tabular)
  codigo:  "'IBM Plex Mono',ui-monospace,SFMono-Regular,monospace",     // códigos de contenedor

  fondo:   "#EEF0F1",   // fondo de página OLO
  placa:   "#FFFFFF",   // tarjetas
  placa2:  "#F0F2F3",   // campos de formulario y botones secundarios
  tinta:   "#1A1A1A",   // texto principal
  tinta2:  "#686E73",   // texto secundario (4,5:1 sobre el fondo gris)
  tinta3:  "#8E959A",   // etiquetas y ejes (3,0:1)
  linea:   "#E4E6E8",   // bordes
  linea2:  "#EEF0F1",   // divisiones internas y rejilla de gráficos

  senal:   "#00B497",   // teal OLO exacto — rellenos: cinta del ciclo, barras de progreso
  senalGrafico: "#00A88D",// mismo matiz, 3,0:1 sobre blanco — mínimo para elementos no textuales
  senalOscuro: "#008570",// mismo matiz, 4,6:1 sobre blanco — botones, enlaces y texto teal
  acero:   "#251E1F",   // DATOS — negro del logo: barras de horas y costo real
  acero2:  "#B7E4D9",   // banda de incertidumbre
  acero3:  "#E6F6F2",

  alerta:  "#D93A2B",   // sobregiro
  alertaSuave: "#FDECEA",
  aviso:   "#E29B29",   // "al límite" — punto del semáforo (relleno)
  avisoTexto: "#A06B16", // el mismo ámbar legible como texto (4,6:1)
  ok:      "#008570",
  okSuave: "#E6F6F2",

  radio:      "14px",   // tarjetas
  radioChico: "10px",   // botones y campos
  sombra:  "0 1px 3px rgba(26,26,26,.07), 0 1px 2px rgba(26,26,26,.04)",
};

const CSS = `
@import url('${MARCA.fuentes}');

.cedis{
  --concreto:${MARCA.fondo}; --placa:${MARCA.placa}; --placa-2:${MARCA.placa2};
  --tinta:${MARCA.tinta}; --tinta-2:${MARCA.tinta2}; --tinta-3:${MARCA.tinta3};
  --linea:${MARCA.linea}; --linea-2:${MARCA.linea2};
  --senal:${MARCA.senal}; --senal-oscuro:${MARCA.senalOscuro}; --senal-gr:${MARCA.senalGrafico};
  --acero:${MARCA.acero}; --acero-2:${MARCA.acero2}; --acero-3:${MARCA.acero3};
  --alerta:${MARCA.alerta}; --alerta-suave:${MARCA.alertaSuave};
  --ok:${MARCA.ok}; --ok-suave:${MARCA.okSuave}; --aviso:${MARCA.aviso}; --aviso-texto:${MARCA.avisoTexto};
  --radio:${MARCA.radio}; --radio-chico:${MARCA.radioChico}; --sombra:${MARCA.sombra};
  --dis:${MARCA.display}; --cuerpo:${MARCA.cuerpo}; --dato:${MARCA.dato}; --codigo:${MARCA.codigo};
  font-family:var(--cuerpo); color:var(--tinta); background:var(--concreto);
  min-height:100%; -webkit-font-smoothing:antialiased;
}
.cedis *{box-sizing:border-box;}
.cedis button{font-family:inherit;}
.cedis :focus-visible{outline:2px solid var(--senal); outline-offset:2px;}
@media (prefers-reduced-motion: reduce){ .cedis *{transition:none!important; animation:none!important;} }

/* ── tipografía ── */
.cedis .rot{font-family:var(--dis); text-transform:uppercase; letter-spacing:.11em; font-weight:600; font-size:10.5px; color:var(--tinta-2); line-height:1.2;}
.cedis .rot-b{font-family:var(--dis); text-transform:uppercase; letter-spacing:.08em; font-weight:600;}
.cedis .num{font-family:var(--dato); font-variant-numeric:tabular-nums; font-weight:600; letter-spacing:-.01em;}
.cedis h1,.cedis h2,.cedis h3{font-family:var(--dis); margin:0; font-weight:600; letter-spacing:-.01em;}
.cedis h1{font-size:19px;} .cedis h2{font-size:16px;}
.cedis h3{font-size:11px; letter-spacing:.11em; text-transform:uppercase; color:var(--tinta-2); font-weight:600;}

/* ── estructura ── */
.cedis .marco{max-width:1120px; margin:0 auto; padding:0 16px 120px;}
.cedis .barra{background:#fff; border-bottom:4px solid var(--senal); padding:14px 16px 13px; position:sticky; top:0; z-index:30;}
.cedis .barra-in{max-width:1120px; margin:0 auto; display:flex; align-items:center; gap:14px; flex-wrap:wrap;}
.cedis .barra .divisor{width:1px; align-self:stretch; background:var(--linea);}
.cedis .sello{background:var(--senal-oscuro); color:#fff; font-family:var(--dis); font-weight:600; text-transform:uppercase; letter-spacing:.1em; font-size:10px; padding:5px 10px; border-radius:999px;}

/* ── cinta del ciclo (elemento firma) ── */
.cedis .cinta{background:#fff; border-bottom:1px solid var(--linea); position:sticky; top:0; z-index:20;}
.cedis .cinta-in{max-width:1120px; margin:0 auto; padding:12px 16px 14px;}
.cedis .cinta-cab{display:flex; align-items:baseline; justify-content:space-between; gap:10px; margin-bottom:10px; flex-wrap:wrap;}
.cedis .corchete{display:flex; align-items:stretch; border-top:3px solid var(--senal); border-radius:3px;}
.cedis .dia{flex:1; min-width:0; padding:7px 4px 0; text-align:center; position:relative;}
.cedis .dia-rot{font-family:var(--dis); font-size:10px; font-weight:600; letter-spacing:.07em; color:var(--tinta-3); text-transform:uppercase;}
.cedis .dia-fec{font-family:var(--dato); font-size:10px; color:var(--tinta-3); font-variant-numeric:tabular-nums;}
.cedis .dia.hoy .dia-rot,.cedis .dia.hoy .dia-fec{color:var(--tinta); font-weight:700;}
.cedis .dia.hoy::before{content:""; position:absolute; top:-3px; left:12%; right:12%; height:3px; background:var(--acero); border-radius:3px;}
.cedis .bar-col{height:34px; display:flex; align-items:flex-end; justify-content:center; margin-top:5px;}
.cedis .bar{width:56%; min-height:3px; background:var(--senal); border-radius:3px 3px 0 0; transition:height .3s ease;}
.cedis .bar.vacia{background:var(--linea); height:3px;}
.cedis .dia-h{font-family:var(--dato); font-size:10px; color:var(--tinta-2); padding:3px 0 0; font-variant-numeric:tabular-nums;}

/* ── superficies ── */
.cedis .placa{background:#fff; border-radius:var(--radio); box-shadow:var(--sombra); margin-top:16px; overflow:hidden;}
.cedis .placa-cab{padding:14px 18px; border-bottom:1px solid var(--linea); display:flex; align-items:center; justify-content:space-between; gap:10px; flex-wrap:wrap;}
.cedis .placa-cue{padding:18px;}
.cedis .rejilla{display:grid; gap:1px; background:var(--linea); border-radius:var(--radio); box-shadow:var(--sombra); overflow:hidden;}
.cedis .kpi{background:#fff; padding:14px 16px;}
.cedis .kpi .rot{margin-bottom:7px;}
.cedis .kpi-v{font-family:var(--dato); font-variant-numeric:tabular-nums; font-size:25px; font-weight:600; line-height:1.1; letter-spacing:-.025em;}
.cedis .kpi-s{font-size:12.5px; color:var(--tinta-2); margin-top:4px; line-height:1.45;}
.cedis .g4,.cedis .g2,.cedis .g3{grid-template-columns:repeat(2,1fr);}
@media(max-width:420px){ .cedis .g3,.cedis .g4{grid-template-columns:1fr;} }
@media(min-width:640px){ .cedis .g4{grid-template-columns:repeat(4,1fr);} .cedis .g2{grid-template-columns:repeat(2,1fr);} .cedis .g3{grid-template-columns:repeat(3,1fr);} }

/* ── formulario ── */
.cedis label.campo{display:block; margin-bottom:14px;}
.cedis label.campo>span{display:block; font-family:var(--dis); text-transform:uppercase; letter-spacing:.11em; font-size:10.5px; font-weight:600; color:var(--tinta-2); margin-bottom:6px;}
.cedis input,.cedis select,.cedis textarea{
  width:100%; padding:12px 13px; border:1px solid transparent; background:var(--placa-2);
  font-family:var(--cuerpo); font-size:16px; color:var(--tinta); border-radius:var(--radio-chico);
  transition:border-color .15s, background .15s;
}
.cedis input.num-in{font-variant-numeric:tabular-nums;}
.cedis input:focus,.cedis select:focus,.cedis textarea:focus{background:#fff; border-color:var(--senal); outline:none; box-shadow:0 0 0 3px var(--acero-3);}
.cedis .fila{display:grid; grid-template-columns:1fr 1fr; gap:12px;}
.cedis .chips{display:flex; flex-wrap:wrap; gap:7px;}
.cedis .chip{border:1px solid var(--linea); background:#fff; padding:8px 14px; border-radius:999px; font-family:var(--cuerpo); font-weight:500; font-size:13px; cursor:pointer; color:var(--tinta-2); transition:all .15s;}
.cedis .chip:hover{border-color:var(--senal-oscuro); color:var(--tinta);}
.cedis .chip[aria-pressed="true"]{background:var(--senal-oscuro); border-color:var(--senal-oscuro); color:#fff;}
.cedis .btn{border:1px solid var(--senal-oscuro); background:var(--senal-oscuro); color:#fff; padding:12px 20px; border-radius:var(--radio-chico); font-family:var(--cuerpo); font-weight:600; font-size:14px; cursor:pointer; transition:filter .15s;}
.cedis .btn:hover:not(:disabled){filter:brightness(.93);}
.cedis .btn:disabled{opacity:.4; cursor:not-allowed;}
.cedis .btn-2{background:#fff; color:var(--tinta); border-color:var(--linea);}
.cedis .btn-2:hover:not(:disabled){border-color:var(--tinta-3); filter:none;}
.cedis .btn-s{padding:8px 14px; font-size:13px;}
.cedis .btn-senal{background:var(--senal-oscuro); border-color:var(--senal-oscuro); color:#fff;}
.cedis .btn-peligro{background:#fff; border-color:var(--alerta); color:var(--alerta);}
.cedis .lig{background:none; border:0; color:var(--senal-oscuro); font-size:13px; font-weight:500; cursor:pointer; padding:4px 6px; border-radius:6px;}
.cedis .lig:hover{background:var(--acero-3);}

/* ── embarques ── */
.cedis .emb-fila{display:grid; grid-template-columns:1fr 92px 40px; gap:8px; align-items:center; margin-bottom:9px;}
.cedis .cont-cod{font-family:var(--codigo); text-transform:uppercase; letter-spacing:.04em;}
.cedis .marca{display:inline-block; font-family:var(--codigo); font-size:11px; letter-spacing:.03em; border:1px solid var(--linea); border-radius:6px; padding:3px 7px; text-transform:uppercase; background:var(--placa-2); color:var(--tinta-2); white-space:nowrap;}
.cedis .x{border:1px solid var(--linea); background:#fff; border-radius:var(--radio-chico); width:40px; height:44px; cursor:pointer; color:var(--tinta-2); font-size:17px;}
.cedis .x:hover:not(:disabled){border-color:var(--alerta); color:var(--alerta);}

/* ── tablas ── */
.cedis .tabla-env{overflow-x:auto; -webkit-overflow-scrolling:touch;}
.cedis table{width:100%; border-collapse:collapse; font-size:13.5px; min-width:520px;}
.cedis th{font-family:var(--dis); text-transform:uppercase; letter-spacing:.09em; font-size:10px; font-weight:600; color:var(--tinta-2); text-align:left; padding:10px 14px; border-bottom:1px solid var(--linea); white-space:nowrap;}
.cedis td{padding:11px 14px; border-bottom:1px solid var(--linea-2); vertical-align:top;}
.cedis td.n,.cedis th.n{text-align:right; font-family:var(--dato); font-variant-numeric:tabular-nums; white-space:nowrap;}
.cedis tbody tr:hover{background:var(--linea-2);}
.cedis tr:last-child td{border-bottom:0;}
.cedis .tot td{border-top:2px solid var(--acero); font-weight:600; background:var(--placa-2);}
.cedis .tot:hover td{background:var(--placa-2);}

/* ── desglose ── */
.cedis .desg{display:flex; flex-direction:column; gap:11px;}
.cedis .desg-f{display:grid; grid-template-columns:1fr auto; gap:8px; align-items:baseline;}
.cedis .desg-n{font-size:13.5px; font-weight:500;}
.cedis .pista{height:8px; background:var(--linea-2); grid-column:1/-1; border-radius:999px; overflow:hidden;}
.cedis .pista i{display:block; height:100%; background:var(--senal); border-radius:999px;}

/* ── estados ── */
.cedis .aviso{padding:12px 14px; font-size:13.5px; line-height:1.5; color:var(--aviso-texto); border-left:4px solid var(--aviso); background:#FDF6EA; border-radius:var(--radio-chico);}
.cedis .aviso.rojo{border-color:var(--alerta); background:var(--alerta-suave); color:#8C231A;}
.cedis .aviso.verde{border-color:var(--ok); background:var(--ok-suave); color:#00604F;}
.cedis .vacio{padding:44px 20px; text-align:center; color:var(--tinta-2);}
.cedis .vacio p{margin:0 0 16px; font-size:14px; line-height:1.55;}

/* ── navegación ── */
.cedis .nav{position:fixed; bottom:0; left:0; right:0; background:#fff; display:flex; z-index:40;
  box-shadow:0 -1px 3px rgba(26,26,26,.08); padding-bottom:env(safe-area-inset-bottom);}
.cedis .nav button{flex:1; background:none; border:0; border-top:3px solid transparent; color:var(--tinta-2); padding:12px 4px 14px; font-family:var(--cuerpo); font-weight:500; font-size:13px; cursor:pointer;}
.cedis .nav button[aria-current="page"]{color:var(--senal-oscuro); border-top-color:var(--senal); font-weight:600;}
.cedis .paso{display:flex; align-items:center; gap:8px;}
.cedis .paso button{width:38px; height:38px; border:1px solid var(--linea); background:#fff; border-radius:var(--radio-chico); cursor:pointer; font-size:16px; line-height:1; color:var(--tinta);}
.cedis .paso button:hover:not(:disabled){border-color:var(--senal-oscuro); color:var(--senal-oscuro);}
.cedis .paso button:disabled{opacity:.35; cursor:not-allowed;}
.cedis .toast{position:fixed; left:16px; right:16px; bottom:82px; background:var(--tinta); color:#fff; padding:14px 16px; border-radius:var(--radio-chico); z-index:50; font-size:14px; display:flex; gap:11px; align-items:center; box-shadow:0 6px 20px rgba(26,26,26,.2);}
.cedis .toast .sello{flex-shrink:0;}
@media(min-width:900px){ .cedis .toast{left:auto; right:24px; max-width:420px;} }
.cedis .semaforo{width:10px; height:10px; border-radius:999px; display:inline-block; flex-shrink:0;}
`;

/* ════════════════════════════════════════════════════════
   1. REGLAS DE NEGOCIO
   ════════════════════════════════════════════════════════ */

const TARIFA_DEFECTO = 2750;          // ₡ por hora por colaborador
const DIA_CORTE = 5;                  // 5 = viernes (JS: 0=Dom … 6=Sáb)
const DIAS = ["VIE", "SÁB", "DOM", "LUN", "MAR", "MIÉ", "JUE"];
const MESES = ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Set","Oct","Nov","Dic"];

/* — fechas locales sin corrimiento UTC — */
const aFecha = (iso) => { const [a,m,d] = iso.split("-").map(Number); return new Date(a, m-1, d); };
const aISO   = (f) => `${f.getFullYear()}-${String(f.getMonth()+1).padStart(2,"0")}-${String(f.getDate()).padStart(2,"0")}`;
const sumaDias = (f, n) => { const x = new Date(f); x.setDate(x.getDate()+n); return x; };
const hoyISO = () => aISO(new Date());
const fmtCorto = (iso) => { const f = aFecha(iso); return `${String(f.getDate()).padStart(2,"0")}/${String(f.getMonth()+1).padStart(2,"0")}`; };
const fmtLargo = (iso) => { const f = aFecha(iso); return `${String(f.getDate()).padStart(2,"0")}/${String(f.getMonth()+1).padStart(2,"0")}/${f.getFullYear()}`; };

/**
 * Ciclo operativo VIERNES → JUEVES.
 * offset 0 = ciclo que contiene la fecha (en curso);  -1 = ciclo cerrado anterior.
 */
function ciclo(fechaRef = new Date(), offset = 0) {
  const d = new Date(fechaRef); d.setHours(0,0,0,0);
  const atras = (d.getDay() - DIA_CORTE + 7) % 7;   // días transcurridos desde el viernes
  const inicio = sumaDias(d, -atras + offset*7);    // viernes
  const fin = sumaDias(inicio, 6);                  // jueves
  return { inicio: aISO(inicio), fin: aISO(fin), etiqueta: `${fmtCorto(aISO(inicio))} – ${fmtCorto(aISO(fin))}` };
}
/** El viernes se audita el ciclo recién cerrado ⇒ siempre offset −1. */
const cicloAuditoria = (ref = new Date()) => ciclo(ref, -1);
const enRango = (iso, r) => iso >= r.inicio && iso <= r.fin;

/**
 * Horas trabajadas. Soporta turnos que cruzan medianoche y descuenta el
 * tiempo no laborado (almuerzo/café). Redondeo configurable al bloque más cercano.
 */
function horasTurno(entrada, salida, descansoMin = 0, bloqueMin = 1) {
  if (!entrada || !salida) return 0;
  const [h1,m1] = entrada.split(":").map(Number);
  const [h2,m2] = salida.split(":").map(Number);
  let min = (h2*60 + m2) - (h1*60 + m1);
  if (min < 0) min += 1440;                         // el turno cruzó medianoche
  // entrada == salida son 0 h, no 24: casi siempre es un error de digitación
  min = Math.max(0, min - (descansoMin || 0));
  if (bloqueMin > 1) min = Math.round(min / bloqueMin) * bloqueMin;
  return Math.round((min / 60) * 100) / 100;
}
const costoTurno = (horas, tarifa = TARIFA_DEFECTO) => Math.round(horas * tarifa);

/* — formato — */
const miles = (n) => { const s = String(Math.abs(Math.round(n || 0))); return (n < 0 ? "-" : "") + s.replace(/\B(?=(\d{3})+(?!\d))/g, "."); };
const crc  = (n) => "₡" + miles(n);
const crcK = (n) => Math.abs(n) >= 1e6 ? "₡" + (n/1e6).toFixed(1).replace(".",",") + "M"
                  : Math.abs(n) >= 1e3 ? "₡" + miles(n/1e3) + "k" : "₡" + miles(n);
const hh   = (n) => (n || 0).toFixed(2).replace(".", ",");
const pct  = (n) => (isFinite(n) ? Math.round(n*100) : 0) + "%";

/**
 * Proyección de horas/costo para las próximas semanas.
 * Mezcla regresión lineal (tendencia) con suavizado exponencial (nivel reciente)
 * y amortigua la pendiente para no extrapolar de forma explosiva.
 */
function proyectar(serie, semanas = 4, { alfa = 0.4, amort = 0.85, mezcla = 0.6 } = {}) {
  const y = serie.filter((v) => isFinite(v));
  if (y.length < 2) {
    const base = y[0] || 0;
    return { puntos: Array.from({length:semanas}, () => ({ valor: base, min: base, max: base })),
             pendiente: 0, sigma: 0, confianza: "baja" };
  }
  const n = y.length;
  // Mínimos cuadrados: y = a + b·x
  const sx = (n-1)*n/2, sxx = (n-1)*n*(2*n-1)/6;
  const sy = y.reduce((a,b)=>a+b,0);
  const sxy = y.reduce((a,v,i)=>a+v*i,0);
  const den = n*sxx - sx*sx;
  const b = den === 0 ? 0 : (n*sxy - sx*sy) / den;
  const a = (sy - b*sx) / n;
  // Nivel suavizado (EWMA)
  let ewma = y[0];
  for (let i=1;i<n;i++) ewma = alfa*y[i] + (1-alfa)*ewma;
  // Error residual → banda de incertidumbre (~80 %)
  const res = y.map((v,i)=> v - (a + b*i));
  const sigma = Math.sqrt(res.reduce((s,r)=>s+r*r,0) / Math.max(1, n-2));
  const puntos = [];
  let acumAmort = 0;
  for (let h=1; h<=semanas; h++) {
    acumAmort += Math.pow(amort, h);
    const reg = a + b*(n-1+h);
    const sua = ewma + b*acumAmort;
    const v = Math.max(0, mezcla*reg + (1-mezcla)*sua);
    const margen = 1.28 * sigma * Math.sqrt(h);      // el error crece con el horizonte
    puntos.push({ valor: v, min: Math.max(0, v-margen), max: v+margen });
  }
  const cv = sigma / (sy/n || 1);
  return { puntos, pendiente: b, sigma, confianza: cv < 0.15 ? "alta" : cv < 0.35 ? "media" : "baja" };
}

/** Ejecución presupuestaria del mes con ritmo de gasto proyectado. */
function ejecucion(gastado, presupuesto, ref = new Date()) {
  const dias = new Date(ref.getFullYear(), ref.getMonth()+1, 0).getDate();
  const transcurridos = Math.max(1, ref.getDate());
  const ritmo = gastado / transcurridos;
  const proyectado = ritmo * dias;
  const p = presupuesto > 0 ? gastado / presupuesto : 0;
  const pProy = presupuesto > 0 ? proyectado / presupuesto : 0;
  const estado = presupuesto <= 0 ? "sin"
    : pProy > 1.05 ? "excedido" : pProy > 0.95 ? "limite" : "meta";
  return { dias, transcurridos, ritmo, proyectado, p, pProy, estado,
           disponible: presupuesto - gastado };
}
const COLOR_ESTADO = { meta: MARCA.ok, limite: MARCA.aviso, excedido: MARCA.alerta, sin: MARCA.tinta3 };
// Los KPI y el texto del semáforo usan la variante legible; el punto de color usa el relleno.
const COLOR_ESTADO_TEXTO = { meta: MARCA.ok, limite: MARCA.avisoTexto, excedido: MARCA.alerta, sin: MARCA.tinta2 };
const TEXTO_ESTADO = { meta:"Dentro de presupuesto", limite:"Al límite del ritmo", excedido:"Ritmo por encima del presupuesto", sin:"Sin presupuesto cargado" };

/* ════════════════════════════════════════════════════════
   2. PERSISTENCIA
   ════════════════════════════════════════════════════════ */

const K_DATOS = "cedis:datos:v2";
const memoria = {};

/* Cliente Supabase inicializado por out/supabase-bridge.js (window.supabase).
   Si no está disponible, la app cae a localStorage / memoria sin romperse. */
const sb = () =>
  (typeof window !== "undefined" &&
    window.supabase &&
    typeof window.supabase.from === "function")
    ? window.supabase
    : null;

const almacen = {
  async leer(k) {
    // 1) Supabase (fuente de verdad)
    const cli = sb();
    if (cli) {
      try {
        const { data, error } = await cli
          .from("app_estado").select("datos").eq("clave", k).maybeSingle();
        if (!error && data && data.datos) { memoria[k] = data.datos; return data.datos; }
        if (!error) return null;                 // conectó pero no hay fila aún
        console.warn("[almacen] lectura Supabase:", error.message);
      } catch (e) { console.warn("[almacen] Supabase no disponible al leer:", e); }
    }
    // 2) Respaldo local
    try { const r = localStorage.getItem(k); if (r) return JSON.parse(r); } catch {}
    return memoria[k] ?? null;
  },
  async escribir(k, v) {
    memoria[k] = v;
    // Respaldo local siempre (rápido y offline)
    try { localStorage.setItem(k, JSON.stringify(v)); } catch {}
    // Supabase
    const cli = sb();
    if (cli) {
      try {
        const { error } = await cli
          .from("app_estado")
          .upsert({ clave: k, datos: v }, { onConflict: "clave" });
        if (error) console.warn("[almacen] escritura Supabase:", error.message);
      } catch (e) { console.warn("[almacen] Supabase no disponible al escribir:", e); }
    }
  },
};

const BASE = {
  tarifa: TARIFA_DEFECTO,
  bloqueMin: 15,
  departamentos: ["Recepción", "Valor agregado", "Crossdock", "Pesado", "Alisto", "Despacho", "Zona Franca", "El Coco"],
  clientes: ["EPA", "Cofersa", "Zona Franca", "OLO"],
  colaboradores: [],
  turnos: [],
  presupuestos: {},   // { "2026-08": 4200000 }
};

/* ════════════════════════════════════════════════════════
   3. DATOS DE EJEMPLO (8 ciclos, para ver tendencias)
   ════════════════════════════════════════════════════════ */

function datosEjemplo() {
  const nombres = ["Marvin Ureña Castro","Kimberly Solano Vega","Josué Ramírez Mora","Andrey Chinchilla Rojas",
    "Génesis Aguilar Núñez","Wilberth Zúñiga Salas","Dayana Picado Herrera","Randall Obando Cerdas",
    "Steven Barrantes Mena","Yorleny Fallas Rivera"];
  const prefijos = ["MSCU","TGHU","CSQU","MAEU","HLXU","TCLU"];
  const rnd = (a,b) => a + Math.random()*(b-a);
  const pick = (x) => x[Math.floor(Math.random()*x.length)];
  const turnos = [];
  let id = 1;
  for (let s = 8; s >= 0; s--) {
    const c = ciclo(new Date(), -s);
    const carga = 1 + (8-s)*0.045 + rnd(-0.12, 0.12);          // tendencia creciente + ruido
    for (let d = 0; d < 7; d++) {
      const fecha = aISO(sumaDias(aFecha(c.inicio), d));
      if (fecha > hoyISO()) continue;
      const dom = sumaDias(aFecha(c.inicio), d).getDay() === 0;
      const gente = Math.max(0, Math.round((dom ? 2 : 6) * carga));
      for (let p = 0; p < gente; p++) {
        const eIni = pick(["06:00","06:30","07:00","07:30","13:00"]);
        const [h,m] = eIni.split(":").map(Number);
        const dur = Math.round(rnd(5,10) * 2) / 2;
        const fin = (h*60 + m + dur*60 + 30) % 1440;
        const salida = `${String(Math.floor(fin/60)).padStart(2,"0")}:${String(fin%60).padStart(2,"0")}`;
        const nEmb = 1 + Math.floor(Math.random()*3);
        const embarques = Array.from({length:nEmb}, (_,i) => ({
          id: `e${id}-${i}`,
          codigo: `${pick(prefijos)}${Math.floor(1000000+Math.random()*8999999)}`,
          horas: Math.round((dur/nEmb)*100)/100,
        }));
        turnos.push({
          id: `t${id++}`, fecha, departamento: pick(BASE.departamentos),
          colaborador: pick(nombres), cliente: pick(BASE.clientes),
          entrada: eIni, salida, descansoMin: 30, embarques, nota: "",
        });
      }
    }
  }
  const presupuestos = {};
  const hoy = new Date();
  for (let i = 3; i >= 0; i--) {
    const f = new Date(hoy.getFullYear(), hoy.getMonth()-i, 1);
    presupuestos[`${f.getFullYear()}-${String(f.getMonth()+1).padStart(2,"0")}`] = 5200000;
  }
  return { ...BASE, colaboradores: nombres, turnos, presupuestos };
}

/* ════════════════════════════════════════════════════════
   4. PIEZAS DE INTERFAZ
   ════════════════════════════════════════════════════════ */

const Kpi = ({ rot, valor, sub, color }) => (
  <div className="kpi">
    <div className="rot">{rot}</div>
    <div className="kpi-v" style={color ? { color } : undefined}>{valor}</div>
    {sub && <div className="kpi-s">{sub}</div>}
  </div>
);

function Desglose({ filas, total, unidad = "crc" }) {
  const max = Math.max(...filas.map(f => f.valor), 1);
  if (!filas.length) return <p className="kpi-s">Sin movimientos en el período.</p>;
  return (
    <div className="desg">
      {filas.map(f => (
        <div key={f.nombre}>
          <div className="desg-f">
            <span className="desg-n">{f.nombre}</span>
            <span className="num" style={{ fontSize: 13 }}>
              {unidad === "crc" ? crc(f.valor) : hh(f.valor) + " h"}
              <span style={{ color: "var(--tinta-3)", marginLeft: 8 }}>{pct(f.valor / (total || 1))}</span>
            </span>
          </div>
          <div className="pista"><i style={{ width: `${(f.valor / max) * 100}%` }} /></div>
        </div>
      ))}
    </div>
  );
}

/* ── ELEMENTO FIRMA: la cinta del ciclo Viernes → Jueves ── */
function CintaCiclo({ turnos, rango, tarifa, titulo, derecha }) {
  const dias = useMemo(() => {
    const ini = aFecha(rango.inicio);
    return Array.from({ length: 7 }, (_, i) => {
      const iso = aISO(sumaDias(ini, i));
      const h = turnos.filter(t => t.fecha === iso)
        .reduce((s,t) => s + horasTurno(t.entrada, t.salida, t.descansoMin), 0);
      return { iso, rot: DIAS[i], h };
    });
  }, [turnos, rango]);
  const max = Math.max(...dias.map(d => d.h), 1);
  const totH = dias.reduce((s,d) => s + d.h, 0);
  const hoy = hoyISO();
  return (
    <div className="cinta">
      <div className="cinta-in">
        <div className="cinta-cab">
          <div>
            <div className="rot">{titulo || "Ciclo operativo · viernes a jueves"}</div>
            <div className="num" style={{ fontSize: 15, fontWeight: 600, marginTop: 3 }}>
              {fmtLargo(rango.inicio)} → {fmtLargo(rango.fin)}
            </div>
          </div>
          <div style={{ textAlign: "right" }}>
            {derecha || (<>
              <div className="rot">Acumulado</div>
              <div className="num" style={{ fontSize: 15, fontWeight: 600, marginTop: 3 }}>
                {hh(totH)} h · {crc(totH * tarifa)}
              </div>
            </>)}
          </div>
        </div>
        <div className="corchete">
          {dias.map(d => (
            <div key={d.iso} className={"dia" + (d.iso === hoy ? " hoy" : "")}>
              <div className="dia-rot">{d.rot}</div>
              <div className="dia-fec">{fmtCorto(d.iso)}</div>
              <div className="bar-col">
                <div className={"bar" + (d.h ? "" : " vacia")} style={{ height: d.h ? `${(d.h/max)*100}%` : 2 }} />
              </div>
              <div className="dia-h">{d.h ? hh(d.h) : "—"}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ── selector de ciclo con flechas ── */
const PasoCiclo = ({ offset, setOffset }) => (
  <div className="paso">
    <button onClick={() => setOffset(offset - 1)} aria-label="Ciclo anterior">‹</button>
    <span className="rot-b" style={{ fontSize: 12, minWidth: 96, textAlign: "center" }}>
      {offset === 0 ? "En curso" : offset === -1 ? "Recién cerrado" : `${Math.abs(offset)} ciclos atrás`}
    </span>
    <button onClick={() => setOffset(Math.min(0, offset + 1))} disabled={offset >= 0} aria-label="Ciclo siguiente">›</button>
  </div>
);

/* ── exportar CSV ── */
function descargarCSV(nombre, filas) {
  const csv = filas.map(f => f.map(c => {
    const s = String(c ?? "");
    return /[",;\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(";")).join("\n");
  const url = URL.createObjectURL(new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8;" }));
  const a = document.createElement("a");
  a.href = url; a.download = nombre; a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/* ════════════════════════════════════════════════════════
   5. PANTALLA · REGISTRO DIARIO
   ════════════════════════════════════════════════════════ */

const TURNO_VACIO = () => ({
  id: null, fecha: hoyISO(), departamento: "", colaborador: "", cliente: "",
  entrada: "07:00", salida: "", descansoMin: 30, nota: "",
  embarques: [{ id: "n1", codigo: "", horas: "" }],
});

function Registro({ datos, guardar, borrar, avisar }) {
  const [f, setF] = useState(TURNO_VACIO);
  const [nuevoCliente, setNuevoCliente] = useState(false);
  const set = (k, v) => setF(p => ({ ...p, [k]: v }));

  const horas = horasTurno(f.entrada, f.salida, Number(f.descansoMin) || 0, datos.bloqueMin);
  const costo = costoTurno(horas, datos.tarifa);
  const embValidos = f.embarques.filter(e => e.codigo.trim());
  const horasAsignadas = embValidos.reduce((s,e) => s + (Number(e.horas) || 0), 0);
  const descuadre = horasAsignadas > 0 && Math.abs(horasAsignadas - horas) > 0.02;

  const delDia = useMemo(
    () => datos.turnos.filter(t => t.fecha === f.fecha)
      .sort((a,b) => (a.entrada || "").localeCompare(b.entrada || "")),
    [datos.turnos, f.fecha]
  );
  const totDia = delDia.reduce((s,t) => s + horasTurno(t.entrada, t.salida, t.descansoMin), 0);

  const listo = f.departamento && f.colaborador.trim() && f.cliente && f.entrada && f.salida && horas > 0;

  const setEmb = (i, k, v) => setF(p => {
    const e = p.embarques.map((x,j) => j === i ? { ...x, [k]: v } : x);
    return { ...p, embarques: e };
  });
  const addEmb = () => setF(p => ({ ...p, embarques: [...p.embarques, { id: "n"+Date.now(), codigo: "", horas: "" }] }));
  const delEmb = (i) => setF(p => ({ ...p, embarques: p.embarques.filter((_,j) => j !== i) }));

  const repartir = () => setF(p => {
    const v = p.embarques.filter(e => e.codigo.trim());
    if (!v.length) return p;
    const c = Math.round((horas / v.length) * 100) / 100;
    let k = 0;
    return { ...p, embarques: p.embarques.map(e => e.codigo.trim() ? { ...e, horas: (k++ === v.length-1 ? Math.round((horas - c*(v.length-1))*100)/100 : c) } : e) };
  });

  const enviar = () => {
    if (!listo) return;
    guardar({
      id: f.id || "t" + Date.now() + Math.random().toString(36).slice(2,6),
      fecha: f.fecha, departamento: f.departamento, colaborador: f.colaborador.trim(),
      cliente: f.cliente, entrada: f.entrada, salida: f.salida,
      descansoMin: Number(f.descansoMin) || 0, nota: f.nota.trim(),
      embarques: embValidos.map(e => ({ id: e.id, codigo: e.codigo.trim().toUpperCase(), horas: Number(e.horas) || 0 })),
    });
    avisar(`${f.id ? "Turno actualizado" : "Turno registrado"} · ${hh(horas)} h · ${crc(costo)}`);
    setF({ ...TURNO_VACIO(), fecha: f.fecha, departamento: f.departamento, cliente: f.cliente });
  };

  const editar = (t) => {
    setF({ ...t, descansoMin: t.descansoMin ?? 0, nota: t.nota || "",
      embarques: t.embarques.length ? t.embarques : [{ id: "n1", codigo: "", horas: "" }] });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  return (
    <>
      <div className="placa">
        <div className="placa-cab">
          <h2>{f.id ? "Editar turno" : "Registrar turno"}</h2>
          {f.id && <button className="lig" onClick={() => setF(TURNO_VACIO())}>Cancelar edición</button>}
        </div>
        <div className="placa-cue">
          <div className="fila">
            <label className="campo"><span>Fecha de operación</span>
              <input type="date" className="num-in" value={f.fecha} max={hoyISO()} onChange={e => set("fecha", e.target.value)} />
            </label>
            <label className="campo"><span>Cliente / cuenta</span>
              {nuevoCliente ? (
                <input autoFocus placeholder="Nombre del cliente" value={f.cliente} onChange={e => set("cliente", e.target.value)} onBlur={() => !f.cliente && setNuevoCliente(false)} />
              ) : (
                <select value={f.cliente} onChange={e => e.target.value === "__nuevo" ? (setNuevoCliente(true), set("cliente","")) : set("cliente", e.target.value)}>
                  <option value="">Seleccionar…</option>
                  {datos.clientes.map(c => <option key={c} value={c}>{c}</option>)}
                  <option value="__nuevo">+ Agregar cliente</option>
                </select>
              )}
            </label>
          </div>

          <div className="campo" style={{ marginBottom: 14 }}>
            <span style={{ display:"block", fontFamily:"var(--dis)", textTransform:"uppercase", letterSpacing:".12em", fontSize:10, fontWeight:600, color:"var(--tinta-2)", marginBottom:6 }}>Departamento</span>
            <div className="chips">
              {datos.departamentos.map(d => (
                <button key={d} type="button" className="chip" aria-pressed={f.departamento === d} onClick={() => set("departamento", d)}>{d}</button>
              ))}
            </div>
          </div>

          <label className="campo"><span>Colaborador externo</span>
            <input list="lista-colabs" placeholder="Nombre y apellidos" value={f.colaborador} onChange={e => set("colaborador", e.target.value)} />
            <datalist id="lista-colabs">{datos.colaboradores.map(c => <option key={c} value={c} />)}</datalist>
          </label>

          <div className="fila">
            <label className="campo"><span>Hora de entrada</span>
              <input type="time" className="num-in" value={f.entrada} onChange={e => set("entrada", e.target.value)} />
            </label>
            <label className="campo"><span>Hora de salida</span>
              <input type="time" className="num-in" value={f.salida} onChange={e => set("salida", e.target.value)} />
            </label>
          </div>
          <label className="campo"><span>Tiempo no laborado (min)</span>
            <input type="number" className="num-in" min="0" step="15" value={f.descansoMin} onChange={e => set("descansoMin", e.target.value)} />
          </label>

          {/* — Embarques / contenedores — */}
          <div style={{ borderTop: "1px solid var(--linea-2)", paddingTop: 14, marginTop: 4 }}>
            <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center", marginBottom:10, gap:8, flexWrap:"wrap" }}>
              <h3>Embarques trabajados</h3>
              <button className="lig" onClick={repartir} disabled={!horas}>Repartir horas en partes iguales</button>
            </div>
            {f.embarques.map((e, i) => (
              <div className="emb-fila" key={e.id}>
                <input className="cont-cod" placeholder="MSCU1234567 / N.º embarque" value={e.codigo}
                  onChange={ev => setEmb(i, "codigo", ev.target.value.toUpperCase())} />
                <input className="num-in" type="number" step="0.25" min="0" placeholder="h" value={e.horas}
                  onChange={ev => setEmb(i, "horas", ev.target.value)} />
                <button className="x" onClick={() => delEmb(i)} aria-label="Quitar embarque" disabled={f.embarques.length === 1}>×</button>
              </div>
            ))}
            <button className="btn btn-2 btn-s" onClick={addEmb} style={{ marginTop: 2 }}>+ Otro embarque</button>
            {descuadre && (
              <div className="aviso" style={{ marginTop: 12 }}>
                Las horas asignadas a embarques suman {hh(horasAsignadas)} h y el turno da {hh(horas)} h.
                Ajustá el reparto o dejá las horas de embarque en blanco si no llevás detalle parcial.
              </div>
            )}
          </div>

          <label className="campo" style={{ marginTop: 14 }}><span>Observaciones</span>
            <textarea rows="2" placeholder="Atrasos, retrabajos, incidencias…" value={f.nota} onChange={e => set("nota", e.target.value)} />
          </label>

          {/* — cálculo en vivo — */}
          <div className="rejilla g3" style={{ marginBottom: 14 }}>
            <Kpi rot="Horas del turno" valor={hh(horas)} sub={`Bloques de ${datos.bloqueMin} min`} />
            <Kpi rot={`Tarifa · ₡${miles(datos.tarifa)}/h`} valor={crc(costo)} sub="Costo operativo del día" />
            <Kpi rot="Embarques" valor={String(embValidos.length)} sub={embValidos.length ? embValidos.map(e => e.codigo).join(" · ") : "Sin detalle"} />
          </div>

          <button className="btn btn-senal" onClick={enviar} disabled={!listo} style={{ width: "100%" }}>
            {f.id ? "Guardar cambios" : "Registrar turno"}
          </button>
          {!listo && <p className="kpi-s" style={{ marginTop: 8 }}>Faltan: {[
            !f.departamento && "departamento", !f.colaborador.trim() && "colaborador",
            !f.cliente && "cliente", !f.salida && "hora de salida", (f.salida && horas <= 0) && "horas válidas",
          ].filter(Boolean).join(", ")}.</p>}
        </div>
      </div>

      {/* — turnos ya registrados ese día — */}
      <div className="placa">
        <div className="placa-cab">
          <h2>Registrado el {fmtLargo(f.fecha)}</h2>
          <span className="num" style={{ fontSize: 13 }}>{delDia.length} turnos · {hh(totDia)} h · {crc(totDia * datos.tarifa)}</span>
        </div>
        {delDia.length === 0 ? (
          <div className="vacio"><p>Todavía no hay turnos para esta fecha. El primero que registrés aparece acá.</p></div>
        ) : (
          <div className="tabla-env">
            <table>
              <thead><tr>
                <th>Colaborador</th><th>Depto.</th><th>Cliente</th><th className="n">Entrada</th><th className="n">Salida</th>
                <th className="n">Horas</th><th className="n">Costo</th><th>Embarques</th><th></th>
              </tr></thead>
              <tbody>
                {delDia.map(t => {
                  const h = horasTurno(t.entrada, t.salida, t.descansoMin);
                  return (
                    <tr key={t.id}>
                      <td style={{ fontWeight: 600 }}>{t.colaborador}</td>
                      <td>{t.departamento}</td><td>{t.cliente}</td>
                      <td className="n">{t.entrada}</td><td className="n">{t.salida}</td>
                      <td className="n">{hh(h)}</td><td className="n">{crc(h * datos.tarifa)}</td>
                      <td><div style={{ display:"flex", gap:4, flexWrap:"wrap" }}>
                        {t.embarques.map(e => <span className="marca" key={e.id}>{e.codigo}{e.horas ? ` · ${hh(e.horas)}h` : ""}</span>)}
                      </div></td>
                      <td style={{ whiteSpace: "nowrap" }}>
                        <button className="lig" onClick={() => editar(t)}>Editar</button>
                        <button className="lig" style={{ color: "var(--alerta)" }} onClick={() => borrar(t.id)}>Borrar</button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}

/* ════════════════════════════════════════════════════════
   6. PANTALLA · AUDITORÍA SEMANAL (VIE → JUE)
   ════════════════════════════════════════════════════════ */

function agrupar(turnos, clave, tarifa) {
  const m = new Map();
  turnos.forEach(t => {
    const h = horasTurno(t.entrada, t.salida, t.descansoMin);
    const k = t[clave] || "—";
    const a = m.get(k) || { nombre: k, horas: 0, costo: 0, turnos: 0 };
    a.horas += h; a.costo += h * tarifa; a.turnos++;
    m.set(k, a);
  });
  return [...m.values()].sort((a,b) => b.costo - a.costo);
}

function Semana({ datos, offset, setOffset }) {
  const rango = useMemo(() => ciclo(new Date(), offset), [offset]);
  const previo = useMemo(() => ciclo(new Date(), offset - 1), [offset]);
  const T = datos.tarifa;

  const enCiclo = useMemo(() => datos.turnos.filter(t => enRango(t.fecha, rango)), [datos.turnos, rango]);
  const enPrevio = useMemo(() => datos.turnos.filter(t => enRango(t.fecha, previo)), [datos.turnos, previo]);

  const suma = (ts) => ts.reduce((s,t) => s + horasTurno(t.entrada, t.salida, t.descansoMin), 0);
  const horas = suma(enCiclo), horasPrev = suma(enPrevio);
  const costo = horas * T;
  const personas = new Set(enCiclo.map(t => t.colaborador)).size;
  const embarques = enCiclo.reduce((s,t) => s + t.embarques.length, 0);
  const delta = horasPrev > 0 ? (horas - horasPrev) / horasPrev : 0;

  const porCliente = agrupar(enCiclo, "cliente", T);
  const porDepto   = agrupar(enCiclo, "departamento", T);
  const porPersona = agrupar(enCiclo, "colaborador", T);

  const exportar = () => {
    const filas = [["Fecha","Departamento","Colaborador","Cliente","Entrada","Salida","Descanso (min)","Horas","Tarifa CRC","Costo CRC","Embarques","Observaciones"]];
    enCiclo.slice().sort((a,b) => a.fecha.localeCompare(b.fecha)).forEach(t => {
      const h = horasTurno(t.entrada, t.salida, t.descansoMin);
      filas.push([fmtLargo(t.fecha), t.departamento, t.colaborador, t.cliente, t.entrada, t.salida,
        t.descansoMin || 0, hh(h), T, Math.round(h*T),
        t.embarques.map(e => e.codigo + (e.horas ? `(${hh(e.horas)}h)` : "")).join(" | "), t.nota || ""]);
    });
    filas.push([]);
    filas.push(["TOTAL CICLO", `${fmtLargo(rango.inicio)} a ${fmtLargo(rango.fin)}`, "", "", "", "", "", hh(horas), T, Math.round(costo)]);
    descargarCSV(`auditoria_${rango.inicio}_${rango.fin}.csv`, filas);
  };

  return (
    <>
      <CintaCiclo turnos={enCiclo} rango={rango} tarifa={T}
        titulo={offset === -1 ? "Ciclo a auditar · recién cerrado" : offset === 0 ? "Ciclo en curso" : "Ciclo histórico"}
        derecha={<PasoCiclo offset={offset} setOffset={setOffset} />} />

      <div className="marco">
        <div className="rejilla g4" style={{ marginTop: 14 }}>
          <Kpi rot="Horas del ciclo" valor={hh(horas)} sub={`${enCiclo.length} turnos registrados`} />
          <Kpi rot="Costo del ciclo" valor={crc(costo)} sub={`Tarifa ₡${miles(T)}/h`} />
          <Kpi rot="Personal externo" valor={String(personas)} sub={`${embarques} embarques atendidos`} />
          <Kpi rot="Contra ciclo anterior" valor={(delta >= 0 ? "+" : "") + pct(delta)}
            sub={`${hh(horasPrev)} h el ciclo previo`}
            color={delta > 0.1 ? "var(--alerta)" : delta < -0.05 ? "var(--ok)" : undefined} />
        </div>

        {offset === 0 && (
          <div className="aviso" style={{ marginTop: 14 }}>
            Este ciclo todavía está abierto. El corte de auditoría se hace el viernes sobre el ciclo recién cerrado
            ({fmtLargo(previo.inicio)} → {fmtLargo(previo.fin)}).{" "}
            <button className="lig" onClick={() => setOffset(-1)}>Ver ese ciclo</button>
          </div>
        )}

        <div className="rejilla g2" style={{ marginTop: 14, background: "transparent", border: 0, gap: 14 }}>
          <div className="placa" style={{ marginTop: 0 }}>
            <div className="placa-cab"><h2>Por cliente</h2></div>
            <div className="placa-cue"><Desglose filas={porCliente.map(x => ({ nombre: x.nombre, valor: x.costo }))} total={costo} /></div>
          </div>
          <div className="placa" style={{ marginTop: 0 }}>
            <div className="placa-cab"><h2>Por departamento</h2></div>
            <div className="placa-cue"><Desglose filas={porDepto.map(x => ({ nombre: x.nombre, valor: x.costo }))} total={costo} /></div>
          </div>
        </div>

        <div className="placa">
          <div className="placa-cab">
            <h2>Horas por colaborador</h2>
            <button className="btn btn-2 btn-s" onClick={exportar} disabled={!enCiclo.length}>Exportar CSV</button>
          </div>
          {!porPersona.length ? (
            <div className="vacio"><p>No hay turnos en este ciclo. Cambiá de ciclo con las flechas o registrá turnos en la pestaña Registrar.</p></div>
          ) : (
            <div className="tabla-env">
              <table>
                <thead><tr><th>Colaborador</th><th className="n">Turnos</th><th className="n">Horas</th><th className="n">Promedio/turno</th><th className="n">Costo</th></tr></thead>
                <tbody>
                  {porPersona.map(p => (
                    <tr key={p.nombre}>
                      <td style={{ fontWeight: 600 }}>{p.nombre}</td>
                      <td className="n">{p.turnos}</td>
                      <td className="n">{hh(p.horas)}</td>
                      <td className="n" style={{ color: p.horas/p.turnos > 10 ? "var(--alerta)" : undefined }}>{hh(p.horas/p.turnos)}</td>
                      <td className="n">{crc(p.costo)}</td>
                    </tr>
                  ))}
                  <tr className="tot">
                    <td>Total del ciclo</td><td className="n">{enCiclo.length}</td><td className="n">{hh(horas)}</td>
                    <td className="n">{hh(horas / (enCiclo.length || 1))}</td><td className="n">{crc(costo)}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="placa">
          <div className="placa-cab"><h2>Detalle de embarques</h2></div>
          {!enCiclo.length ? <div className="vacio"><p>Sin embarques en el ciclo.</p></div> : (
            <div className="tabla-env">
              <table>
                <thead><tr><th>Fecha</th><th>Colaborador</th><th>Cliente</th><th className="n">Horas</th><th>Contenedores / embarques</th></tr></thead>
                <tbody>
                  {enCiclo.slice().sort((a,b) => a.fecha.localeCompare(b.fecha) || a.entrada.localeCompare(b.entrada)).map(t => (
                    <tr key={t.id}>
                      <td className="n">{fmtCorto(t.fecha)}</td>
                      <td>{t.colaborador}</td><td>{t.cliente}</td>
                      <td className="n">{hh(horasTurno(t.entrada, t.salida, t.descansoMin))}</td>
                      <td><div style={{ display:"flex", gap:4, flexWrap:"wrap" }}>
                        {t.embarques.length ? t.embarques.map(e => <span className="marca" key={e.id}>{e.codigo}{e.horas ? ` · ${hh(e.horas)}h` : ""}</span>)
                          : <span style={{ color: "var(--tinta-3)" }}>sin detalle</span>}
                      </div></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </>
  );
}

/* ════════════════════════════════════════════════════════
   7. PANTALLA · TABLERO FINANCIERO Y PROYECCIÓN
   ════════════════════════════════════════════════════════ */

const claveMes = (iso) => iso.slice(0, 7);
const nombreMes = (k) => { const [a,m] = k.split("-"); return `${MESES[Number(m)-1]} ${a}`; };

function Tablero({ datos, setPresupuesto }) {
  const T = datos.tarifa;
  const [semanasBase, setSemanasBase] = useState(8);   // ventana de análisis (4–8)
  const [horizonte, setHorizonte] = useState(4);

  /* — serie por ciclo Vie→Jue (12 ciclos hacia atrás, sin incluir el abierto) — */
  const serie = useMemo(() => {
    const out = [];
    for (let i = 12; i >= 1; i--) {
      const c = ciclo(new Date(), -i);
      const ts = datos.turnos.filter(t => enRango(t.fecha, c));
      const h = ts.reduce((s,t) => s + horasTurno(t.entrada, t.salida, t.descansoMin), 0);
      out.push({ etiqueta: c.etiqueta, inicio: c.inicio, horas: Math.round(h*100)/100, costo: Math.round(h*T),
                 personas: new Set(ts.map(t => t.colaborador)).size });
    }
    return out;
  }, [datos.turnos, T]);

  const conDatos = serie.filter(s => s.horas > 0);
  const ventana = conDatos.slice(-semanasBase);
  const pron = useMemo(() => proyectar(ventana.map(s => s.horas), horizonte), [ventana, horizonte]);

  const datosGrafico = useMemo(() => {
    const base = serie.slice(-Math.max(semanasBase, 8)).map(s => ({ etiqueta: s.etiqueta, real: s.horas }));
    if (base.length) base[base.length-1].proy = base[base.length-1].real;
    pron.puntos.forEach((p, i) => {
      const c = ciclo(new Date(), i);   // ciclos futuros: 0 = en curso, 1, 2…
      base.push({ etiqueta: c.etiqueta, proy: Math.round(p.valor*100)/100,
                  banda: [Math.round(p.min*100)/100, Math.round(p.max*100)/100] });
    });
    return base;
  }, [serie, pron, semanasBase]);

  const horasPromPersona = ventana.length
    ? ventana.reduce((s,v) => s + v.horas, 0) / Math.max(1, ventana.reduce((s,v) => s + v.personas, 0)) : 0;

  /* — histórico mensual — */
  const meses = useMemo(() => {
    const m = new Map();
    datos.turnos.forEach(t => {
      const k = claveMes(t.fecha);
      const h = horasTurno(t.entrada, t.salida, t.descansoMin);
      const a = m.get(k) || { k, horas: 0 };
      a.horas += h; m.set(k, a);
    });
    return [...m.values()].sort((a,b) => a.k.localeCompare(b.k)).slice(-12)
      .map(x => ({ ...x, horas: Math.round(x.horas*100)/100, costo: Math.round(x.horas*T),
                   etiqueta: nombreMes(x.k), presupuesto: datos.presupuestos[x.k] || 0 }));
  }, [datos.turnos, datos.presupuestos, T]);

  /* — presupuesto del mes seleccionado — */
  const [mesSel, setMesSel] = useState(claveMes(hoyISO()));
  const presupuesto = datos.presupuestos[mesSel] || 0;
  const gastoMes = useMemo(() => datos.turnos.filter(t => claveMes(t.fecha) === mesSel)
    .reduce((s,t) => s + horasTurno(t.entrada, t.salida, t.descansoMin), 0) * T, [datos.turnos, mesSel, T]);
  const esMesActual = mesSel === claveMes(hoyISO());
  const ej = ejecucion(gastoMes, presupuesto, esMesActual ? new Date() : new Date(Number(mesSel.slice(0,4)), Number(mesSel.slice(5,7)), 0));
  const opcionesMes = useMemo(() => {
    const s = new Set([...Object.keys(datos.presupuestos), ...datos.turnos.map(t => claveMes(t.fecha)), claveMes(hoyISO())]);
    return [...s].sort().reverse();
  }, [datos.presupuestos, datos.turnos]);

  const anioHoras = datos.turnos.filter(t => t.fecha.startsWith(hoyISO().slice(0,4)))
    .reduce((s,t) => s + horasTurno(t.entrada, t.salida, t.descansoMin), 0);

  const tooltipStyle = { background: MARCA.tinta, border: 0, color: "#fff", fontSize: 12, fontFamily: MARCA.dato };
  const ejeTick = { fontSize: 10, fontFamily: MARCA.dato, fill: MARCA.tinta3 };

  return (
    <div className="marco">
      <div className="rejilla g4" style={{ marginTop: 14 }}>
        <Kpi rot={`Horas ${hoyISO().slice(0,4)}`} valor={hh(anioHoras)} sub="personal externo, año a la fecha" />
        <Kpi rot={`Costo ${hoyISO().slice(0,4)}`} valor={crcK(anioHoras * T)} sub={crc(anioHoras * T)} />
        <Kpi rot="Promedio por ciclo" valor={hh(ventana.reduce((s,v)=>s+v.horas,0) / (ventana.length||1))}
             sub={`últimos ${ventana.length} ciclos`} />
        <Kpi rot="Tendencia semanal" valor={(pron.pendiente >= 0 ? "+" : "") + hh(pron.pendiente) + " h"}
             sub={`confianza ${pron.confianza}`}
             color={pron.pendiente > 0 ? "var(--alerta)" : "var(--ok)"} />
      </div>

      {/* ── PRESUPUESTO ── */}
      <div className="placa">
        <div className="placa-cab">
          <h2>Presupuesto contra ejecución</h2>
          <select value={mesSel} onChange={e => setMesSel(e.target.value)} style={{ width: "auto", padding: "7px 10px", fontSize: 14 }}>
            {opcionesMes.map(k => <option key={k} value={k}>{nombreMes(k)}</option>)}
          </select>
        </div>
        <div className="placa-cue">
          <label className="campo" style={{ maxWidth: 320 }}><span>Presupuesto aprobado del mes (₡)</span>
            <input type="number" className="num-in" min="0" step="50000" value={presupuesto || ""}
              placeholder="0" onChange={e => setPresupuesto(mesSel, Number(e.target.value) || 0)} />
          </label>

          <div className="pista" style={{ height: 22, position: "relative", marginBottom: 8 }}>
            <i style={{ width: `${Math.min(100, ej.p*100)}%`, background: COLOR_ESTADO[ej.estado] }} />
            {presupuesto > 0 && ej.pProy > ej.p && (
              <span style={{ position:"absolute", top:0, bottom:0, left:`${Math.min(100, ej.pProy*100)}%`, width:2, background:"var(--tinta)" }} />
            )}
          </div>
          <div style={{ display:"flex", justifyContent:"space-between", fontSize:12, color:"var(--tinta-2)", marginBottom:14 }}>
            <span className="num">{crc(gastoMes)} ejecutado</span>
            <span className="num">{presupuesto ? crc(presupuesto) : "sin presupuesto"}</span>
          </div>

          <div className="rejilla g4">
            <Kpi rot="Ejecución" valor={pct(ej.p)} sub={`${ej.transcurridos} de ${ej.dias} días`} color={COLOR_ESTADO_TEXTO[ej.estado]} />
            <Kpi rot="Disponible" valor={crcK(ej.disponible)} sub={ej.disponible < 0 ? "sobregiro" : crc(ej.disponible)}
                 color={ej.disponible < 0 ? "var(--alerta)" : undefined} />
            <Kpi rot="Ritmo diario" valor={crcK(ej.ritmo)} sub="promedio del mes en curso" />
            <Kpi rot="Cierre proyectado" valor={crcK(ej.proyectado)} sub={presupuesto ? `${pct(ej.pProy)} del presupuesto` : "cargá el presupuesto"}
                 color={COLOR_ESTADO_TEXTO[ej.estado]} />
          </div>

          <div className={"aviso " + (ej.estado === "excedido" ? "rojo" : ej.estado === "meta" ? "verde" : "")} style={{ marginTop: 14, display:"flex", gap:10, alignItems:"flex-start" }}>
            <span className="semaforo" style={{ background: COLOR_ESTADO[ej.estado], marginTop: 4 }} />
            <span>
              <strong>{TEXTO_ESTADO[ej.estado]}.</strong>{" "}
              {presupuesto > 0 && (ej.estado === "excedido"
                ? `Al ritmo actual el mes cierra en ${crc(ej.proyectado)}, ${crc(ej.proyectado - presupuesto)} por encima. Equivale a ${hh((ej.proyectado - presupuesto)/T)} horas de más.`
                : ej.estado === "limite"
                ? `El cierre proyectado (${crc(ej.proyectado)}) queda a menos de 5 % del techo. Conviene revisar la asignación de la próxima semana.`
                : `Quedan ${crc(ej.disponible)} disponibles, equivalentes a ${hh(ej.disponible / T)} horas de personal externo.`)}
              {presupuesto <= 0 && "Ingresá el monto aprobado para activar el semáforo y el cierre proyectado."}
            </span>
          </div>
        </div>
      </div>

      {/* ── PROYECCIÓN ── */}
      <div className="placa">
        <div className="placa-cab">
          <h2>Proyección de demanda</h2>
          <div style={{ display:"flex", gap:8, alignItems:"center", flexWrap:"wrap" }}>
            <span className="rot">Base</span>
            <div className="chips">
              {[4,6,8].map(n => <button key={n} className="chip" aria-pressed={semanasBase===n} onClick={() => setSemanasBase(n)}>{n} sem</button>)}
            </div>
            <span className="rot">Horizonte</span>
            <div className="chips">
              {[2,4,6].map(n => <button key={n} className="chip" aria-pressed={horizonte===n} onClick={() => setHorizonte(n)}>{n}</button>)}
            </div>
          </div>
        </div>
        <div className="placa-cue">
          {conDatos.length < 2 ? (
            <div className="vacio"><p>Se necesitan al menos dos ciclos cerrados con registros para calcular tendencia.</p></div>
          ) : (<>
            <div style={{ height: 260, marginLeft: -14 }}>
              <ResponsiveContainer width="100%" height="100%">
                <ComposedChart data={datosGrafico} margin={{ top: 8, right: 12, bottom: 4, left: 0 }}>
                  <CartesianGrid stroke={MARCA.linea2} vertical={false} />
                  <XAxis dataKey="etiqueta" tick={ejeTick} interval={0} angle={-38} textAnchor="end" height={52} />
                  <YAxis tick={ejeTick} width={44} />
                  <Tooltip contentStyle={tooltipStyle} labelStyle={{ color: "#8FA0B2" }}
                    formatter={(v, n) => Array.isArray(v) ? [`${hh(v[0])} – ${hh(v[1])} h`, "Rango probable"]
                      : [`${hh(v)} h · ${crc(v*T)}`, n === "real" ? "Real" : "Proyectado"]} />
                  <Area dataKey="banda" stroke="none" fill={MARCA.senal} fillOpacity={0.15} isAnimationActive={false} />
                  <Bar dataKey="real" fill={MARCA.acero} radius={[3,3,0,0]} barSize={16} isAnimationActive={false} />
                  <Line dataKey="proy" stroke={MARCA.senalGrafico} strokeWidth={2.5} strokeDasharray="6 4" dot={{ r: 3.5, fill: MARCA.senalGrafico }} isAnimationActive={false} />
                </ComposedChart>
              </ResponsiveContainer>
            </div>
            <div className="tabla-env" style={{ marginTop: 10 }}>
              <table>
                <thead><tr><th>Ciclo proyectado</th><th className="n">Horas est.</th><th className="n">Rango</th><th className="n">Costo est.</th><th className="n">Personas aprox.</th></tr></thead>
                <tbody>
                  {pron.puntos.map((p, i) => {
                    const c = ciclo(new Date(), i);
                    return (
                      <tr key={i}>
                        <td className="num">{fmtLargo(c.inicio)} → {fmtLargo(c.fin)}{i === 0 && <span className="marca" style={{ marginLeft: 8 }}>en curso</span>}</td>
                        <td className="n" style={{ fontWeight: 600 }}>{hh(p.valor)}</td>
                        <td className="n" style={{ color: "var(--tinta-2)" }}>{hh(p.min)} – {hh(p.max)}</td>
                        <td className="n">{crc(p.valor * T)}</td>
                        <td className="n">{horasPromPersona > 0 ? Math.ceil(p.valor / horasPromPersona) : "—"}</td>
                      </tr>
                    );
                  })}
                  <tr className="tot">
                    <td>Total del horizonte</td>
                    <td className="n">{hh(pron.puntos.reduce((s,p)=>s+p.valor,0))}</td><td className="n"></td>
                    <td className="n">{crc(pron.puntos.reduce((s,p)=>s+p.valor,0) * T)}</td><td className="n"></td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p className="kpi-s" style={{ marginTop: 10 }}>
              Mezcla de regresión lineal sobre los últimos {ventana.length} ciclos con suavizado exponencial del nivel reciente;
              la pendiente se amortigua un 15 % por semana. El rango cubre cerca del 80 % de los desenlaces según la dispersión histórica
              (desviación de {hh(pron.sigma)} h). Confianza {pron.confianza}.
            </p>
          </>)}
        </div>
      </div>

      {/* ── HISTÓRICO MENSUAL ── */}
      <div className="placa">
        <div className="placa-cab"><h2>Histórico mensual</h2></div>
        <div className="placa-cue">
          {!meses.length ? <div className="vacio"><p>Sin historial todavía.</p></div> : (<>
            <div style={{ height: 230, marginLeft: -14 }}>
              <ResponsiveContainer width="100%" height="100%">
                <ComposedChart data={meses} margin={{ top: 8, right: 12, bottom: 4, left: 0 }}>
                  <CartesianGrid stroke={MARCA.linea2} vertical={false} />
                  <XAxis dataKey="etiqueta" tick={ejeTick} />
                  <YAxis tickFormatter={crcK} tick={ejeTick} width={52} />
                  <Tooltip contentStyle={tooltipStyle} labelStyle={{ color: "#8FA0B2" }}
                    formatter={(v, n) => [crc(v), n === "costo" ? "Costo real" : "Presupuesto"]} />
                  <Bar dataKey="costo" radius={[3,3,0,0]} barSize={26} isAnimationActive={false}>
                    {meses.map((m,i) => <Cell key={i} fill={m.presupuesto && m.costo > m.presupuesto ? MARCA.alerta : MARCA.acero} />)}
                  </Bar>
                  <Line dataKey="presupuesto" stroke={MARCA.tinta2} strokeWidth={2} strokeDasharray="4 4" dot={false} isAnimationActive={false} />
                </ComposedChart>
              </ResponsiveContainer>
            </div>
            <div className="tabla-env" style={{ marginTop: 10 }}>
              <table>
                <thead><tr><th>Mes</th><th className="n">Horas</th><th className="n">Costo</th><th className="n">Presupuesto</th><th className="n">Ejecución</th></tr></thead>
                <tbody>
                  {meses.slice().reverse().map(m => (
                    <tr key={m.k}>
                      <td>{m.etiqueta}</td><td className="n">{hh(m.horas)}</td><td className="n">{crc(m.costo)}</td>
                      <td className="n" style={{ color: "var(--tinta-2)" }}>{m.presupuesto ? crc(m.presupuesto) : "—"}</td>
                      <td className="n" style={{ color: m.presupuesto && m.costo > m.presupuesto ? "var(--alerta)" : undefined, fontWeight: 600 }}>
                        {m.presupuesto ? pct(m.costo / m.presupuesto) : "—"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>)}
        </div>
      </div>
    </div>
  );
}

/* ════════════════════════════════════════════════════════
   8. PANTALLA · CATÁLOGOS Y PARÁMETROS
   ════════════════════════════════════════════════════════ */

function ListaEditable({ titulo, items, onAdd, onDel, placeholder }) {
  const [v, setV] = useState("");
  return (
    <div>
      <h3 style={{ marginBottom: 8 }}>{titulo}</h3>
      <div className="chips" style={{ marginBottom: 10 }}>
        {items.length ? items.map(i => (
          <span key={i} className="chip" style={{ cursor: "default", display: "inline-flex", gap: 8, alignItems: "center" }}>
            {i}<button onClick={() => onDel(i)} aria-label={`Quitar ${i}`}
              style={{ background:"none", border:0, cursor:"pointer", color:"var(--alerta)", fontSize:14, padding:0 }}>×</button>
          </span>
        )) : <span className="kpi-s">Lista vacía.</span>}
      </div>
      <div style={{ display: "flex", gap: 8 }}>
        <input value={v} placeholder={placeholder} onChange={e => setV(e.target.value)}
          onKeyDown={e => { if (e.key === "Enter" && v.trim()) { onAdd(v.trim()); setV(""); } }} />
        <button className="btn btn-2 btn-s" onClick={() => { if (v.trim()) { onAdd(v.trim()); setV(""); } }}>Agregar</button>
      </div>
    </div>
  );
}

function Ajustes({ datos, setDatos, avisar }) {
  const up = (p) => setDatos(d => ({ ...d, ...p }));
  const [confirmar, setConfirmar] = useState(false);
  const mesesPres = useMemo(() => {
    const s = new Set([...Object.keys(datos.presupuestos), ...datos.turnos.map(t => claveMes(t.fecha))]);
    return [...s].sort().reverse();
  }, [datos]);

  return (
    <div className="marco">
      <div className="placa">
        <div className="placa-cab"><h2>Parámetros de costeo</h2></div>
        <div className="placa-cue">
          <div className="fila">
            <label className="campo"><span>Tarifa por hora (₡)</span>
              <input type="number" className="num-in" min="0" step="50" value={datos.tarifa}
                onChange={e => up({ tarifa: Number(e.target.value) || 0 })} />
            </label>
            <label className="campo"><span>Redondeo del turno</span>
              <select value={datos.bloqueMin} onChange={e => up({ bloqueMin: Number(e.target.value) })}>
                <option value="1">Al minuto exacto</option>
                <option value="15">Bloques de 15 minutos</option>
                <option value="30">Bloques de 30 minutos</option>
                <option value="60">Hora completa</option>
              </select>
            </label>
          </div>
          <p className="kpi-s">
            La tarifa se aplica a todo el histórico al recalcular. Si negociás una tarifa nueva a partir de una fecha,
            registrala en el campo <code>tarifa_hora</code> del turno en el backend para conservar el costo histórico.
          </p>
        </div>
      </div>

      <div className="placa">
        <div className="placa-cab"><h2>Catálogos</h2></div>
        <div className="placa-cue" style={{ display: "grid", gap: 22 }}>
          <ListaEditable titulo="Departamentos" items={datos.departamentos} placeholder="Ej. Congelados"
            onAdd={v => up({ departamentos: [...new Set([...datos.departamentos, v])] })}
            onDel={v => up({ departamentos: datos.departamentos.filter(x => x !== v) })} />
          <ListaEditable titulo="Clientes / cuentas" items={datos.clientes} placeholder="Ej. Auto Mercado"
            onAdd={v => up({ clientes: [...new Set([...datos.clientes, v])] })}
            onDel={v => up({ clientes: datos.clientes.filter(x => x !== v) })} />
          <ListaEditable titulo="Colaboradores externos" items={datos.colaboradores} placeholder="Nombre y apellidos"
            onAdd={v => up({ colaboradores: [...new Set([...datos.colaboradores, v])] })}
            onDel={v => up({ colaboradores: datos.colaboradores.filter(x => x !== v) })} />
        </div>
      </div>

      <div className="placa">
        <div className="placa-cab"><h2>Presupuestos mensuales</h2></div>
        <div className="tabla-env">
          <table>
            <thead><tr><th>Mes</th><th className="n">Presupuesto (₡)</th><th className="n">Ejecutado</th></tr></thead>
            <tbody>
              {mesesPres.map(k => {
                const gasto = datos.turnos.filter(t => claveMes(t.fecha) === k)
                  .reduce((s,t) => s + horasTurno(t.entrada, t.salida, t.descansoMin), 0) * datos.tarifa;
                return (
                  <tr key={k}>
                    <td style={{ fontWeight: 600 }}>{nombreMes(k)}</td>
                    <td className="n"><input type="number" className="num-in" style={{ padding: "6px 8px", textAlign: "right", maxWidth: 160 }}
                      value={datos.presupuestos[k] || ""} placeholder="0"
                      onChange={e => up({ presupuestos: { ...datos.presupuestos, [k]: Number(e.target.value) || 0 } })} /></td>
                    <td className="n" style={{ color: datos.presupuestos[k] && gasto > datos.presupuestos[k] ? "var(--alerta)" : undefined }}>{crc(gasto)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      <div className="placa">
        <div className="placa-cab"><h2>Datos</h2></div>
        <div className="placa-cue" style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
          <button className="btn btn-2 btn-s" onClick={() => {
            const filas = [["id","fecha","departamento","colaborador","cliente","entrada","salida","descanso_min","horas","costo_crc","embarques","nota"]];
            datos.turnos.slice().sort((a,b) => a.fecha.localeCompare(b.fecha)).forEach(t => {
              const h = horasTurno(t.entrada, t.salida, t.descansoMin);
              filas.push([t.id, t.fecha, t.departamento, t.colaborador, t.cliente, t.entrada, t.salida, t.descansoMin || 0,
                hh(h), Math.round(h*datos.tarifa), t.embarques.map(e => e.codigo).join("|"), t.nota || ""]);
            });
            descargarCSV("cedis_turnos_completo.csv", filas);
          }}>Exportar todo a CSV</button>
          <button className="btn btn-2 btn-s" onClick={() => { setDatos(datosEjemplo()); avisar("Datos de ejemplo cargados: 9 ciclos de historial"); }}>
            Cargar datos de ejemplo
          </button>
          {confirmar ? (
            <>
              <button className="btn btn-peligro btn-s" onClick={() => { setDatos({ ...BASE }); setConfirmar(false); avisar("Se borraron todos los registros"); }}>Sí, borrar todo</button>
              <button className="btn btn-2 btn-s" onClick={() => setConfirmar(false)}>Cancelar</button>
            </>
          ) : (
            <button className="btn btn-peligro btn-s" onClick={() => setConfirmar(true)}>Borrar todos los registros</button>
          )}
        </div>
      </div>
    </div>
  );
}

/* ════════════════════════════════════════════════════════
   9. APLICACIÓN
   ════════════════════════════════════════════════════════ */

const PESTANAS = [
  { id: "registro", rot: "Registrar" },
  { id: "semana",   rot: "Semana" },
  { id: "tablero",  rot: "Tablero" },
  { id: "ajustes",  rot: "Ajustes" },
];

export default function App() {
  const [datos, setDatos] = useState(BASE);
  const [cargando, setCargando] = useState(true);
  const [tab, setTab] = useState("registro");
  const [offset, setOffset] = useState(-1);          // el viernes se audita el ciclo cerrado
  const [toast, setToast] = useState(null);
  const primera = useRef(true);

  useEffect(() => {
    (async () => {
      const g = await almacen.leer(K_DATOS);
      if (g) setDatos({ ...BASE, ...g });
      setCargando(false);
    })();
  }, []);

  useEffect(() => {
    if (cargando) return;
    if (primera.current) { primera.current = false; return; }
    almacen.escribir(K_DATOS, datos);
  }, [datos, cargando]);

  const avisar = (m) => { setToast(m); setTimeout(() => setToast(null), 3800); };

  const guardarTurno = (t) => setDatos(d => ({
    ...d,
    colaboradores: [...new Set([...d.colaboradores, t.colaborador])].sort(),
    clientes: [...new Set([...d.clientes, t.cliente])],
    turnos: d.turnos.some(x => x.id === t.id) ? d.turnos.map(x => x.id === t.id ? t : x) : [...d.turnos, t],
  }));
  const borrarTurno = (id) => { setDatos(d => ({ ...d, turnos: d.turnos.filter(t => t.id !== id) })); avisar("Turno eliminado"); };
  const setPresupuesto = (mes, monto) => setDatos(d => ({ ...d, presupuestos: { ...d.presupuestos, [mes]: monto } }));

  const cicloHoy = ciclo(new Date(), 0);
  const turnosCiclo = datos.turnos.filter(t => enRango(t.fecha, cicloHoy));

  if (cargando) return (
    <div className="cedis"><style>{CSS}</style>
      <div className="marco" style={{ paddingTop: 60 }}><div className="vacio"><p>Cargando registros…</p></div></div>
    </div>
  );

  const vacio = datos.turnos.length === 0;

  return (
    <div className="cedis">
      <style>{CSS}</style>

      <header className="barra">
        <div className="barra-in">
          {MARCA.logo
            ? <img src={MARCA.logo} alt="OLO" style={{ height: 34, width: "auto", display: "block" }} />
            : <span className="sello">OLO</span>}
          <span className="divisor" aria-hidden="true" />
          <div>
            <div className="rot">Centro de distribución · Costa Rica</div>
            <h1 style={{ marginTop: 4 }}>Horas de personal externo</h1>
          </div>
          <div style={{ marginLeft: "auto", textAlign: "right" }}>
            <div className="rot">Tarifa vigente</div>
            <div className="num" style={{ fontSize: 15, fontWeight: 600, marginTop: 3 }}>₡{miles(datos.tarifa)} / h</div>
          </div>
        </div>
      </header>

      {(tab === "registro" || tab === "tablero") && (
        <CintaCiclo turnos={turnosCiclo} rango={cicloHoy} tarifa={datos.tarifa} titulo="Ciclo en curso · viernes a jueves" />
      )}

      {vacio && tab !== "ajustes" && (
        <div className="marco"><div className="placa"><div className="vacio">
          <h2 style={{ marginBottom: 10 }}>Sin registros todavía</h2>
          <p>Registrá el primer turno en esta pestaña, o cargá nueve ciclos de datos de ejemplo para ver cómo se comportan la auditoría semanal y la proyección.</p>
          <button className="btn btn-senal btn-s" onClick={() => { setDatos(datosEjemplo()); avisar("Datos de ejemplo cargados"); }}>Cargar datos de ejemplo</button>
        </div></div></div>
      )}

      {tab === "registro" && <div className="marco"><Registro datos={datos} guardar={guardarTurno} borrar={borrarTurno} avisar={avisar} /></div>}
      {tab === "semana"   && <Semana datos={datos} offset={offset} setOffset={setOffset} />}
      {tab === "tablero"  && <Tablero datos={datos} setPresupuesto={setPresupuesto} />}
      {tab === "ajustes"  && <Ajustes datos={datos} setDatos={setDatos} avisar={avisar} />}

      {toast && <div className="toast"><span className="sello">OK</span>{toast}</div>}

      <nav className="nav">
        {PESTANAS.map(p => (
          <button key={p.id} aria-current={tab === p.id ? "page" : undefined} onClick={() => setTab(p.id)}>{p.rot}</button>
        ))}
      </nav>
    </div>
  );
}
