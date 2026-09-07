-- ============================================================
-- ÍNDICES + VISTAS ANALÍTICAS para transacciones_novusbet
-- Proyecto: lkxqhutzlgkiiirtbohv.supabase.co
-- Fecha: 2026-09-07
--
-- CÓMO EJECUTAR:
--   1. Abre https://app.supabase.com → tu proyecto
--   2. SQL Editor → New Query
--   3. Pega TODO este archivo y presiona "Run"
--   4. Tarda ~30-60 segundos (crea índices sobre ~600K filas)
-- ============================================================


-- ============================================================
-- PARTE 1: ÍNDICES (arreglan los timeouts en consultas grandes)
-- ============================================================

-- El más importante: filtrar/ordenar por fecha de la transacción
CREATE INDEX IF NOT EXISTS idx_trans_fecha
  ON transacciones_novusbet (fecha);

-- Ordenar por fecha de inserción (útil para ver "lo último que llegó")
CREATE INDEX IF NOT EXISTS idx_trans_created_at
  ON transacciones_novusbet (created_at);

-- Búsquedas por usuario
CREATE INDEX IF NOT EXISTS idx_trans_usuario
  ON transacciones_novusbet (usuario);

-- Combinado disciplina + fecha (acelera dashboards por disciplina)
CREATE INDEX IF NOT EXISTS idx_trans_disciplina_fecha
  ON transacciones_novusbet (disciplina, fecha);

-- Por casa de apuestas
CREATE INDEX IF NOT EXISTS idx_trans_casa
  ON transacciones_novusbet (casa_apuestas);

-- Por juego (solo donde hay juego, índice más pequeño)
CREATE INDEX IF NOT EXISTS idx_trans_juego
  ON transacciones_novusbet (juego)
  WHERE juego IS NOT NULL;

-- Por id de transacción NovusBet (detección de duplicados / upserts)
CREATE INDEX IF NOT EXISTS idx_trans_id_novusbet
  ON transacciones_novusbet (id_transaccion_novusbet);

-- Actualiza estadísticas del planificador
ANALYZE transacciones_novusbet;


-- ============================================================
-- PARTE 2: VISTAS ANALÍTICAS (fuentes de datos para Looker)
-- ============================================================

-- ── 1. KPIs generales (1 fila con los números globales) ─────
CREATE OR REPLACE VIEW v_kpi_general AS
SELECT
  COUNT(*)                                  AS total_transacciones,
  COUNT(DISTINCT usuario)                   AS usuarios_unicos,
  ROUND(SUM(monto), 2)                      AS monto_total,
  ROUND(SUM(ingresos), 2)                   AS ingresos_totales,
  ROUND(SUM(comision), 2)                   AS comision_total,
  COUNT(*) FILTER (WHERE es_apuesta)        AS total_apuestas,
  COUNT(*) FILTER (WHERE es_ganancia)       AS total_ganancias,
  MIN(fecha)                                AS primera_transaccion,
  MAX(fecha)                                AS ultima_transaccion
FROM transacciones_novusbet;

-- ── 2. Tendencia diaria (línea de tiempo principal) ─────────
CREATE OR REPLACE VIEW v_tendencia_diaria AS
SELECT
  fecha::date                               AS dia,
  disciplina,
  COUNT(*)                                  AS transacciones,
  COUNT(DISTINCT usuario)                   AS usuarios_unicos,
  ROUND(SUM(monto), 2)                      AS monto,
  ROUND(SUM(ingresos), 2)                   AS ingresos,
  COUNT(*) FILTER (WHERE es_apuesta)        AS apuestas,
  COUNT(*) FILTER (WHERE es_ganancia)       AS ganancias
FROM transacciones_novusbet
GROUP BY fecha::date, disciplina
ORDER BY dia DESC, disciplina;

-- ── 3. Resumen por disciplina ───────────────────────────────
CREATE OR REPLACE VIEW v_resumen_disciplina AS
SELECT
  disciplina,
  COUNT(*)                                  AS transacciones,
  COUNT(DISTINCT usuario)                   AS usuarios_unicos,
  ROUND(SUM(monto), 2)                      AS monto_total,
  ROUND(SUM(ingresos), 2)                   AS ingresos_totales,
  ROUND(AVG(monto), 4)                      AS monto_promedio,
  MAX(fecha)                                AS ultima_actividad
FROM transacciones_novusbet
GROUP BY disciplina
ORDER BY transacciones DESC;

-- ── 4. Resumen mensual ──────────────────────────────────────
CREATE OR REPLACE VIEW v_resumen_mensual AS
SELECT
  to_char(fecha, 'YYYY-MM')                 AS mes,
  disciplina,
  COUNT(*)                                  AS transacciones,
  COUNT(DISTINCT usuario)                   AS usuarios_unicos,
  ROUND(SUM(monto), 2)                      AS monto,
  ROUND(SUM(ingresos), 2)                   AS ingresos
FROM transacciones_novusbet
GROUP BY to_char(fecha, 'YYYY-MM'), disciplina
ORDER BY mes DESC, disciplina;

-- ── 5. Top 100 usuarios últimos 30 días ─────────────────────
CREATE OR REPLACE VIEW v_top_usuarios_30d AS
SELECT
  usuario,
  estado_cliente,
  COUNT(*)                                  AS transacciones,
  ROUND(SUM(monto), 2)                      AS monto_neto,
  ROUND(SUM(ingresos), 2)                   AS ingresos,
  ROUND(SUM(monto) FILTER (WHERE es_apuesta), 2)   AS total_apostado,
  ROUND(SUM(monto) FILTER (WHERE es_ganancia), 2)  AS total_ganado,
  MAX(fecha)                                AS ultima_actividad
FROM transacciones_novusbet
WHERE fecha >= now() - interval '30 days'
GROUP BY usuario, estado_cliente
ORDER BY transacciones DESC
LIMIT 100;

-- ── 6. Usuarios activos HOY ─────────────────────────────────
CREATE OR REPLACE VIEW v_activos_hoy AS
SELECT
  usuario,
  disciplina,
  COUNT(*)                                  AS transacciones,
  ROUND(SUM(monto), 2)                      AS monto,
  ROUND(SUM(ingresos), 2)                   AS ingresos,
  MAX(fecha)                                AS ultima_transaccion
FROM transacciones_novusbet
WHERE fecha >= CURRENT_DATE
GROUP BY usuario, disciplina
ORDER BY transacciones DESC;

-- ── 7. Resumen por juego (top juegos) ───────────────────────
CREATE OR REPLACE VIEW v_resumen_juegos AS
SELECT
  juego,
  disciplina,
  COUNT(*)                                  AS transacciones,
  COUNT(DISTINCT usuario)                   AS usuarios_unicos,
  ROUND(SUM(monto), 2)                      AS monto_neto,
  ROUND(SUM(monto) FILTER (WHERE es_apuesta), 2)   AS total_apostado,
  ROUND(SUM(monto) FILTER (WHERE es_ganancia), 2)  AS total_pagado,
  MAX(fecha)                                AS ultima_actividad
FROM transacciones_novusbet
WHERE juego IS NOT NULL
GROUP BY juego, disciplina
ORDER BY transacciones DESC;

-- ── 8. Resumen por casa de apuestas ─────────────────────────
CREATE OR REPLACE VIEW v_resumen_casa_apuestas AS
SELECT
  casa_apuestas,
  COUNT(*)                                  AS transacciones,
  COUNT(DISTINCT usuario)                   AS usuarios_unicos,
  ROUND(SUM(monto), 2)                      AS monto_total,
  ROUND(SUM(ingresos), 2)                   AS ingresos,
  MIN(fecha)                                AS desde,
  MAX(fecha)                                AS hasta
FROM transacciones_novusbet
GROUP BY casa_apuestas
ORDER BY transacciones DESC;


-- ============================================================
-- PARTE 3: PERMISOS DE LECTURA (para Looker vía API si aplica)
-- ============================================================
GRANT SELECT ON v_kpi_general,
                v_tendencia_diaria,
                v_resumen_disciplina,
                v_resumen_mensual,
                v_top_usuarios_30d,
                v_activos_hoy,
                v_resumen_juegos,
                v_resumen_casa_apuestas
TO anon, authenticated, service_role;


-- ============================================================
-- VERIFICACIÓN (se ejecuta al final, debes ver resultados)
-- ============================================================
SELECT 'v_kpi_general' AS vista, * FROM v_kpi_general;
