-- ============================================================
-- RELACIONES FÍSICAS (para el Schema Visualizer) +
-- TABLA RESUMEN DE LA NORMALIZACIÓN (relación por relación)
-- Proyecto: lkxqhutzlgkiiirtbohv (dashboard-Genius)
-- Fecha: 2026-09-07
--
-- REQUISITO: haber ejecutado antes sql_normalizacion_y_visualizacion.sql
-- CÓMO EJECUTAR: SQL Editor → New Query → pegar todo → Run
--
-- DESPUÉS DE EJECUTAR, para VER las relaciones:
--   Menú izquierdo → Database → Schema Visualizer
--   (ahí verás el diagrama con las líneas entre tablas)
-- ============================================================


-- ============================================================
-- PARTE 1: FOREIGN KEYS FÍSICAS
-- Se crean como NOT VALID = NO escanean las 600K filas al
-- crearse (instantáneo, sin bloqueo). Aplican a inserts nuevos,
-- y el Schema Visualizer las dibuja igual.
-- ============================================================

-- transacciones → dim_casa_apuestas
ALTER TABLE transacciones_novusbet
  DROP CONSTRAINT IF EXISTS fk_trans_casa;
ALTER TABLE transacciones_novusbet
  ADD CONSTRAINT fk_trans_casa
  FOREIGN KEY (casa_apuestas) REFERENCES dim_casa_apuestas (nombre)
  NOT VALID;

-- transacciones → dim_juego
ALTER TABLE transacciones_novusbet
  DROP CONSTRAINT IF EXISTS fk_trans_juego;
ALTER TABLE transacciones_novusbet
  ADD CONSTRAINT fk_trans_juego
  FOREIGN KEY (juego) REFERENCES dim_juego (nombre)
  NOT VALID;

-- transacciones → dim_tipo_transaccion
ALTER TABLE transacciones_novusbet
  DROP CONSTRAINT IF EXISTS fk_trans_tipo;
ALTER TABLE transacciones_novusbet
  ADD CONSTRAINT fk_trans_tipo
  FOREIGN KEY (tipo_transaccion) REFERENCES dim_tipo_transaccion (nombre)
  NOT VALID;

-- Valida el histórico completo (las dims ya contienen todos los
-- valores existentes, así que esto debe pasar sin errores).
ALTER TABLE transacciones_novusbet VALIDATE CONSTRAINT fk_trans_casa;
ALTER TABLE transacciones_novusbet VALIDATE CONSTRAINT fk_trans_juego;
ALTER TABLE transacciones_novusbet VALIDATE CONSTRAINT fk_trans_tipo;


-- ============================================================
-- PARTE 2: TABLA RESUMEN DE LA NORMALIZACIÓN (1 a 1)
-- Cada fila documenta UNA relación del modelo. La ves en
-- Table Editor → resumen_normalizacion
-- ============================================================

DROP TABLE IF EXISTS resumen_normalizacion;
CREATE TABLE resumen_normalizacion (
  id              serial PRIMARY KEY,
  tabla_origen    text NOT NULL,
  columna_origen  text NOT NULL,
  tabla_destino   text NOT NULL,
  columna_destino text NOT NULL,
  cardinalidad    text NOT NULL,   -- N:1, 1:1, 1:N
  tipo_relacion   text NOT NULL,   -- 'FK física' o 'lógica (join en vista)'
  vista_que_la_usa text,
  descripcion     text
);

INSERT INTO resumen_normalizacion
  (tabla_origen, columna_origen, tabla_destino, columna_destino,
   cardinalidad, tipo_relacion, vista_que_la_usa, descripcion)
VALUES
  ('transacciones_novusbet', 'casa_apuestas', 'dim_casa_apuestas', 'nombre',
   'N:1', 'FK física', 'vn_transacciones',
   'Cada transacción pertenece a una casa de apuestas'),

  ('transacciones_novusbet', 'juego', 'dim_juego', 'nombre',
   'N:1', 'FK física', 'vn_transacciones',
   'Cada transacción de juego referencia un juego del catálogo'),

  ('transacciones_novusbet', 'tipo_transaccion', 'dim_tipo_transaccion', 'nombre',
   'N:1', 'FK física', 'vn_transacciones',
   'Withdraw, Deposit, etc. normalizados en catálogo'),

  ('transacciones_novusbet', 'disciplina', 'disciplinas', 'nombre',
   'N:1', 'lógica (join en vista)', 'vn_transacciones',
   'Join con lower() porque el catálogo usa mayúscula inicial (Casino vs casino)'),

  ('transacciones_novusbet', 'usuario', 'usuarios_novusbet', 'usuario',
   'N:1', 'lógica (join en vista)', 'vn_transacciones, vn_usuario_diario',
   'Sin FK física porque usuarios_novusbet tiene filas duplicadas por usuario; vn_usuarios deduplica'),

  ('transacciones_novusbet', 'id_usuario_novusbet', 'usuarios_novusbet', 'id_usuario',
   'N:1', 'lógica (join alternativo)', NULL,
   'Llave alternativa por ID interno de NovusBet'),

  ('dim_juego', 'disciplina', 'disciplinas', 'nombre',
   'N:1', 'lógica (join en vista)', NULL,
   'Cada juego pertenece a una disciplina'),

  ('usuarios_novusbet', 'estado', 'estados_usuario', 'nombre',
   'N:1', 'lógica (catálogo)', NULL,
   'Estado del usuario (Habilitado, etc.)'),

  ('usuarios_novusbet', 'tipo', 'tipos_usuario', 'nombre',
   'N:1', 'lógica (catálogo)', NULL,
   'Tipo de usuario (Jugador, etc.)'),

  ('apuestas_deportivas', 'usuario', 'usuarios_novusbet', 'usuario',
   'N:1', 'lógica', NULL,
   'Apuestas deportivas ligadas al usuario');

GRANT SELECT ON resumen_normalizacion TO anon, authenticated, service_role;


-- ============================================================
-- PARTE 3: CONSULTA "VER RELACIONES EN VIVO"
-- Lista las FKs físicas reales que existen ahora en tu base.
-- Guárdala (Save) para consultarla cuando quieras.
-- ============================================================
SELECT
  tc.table_name        AS tabla_origen,
  kcu.column_name      AS columna_origen,
  ccu.table_name       AS tabla_destino,
  ccu.column_name      AS columna_destino,
  tc.constraint_name   AS nombre_fk
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tabla_origen, columna_origen;


-- ============================================================
-- VERIFICACIÓN FINAL: el resumen completo de la normalización
-- ============================================================
SELECT tabla_origen, columna_origen,
       '→' AS rel,
       tabla_destino, columna_destino,
       cardinalidad, tipo_relacion
FROM resumen_normalizacion
ORDER BY id;
