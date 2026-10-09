# Guía de usuario · Control de horas de personal externo (OLO / CEDIS)

Sistema para registrar las horas del personal externo en el CEDIS, calcular su costo (incluyendo horas extra), auditar la semana y sacar reportes por cliente, embarque y día.

El ciclo de trabajo va de **viernes a jueves**: cada viernes se revisa lo de la semana recién cerrada.

---

## 1. Entrar al sistema

1. Abrí la dirección del sistema en el navegador.
2. Ingresá con tu **correo y contraseña**.
3. Arriba a la derecha ves tu nombre, tu **rol** (Admin u Operario) y el botón **Salir**.

**Roles**
- **Admin**: ve y hace todo, incluidos Ajustes completos, la administración de Usuarios y el borrado masivo.
- **Operario**: registra turnos y ve los reportes; en Ajustes solo puede agregar colaboradores externos. No ve Usuarios ni el borrado masivo.

Si no tenés cuenta, un administrador te la crea (ver sección Usuarios).

---

## 2. La cinta del ciclo (viernes → jueves)

Debajo del encabezado, en Registrar y Tablero, hay una franja con los siete días del ciclo (VIE a JUE), las horas de cada día y el acumulado en horas y colones. Es el recordatorio visual de que la semana **no** empieza el lunes.

---

## 3. Registrar un turno

Pestaña **Registrar**. Es la pantalla del día a día en el patio.

1. **Fecha de operación** (por defecto hoy).
2. **Cliente / cuenta**: elegí de la lista o agregá uno nuevo con "+ Agregar cliente".
3. **Departamento**: tocá el chip correspondiente.
4. **Colaborador externo**: escribí el nombre (autocompleta con los ya usados).
5. **Hora de entrada** y **hora de salida**. Soporta turnos que cruzan medianoche (por ejemplo 22:00 → 06:00 = 8 horas).
6. **Tiempo no laborado (min)**: el almuerzo o café que se descuenta.
7. **Embarques trabajados**: agregá el código de cada contenedor/embarque. Podés dejar las horas por embarque en blanco, o repartirlas:
   - **Repartir horas en partes iguales** divide las horas del turno entre los embarques con código.
8. **Observaciones**: atrasos, retrabajos, incidencias.

Mientras escribís, abajo se ve el **cálculo en vivo**: horas del turno, horas extra, costo (normal + recargo) y embarques.

### Horas extra (por día, por persona)
- El umbral se aplica al **total de horas que un colaborador trabaja en el día**, sumando todos sus turnos/procesos. Las primeras **9,5 horas del día** se pagan a tarifa normal; lo que exceda es **extra**, a **tarifa × 1,5**.
- El umbral (9,5 h) y el recargo (×1,5) se configuran en Ajustes.
- Las horas extra se asignan **cronológicamente a los últimos turnos del día** y se cargan automáticamente al **cliente de esos turnos** (no hay selector manual).
- **Ejemplo**: Pepito trabaja de 7:00 a 17:00 en el proceso 1 (10 h) y de 17:00 a 20:00 en el proceso 2 (3 h) = 13 h → **9,5 normales + 3,5 extra**. Esas 3,5 h extra caen en el proceso 2 (y la media hora final del proceso 1), y se cargan a los clientes de esos turnos.
- En el formulario, al registrar un turno que cruza el umbral, el cálculo en vivo avisa cuántas horas ya trabajó esa persona en el día y cuántas de este turno son extra.

Al final, **Registrar turno** guarda. Los turnos del día aparecen listados abajo, con opción de **Editar** o **Borrar**.

---

## 4. Semana (auditoría del ciclo)

Pestaña **Semana**. Lo que se revisa el viernes.

Arriba podés elegir el período:
- **Ciclo viernes → jueves** (con flechas para navegar ciclos y saltar a la semana de una fecha).
- **Rango de fechas** libre (Desde / Hasta).

### Resumen diario (primer reporte)
Una fila por día con: colaboradores, horas, monto por hora, subtotal de jornada normal, horas extra, monto por hora extra, costo de horas extra y **total general del día**. La última fila es el **gran total**.
- **Filtro por departamento (multiselección)**: tocá "Todos los departamentos" o uno o varios departamentos a la vez.
- **Descargar CSV** baja el reporte diario con el filtro aplicado.

### Otros bloques de la semana
- KPIs del ciclo: horas, costo, horas extra y comparación contra el período anterior.
- **Por cliente** y **Por departamento** (desglose de costo).
- **Horas por colaborador** (tabla con exportación CSV).
- **Detalle de embarques** del ciclo.

---

## 5. Embarques (costo por embarque)

Pestaña **Embarques**. Suma el costo de todas las horas trabajadas por distintos colaboradores bajo un mismo embarque.

Filtros:
- **Rango de fechas** (con atajos: ciclo recién cerrado, en curso, mes en curso, todo).
- **Cliente**.
- **Embarque (código)** para buscar uno específico.

Muestra, por embarque: cliente(s), turnos, personas, horas, costo y % del total. Se descarga en **CSV** o **Excel** (dos hojas: resumen y detalle).

**Fila “(sin embarque)”**: las horas que no están asignadas a ningún contenedor (turnos registrados sin embarque, o con detalle parcial) se agrupan en una fila al final llamada “(sin embarque)”, resaltada en ámbar. Un KPI arriba muestra cuántas horas y cuánto costo quedaron sin asignar a un contenedor.

> **Por qué antes no cuadraba con el Tablero:** el reporte de Embarques solo cuenta horas asignadas a un contenedor y tiene su propio filtro de fechas, mientras que el Tablero suma **todo** el histórico del cliente. Con la fila “(sin embarque)” ya no se pierden horas: **el total de Embarques coincide con el reporte por cliente del Tablero siempre que uses el mismo rango de fechas** (usá el atajo “Todo el historial” para comparar contra el Tablero, que no filtra fecha).
>
> Al filtrar por una compañía, ambos módulos cuentan **todo lo atribuible a esa compañía**, incluidas las horas extra que se le cargaron aunque el horario normal del turno fuera de otro cliente.

---

## 6. Tablero (finanzas y proyección)

Pestaña **Tablero**. La vista gerencial.

- **Filtros** por cliente y departamento (afectan todo el tablero).
- KPIs de horas y costo del año, promedio por ciclo y tendencia.
- **Presupuesto contra ejecución**: cargás el monto aprobado del mes y el semáforo indica si el ritmo de gasto proyectado queda dentro (verde), al límite (amarillo) o por encima (rojo).
- **Proyección de demanda**: estima horas, costo y personas de las próximas semanas. Es una estimación a tarifa base (no incluye recargo por horas extra).
- **Histórico mensual**.
- **Reportes por cliente / departamento / colaborador** y **detalle de turnos**, todos con descarga a Excel. El botón **Descargar Excel (todo)** baja un libro con todas las hojas.

---

## 7. Ajustes (configuración) — solo Admin

Pestaña **Ajustes**.

- **Parámetros de costeo**: tarifa por hora, redondeo del turno, umbral de horas extra por día/persona (9,5 h) y recargo (×1,5).
- **Catálogos**: alta y baja de departamentos, clientes y colaboradores.
- **Presupuestos mensuales**: monto aprobado por mes y su ejecución.
- **Datos**: exportar todo a CSV, cargar datos de ejemplo y borrar todos los registros (con confirmación).
- **Bitácora de cambios**: registro de todo lo que pasa en el sistema (ver abajo).

El **operario** solo ve la sección de colaboradores externos.

---

## 8. Bitácora de cambios (auditoría)

Dentro de Ajustes, el panel **Bitácora de cambios · registros y modificaciones** guarda automáticamente cada acción: quién, cuándo, qué acción (creó / editó / eliminó / agregó / quitó), sobre qué (turno, presupuesto, ajuste, catálogo, usuario) y un detalle.

- Filtrá por tipo de acción o buscá por texto.
- **Descargar CSV** de lo filtrado.
- **Limpiar bitácora** (con confirmación).

---

## 9. Usuarios del sistema — solo Admin

Pestaña **Usuarios** (visible solo para administradores).

- Lista de usuarios con su **nombre**, **correo**, **rol** y **estado** (activo/inactivo).
- **Editar** permite cambiar el nombre, el rol (admin/operario) y activar o desactivar.
- Un usuario **inactivo** pierde el acceso al sistema.

**Importante**: las cuentas de acceso (correo y contraseña) se crean y se eliminan en **Supabase → Authentication → Users**. Desde la app se administra el perfil, el estado y el rol. Cuando se crea una cuenta nueva, queda como **operario** por defecto.

---

## 10. Reportes descargables — resumen

| Dónde | Reporte | Formato |
|---|---|---|
| Semana | Resumen diario (filtro por departamento) | CSV |
| Semana | Horas por colaborador del ciclo | CSV |
| Embarques | Costo por embarque (filtros de cliente/fecha/código) | CSV y Excel |
| Tablero | Por cliente / departamento / colaborador | Excel |
| Tablero | Detalle de turnos | Excel |
| Ajustes | Exportar todo | CSV |
| Ajustes | Bitácora de cambios | CSV |

Los CSV se abren en Excel en español (separador `;`). Los Excel bajan como archivo `.xls` con varias hojas.

---

## 11. Preguntas frecuentes

**¿Por qué la semana empieza el viernes?**
Porque la revisión operativa se hace los viernes por la mañana sobre la semana recién cerrada (viernes a jueves).

**¿Cómo se calcula el costo?**
Horas trabajadas = salida − entrada − tiempo no laborado. El umbral de horas extra se aplica al **total del día por colaborador**: las primeras 9,5 h del día a tarifa normal y el resto a tarifa × 1,5. Si una persona hizo varios procesos el mismo día, se suman todos para decidir las extra. El costo se redondea a colones enteros.

**¿A qué cliente se le cargan las horas extra?**
Al cliente de los turnos donde caen cronológicamente (los últimos del día). Si Pepito hizo el horario normal en un proceso y luego trabajó en otro proceso/cliente que lo llevó sobre las 9,5 h, esas horas extra se le cargan al segundo cliente. Se ve en los reportes "Por cliente" de Semana y Tablero.

**Los datos, ¿se comparten entre dispositivos?**
Sí. Se guardan en la nube (Supabase) y se respaldan localmente para trabajar sin conexión; sincroniza cuando vuelve la señal.

**¿Puedo recuperar algo que borré?**
El borrado de un turno es inmediato. El borrado masivo pide confirmación. Conviene exportar a CSV antes de borrar. La bitácora deja constancia de quién borró qué.
