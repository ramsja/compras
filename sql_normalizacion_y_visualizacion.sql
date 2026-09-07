-- ============================================================
-- NORMALIZACIÓN (modelo estrella) + VISUALIZACIÓN EN SUPABASE
-- Proyecto: lkxqhutzlgkiiirtbohv (dashboard-Genius)
-- Fecha: 2026-09-07
--
-- Diseño: NO duplica la tabla de 600K filas (tu proyecto está
-- excediendo límites de uso). transacciones_novusbet queda como
-- tabla de HECHOS; se crean DIMENSIONES pequeñas + vistas que
-- unen todo. Un trigger mantiene las dimensiones al día solo.
--
-- CÓMO EJECUTAR: SQL Editor → New Query → pegar todo → Run
-- ============================================================


-- ============================================================
-- PARTE 1: TABLAS DE DIMENSIÓN (se llenan desde tus datos)
-- ============================================================

-- Casas de apuestas (geniusbet.sv, etc.)
CREATE TABLE IF NOT EXISTS dim_casa_apuestas (
  id         serial PRIMARY KEY,
  nombre     text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

INSERT INTO dim_casa_apuestas (nombre)
SELECT DISTINCT casa_apuestas
FROM transacciones_novusbet
WHERE casa_apuestas IS NOT NULL AND casa_apuestas <> ''
ON CONFLICT (nombre) DO NOTHING;

-- Juegos (Golden Diamonds, etc.) con su disciplina
CREATE TABLE IF NOT EXISTS dim_juego (
  id         serial PRIMARY KEY,
  nombre     text UNIQUE NOT NULL,
  disciplina text,
  created_at timestamptz DEFAULT now()
);

INSERT INTO dim_juego (nombre, disciplina)
SELECT juego, min(disciplina)
FROM transacciones_novusbet
WHERE juego IS NOT NULL AND juego <> ''
GROUP BY juego
ON CONFLICT (nombre) DO NOTHING;

-- Tipos de transacción (Withdraw, Deposit, etc.)
CREATE TABLE IF NOT EXISTS dim_tipo_transaccion (
  id         serial PRIMARY KEY,
  nombre     text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

INSERT INTO dim_tipo_transaccion (nombre)
SELECT DISTINCT tipo_transaccion
FROM transacciones_novusbet
WHERE tipo_transaccion IS NOT NULL AND tipo_transaccion <> ''
ON CONFLICT (nombre) DO NOTHING;

-- Índice para unir hechos ↔ usuarios (dimensión ya existente
-- con 39K filas: usuarios_novusbet)
CREATE INDEX IF NOT EXISTS idx_usuarios_nb_usuario
  ON usuarios_novusbet (usuario);


-- ============================================================
-- PARTE 2: TRIGGER — dimensiones se actualizan solas
-- Cada transacción nueva registra casa/juego/tipo si no existen
-- ============================================================

CREATE OR REPLACE FUNCTION fn_actualizar_dimensiones()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.casa_apuestas IS NOT NULL AND NEW.casa_apuestas <> '' THEN
    INSERT INTO dim_casa_apuestas (nombre) VALUES (NEW.casa_apuestas)
    ON CONFLICT (nombre) DO NOTHING;
  END IF;

  IF NEW.juego IS NOT NULL AND NEW.juego <> '' THEN
    INSERT INTO dim_juego (nombre, disciplina) VALUES (NEW.juego, NEW.disciplina)
    ON CONFLICT (nombre) DO NOTHING;
  END IF;

  IF NEW.tipo_transaccion IS NOT NULL AND NEW.tipo_transaccion <> '' THEN
    INSERT INTO dim_tipo_transaccion (nombre) VALUES (NEW.tipo_transaccion)
    ON CONFLICT (nombre) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_actualizar_dimensiones ON transacciones_novusbet;
CREATE TRIGGER trg_actualizar_dimensiones
  BEFORE INSERT ON transacciones_novusbet
  FOR EACH ROW
  EXECUTE FUNCTION fn_actualizar_dimensiones();


-- ============================================================
-- PARTE 3: VISTAS NORMALIZADAS (modelo estrella)
-- ============================================================

-- Dimensión usuario "limpia": 1 fila por usuario, la más reciente
CREATE OR REPLACE VIEW vn_usuarios AS
SELECT DISTINCT ON (usuario)
  usuario,
  id_usuario,
  nombre,
  apellido,
  correo,
  estado,
  tipo,
  moneda,
  saldo,
  saldo_retirable,
  bono,
  bono_activo,
  fecha_registro,
  ultimo_acceso,
  primer_deposito,
  actualizado_at
FROM usuarios_novusbet
WHERE usuario IS NOT NULL
ORDER BY usuario, actualizado_at DESC NULLS LAST;

-- Vista de hechos ENRIQUECIDA: transacción + usuario + catálogos
-- (esta es tu tabla "normalizada" virtual: une todo el modelo)
CREATE OR REPLACE VIEW vn_transacciones AS
SELECT
  t.id,
  t.fecha,
  t.fecha::date              AS dia,
  to_char(t.fecha, 'YYYY-MM') AS mes,
  t.usuario,
  u.nombre                   AS nombre_usuario,
  u.apellido                 AS apellido_usuario,
  u.estado                   AS estado_usuario,
  u.tipo                     AS tipo_usuario,
  d.id                       AS disciplina_id,
  COALESCE(d.nombre, t.disciplina) AS disciplina,
  d.icono                    AS disciplina_icono,
  ca.id                      AS casa_id,
  t.casa_apuestas,
  j.id                       AS juego_id,
  t.juego,
  tt.id                      AS tipo_transaccion_id,
  t.tipo_transaccion,
  t.monto,
  t.ingresos,
  t.comision,
  t.saldo,
  t.saldo_actual,
  t.moneda,
  t.es_apuesta,
  t.es_ganancia
FROM transacciones_novusbet t
LEFT JOIN vn_usuarios          u  ON u.usuario = t.usuario
LEFT JOIN disciplinas          d  ON lower(d.nombre) = lower(t.disciplina)
LEFT JOIN dim_casa_apuestas    ca ON ca.nombre = t.casa_apuestas
LEFT JOIN dim_juego            j  ON j.nombre = t.juego
LEFT JOIN dim_tipo_transaccion tt ON tt.nombre = t.tipo_transaccion;

-- Resumen usuario × día (base para análisis de comportamiento)
CREATE OR REPLACE VIEW vn_usuario_diario AS
SELECT
  t.usuario,
  u.estado                        AS estado_usuario,
  t.fecha::date                   AS dia,
  t.disciplina,
  COUNT(*)                        AS transacciones,
  ROUND(SUM(t.monto), 2)          AS monto_neto,
  ROUND(SUM(t.monto) FILTER (WHERE t.es_apuesta), 2)  AS apostado,
  ROUND(SUM(t.monto) FILTER (WHERE t.es_ganancia), 2) AS ganado,
  MAX(t.fecha)                    AS ultima_actividad
FROM transacciones_novusbet t
LEFT JOIN vn_usuarios u ON u.usuario = t.usuario
GROUP BY t.usuario, u.estado, t.fecha::date, t.disciplina;

-- Permisos de lectura (API / Looker)
GRANT SELECT ON dim_casa_apuestas, dim_juego, dim_tipo_transaccion,
                vn_usuarios, vn_transacciones, vn_usuario_diario
TO anon, authenticated, service_role;


-- ============================================================
-- PARTE 4: VISUALIZACIÓN EN SUPABASE (pestaña "Chart")
-- ============================================================
-- El SQL Editor tiene una pestaña "Chart" junto a "Results".
-- Ejecuta UNA consulta de estas a la vez, abre Chart y configura
-- los ejes como se indica. Guarda cada query con "Save" para
-- reutilizarla (quedan en la lista de queries guardadas).
-- ============================================================

-- ── VIZ 1: Ingresos por día (Chart: Line | X=dia, Y=ingresos) ──
-- SELECT fecha::date AS dia,
--        ROUND(SUM(ingresos),2) AS ingresos,
--        ROUND(SUM(monto),2)    AS monto_neto
-- FROM transacciones_novusbet
-- GROUP BY 1 ORDER BY 1;

-- ── VIZ 2: Transacciones por día y disciplina
--    (Chart: Bar | X=dia, Y=transacciones, agrupa por disciplina) ──
-- SELECT fecha::date AS dia, disciplina, COUNT(*) AS transacciones
-- FROM transacciones_novusbet
-- GROUP BY 1,2 ORDER BY 1;

-- ── VIZ 3: Top 15 juegos por volumen (Chart: Bar | X=juego, Y=apostado) ──
-- SELECT juego,
--        ROUND(ABS(SUM(monto) FILTER (WHERE es_apuesta)),2) AS apostado,
--        ROUND(SUM(monto) FILTER (WHERE es_ganancia),2)     AS pagado
-- FROM transacciones_novusbet
-- WHERE juego IS NOT NULL
-- GROUP BY juego ORDER BY apostado DESC LIMIT 15;

-- ── VIZ 4: Usuarios activos por día (Chart: Line | X=dia, Y=usuarios) ──
-- SELECT fecha::date AS dia, COUNT(DISTINCT usuario) AS usuarios
-- FROM transacciones_novusbet
-- GROUP BY 1 ORDER BY 1;

-- ── VIZ 5: Ingresos por mes y disciplina (Chart: Bar | X=mes, Y=ingresos) ──
-- SELECT to_char(fecha,'YYYY-MM') AS mes, disciplina,
--        ROUND(SUM(ingresos),2) AS ingresos
-- FROM transacciones_novusbet
-- GROUP BY 1,2 ORDER BY 1;


-- ============================================================
-- VERIFICACIÓN FINAL — debes ver el conteo de cada dimensión
-- ============================================================
SELECT 'dim_casa_apuestas'    AS tabla, COUNT(*) AS filas FROM dim_casa_apuestas
UNION ALL
SELECT 'dim_juego',            COUNT(*) FROM dim_juego
UNION ALL
SELECT 'dim_tipo_transaccion', COUNT(*) FROM dim_tipo_transaccion
UNION ALL
SELECT 'vn_usuarios',          COUNT(*) FROM vn_usuarios
UNION ALL
SELECT 'vn_transacciones (muestra hoy)', COUNT(*) FROM vn_transacciones WHERE dia = CURRENT_DATE;
