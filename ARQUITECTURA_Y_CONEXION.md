# 🏗️ Arquitectura y Conexión Directa - Sistema de Reportes

## 📐 Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    NOVUSBET BACKOFFICE                          │
│            https://headoffice.novusbet.com                      │
│                  (Transacciones y Usuarios)                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                  ┌──────────┴──────────┐
                  │   HTTP Request      │
                  │  (Login + Download) │
                  └──────────┬──────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                    PYTHON SYNC ENGINE                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 1. Login con credenciales                                │  │
│  │ 2. Descarga CSV de transacciones                         │  │
│  │ 3. Procesa y clasifica datos                            │  │
│  │ 4. Genera reportes (CSV/JSON)                           │  │
│  │ 5. Sincroniza con Supabase                              │  │
│  └────────────────────┬─────────────────────────────────────┘  │
│                       │                                          │
│       - main.py (descarga única)                                │
│       - sync_realtime.py (cada 30 min)                          │
│       - init_database.py (setup inicial)                        │
└──────────────────────┬──────────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   JSON Payload (REST API)   │
        │   (Registros normalizados)  │
        └──────────────┬──────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│         SUPABASE (PostgreSQL en la nube)                        │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐   │
│  │ Tabla: transaction_records                            │   │
│  │  - id (bigint, PK)                                    │   │
│  │  - user_id, username                                 │   │
│  │  - total, income, balance                            │   │
│  │  - discipline (casino/deportes/otros)                │   │
│  │  - client_status (activo/inactivo/etc)              │   │
│  │  - created_at (timestamp)                            │   │
│  │  - raw (JSON datos originales)                       │   │
│  │  - imported_at (cuando se insertó)                  │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐   │
│  │ Vistas (Views) para análisis:                         │   │
│  │  - v_discipline_summary                              │   │
│  │  - v_client_summary                                  │   │
│  │  - v_daily_trends                                    │   │
│  │  - v_active_today                                    │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐   │
│  │ API REST (PostgREST) automático                       │   │
│  │  GET  /rest/v1/transaction_records                   │   │
│  │  POST /rest/v1/transaction_records                   │   │
│  └────────────────────────────────────────────────────────┘   │
└──────────────────────┬──────────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   HTTP API (REST)           │
        │   JSON Response             │
        └──────────────┬──────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
        │                      ┌──────▼──────┐
        │                      │   BigQuery  │
        │                      │  (Opcional) │
        │                      └─────────────┘
        │
┌───────▼────────────────────────────────────────────────────────┐
│       GOOGLE LOOKER STUDIO (Visualizaciones)                   │
│                                                                  │
│  ┌───────────────────────────────────────────────────────┐    │
│  │ Conexión: PostgreSQL (Supabase)                       │    │
│  │ Credenciales:                                         │    │
│  │  - Host: db.xxxxx.supabase.co                        │    │
│  │  - Port: 5432                                        │    │
│  │  - Database: postgres                               │    │
│  │  - User: postgres                                   │    │
│  │  - Password: [Supabase Master Key]                  │    │
│  └───────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌───────────────────────────────────────────────────────┐    │
│  │ DASHBOARDS:                                           │    │
│  │  📊 KPI Dashboard                                    │    │
│  │     - Total transacciones                           │    │
│  │     - Monto total                                   │    │
│  │     - Usuarios activos                              │    │
│  │  📈 Tendencias                                       │    │
│  │     - Gráfico de líneas por día                     │    │
│  │     - Por disciplina                                │    │
│  │  👥 Análisis de Clientes                            │    │
│  │     - Estado (activo/inactivo)                      │    │
│  │     - Top usuarios por ingresos                     │    │
│  │  💰 Finanzas                                        │    │
│  │     - Ingresos vs gastos                            │    │
│  │     - Por moneda                                    │    │
│  └───────────────────────────────────────────────────────┘    │
│                                                                  │
│  Actualización automática: cada 24h (Looker default)           │
│  Actualización manual: Refresh (Ctrl+R)                        │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

---

## 🔌 CONEXIÓN DIRECTA - Guía Técnica

### 1️⃣ Supabase → Google Looker (RECOMENDADO)

**Ventajas:**
- ✅ Conexión directa a PostgreSQL
- ✅ Actualización en tiempo real (con polling)
- ✅ SQL queries nativas
- ✅ Sin intermediarios

**Pasos:**

#### A) En Supabase - Obtén credenciales de conexión
```
Project Settings → Database → Connection Info
Host: db.xxxxx.supabase.co
Port: 5432
Database: postgres
User: postgres
Password: [Tu contraseña maestra]
```

#### B) En Google Looker Studio
1. Create → Data Source
2. Connector: "PostgreSQL"
3. Fill connection details:
   - **Hostname**: db.xxxxx.supabase.co
   - **Port**: 5432
   - **Database**: postgres
   - **Username**: postgres
   - **Password**: [Contraseña de Supabase]
   - **SSL Mode**: Required

4. ✅ Test connection
5. Selecciona tabla: `transaction_records`
6. Crea tu dashboard

---

### 2️⃣ Validación de Conexión Directa

**Script para validar conectividad:**

```bash
#!/bin/bash
# test_connection.sh

# Instala psql (cliente PostgreSQL)
# macOS: brew install postgresql
# Linux: sudo apt install postgresql-client
# Windows: https://www.postgresql.org/download/windows/

psql -h db.xxxxx.supabase.co \
  -U postgres \
  -d postgres \
  -c "SELECT COUNT(*) as total_records FROM transaction_records;"
```

**Desde Python:**

```python
import psycopg2
from dotenv import load_dotenv
import os

load_dotenv()

try:
    conn = psycopg2.connect(
        host=os.getenv("DB_HOST"),
        database="postgres",
        user="postgres",
        password=os.getenv("DB_PASSWORD"),
        port=5432,
        sslmode="require"
    )
    
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM transaction_records;")
    count = cursor.fetchone()[0]
    
    print(f"✅ Conexión exitosa. Total registros: {count:,}")
    
    cursor.close()
    conn.close()
    
except Exception as e:
    print(f"❌ Error: {e}")
```

---

### 3️⃣ Consultas SQL útiles en Looker

**KPI Principales:**
```sql
SELECT 
  COUNT(*) as total_transactions,
  SUM(total) as total_amount,
  SUM(income) as total_income,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(DISTINCT DATE(created_at)) as days_of_data
FROM transaction_records;
```

**Por Disciplina:**
```sql
SELECT 
  discipline,
  COUNT(*) as records,
  SUM(total) as amount,
  COUNT(DISTINCT user_id) as users
FROM transaction_records
GROUP BY discipline
ORDER BY amount DESC;
```

**Clientes Activos Hoy:**
```sql
SELECT 
  username,
  COUNT(*) as transactions,
  SUM(total) as amount,
  MAX(created_at) as last_activity
FROM transaction_records
WHERE DATE(created_at) = CURRENT_DATE
  AND client_status = 'activo'
GROUP BY username
ORDER BY amount DESC
LIMIT 20;
```

**Tendencia Diaria:**
```sql
SELECT 
  DATE(created_at) as date,
  SUM(total) as daily_total,
  SUM(income) as daily_income,
  COUNT(DISTINCT user_id) as daily_users
FROM transaction_records
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

---

## 🔐 Seguridad - Buenas Prácticas

### Variables de Entorno

```env
# NUNCA en el código
BO_USERNAME=FinanceSV
BO_PASSWORD=Anma07covi*

# Credenciales Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...    # Solo en scripts Python
SUPABASE_ANON_KEY=eyJhbGc...            # Para Looker Studio

# Credenciales DB directo (para conexión PostgreSQL)
DB_HOST=db.xxxxx.supabase.co
DB_PASSWORD=[Tu contraseña maestra]
```

### Permisos en Supabase

```sql
-- Crear usuario con permisos limitados para Looker
CREATE ROLE looker_user WITH LOGIN PASSWORD 'secure_password';

-- Dar permisos solo a lectura
GRANT CONNECT ON DATABASE postgres TO looker_user;
GRANT USAGE ON SCHEMA public TO looker_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO looker_user;
GRANT SELECT ON ALL VIEWS IN SCHEMA public TO looker_user;
```

---

## 📊 Flujo de Datos Completo

### 1. Ciclo de Actualización

```
T+0:00    → Python script inicia
          → Login en NovusBet
          → Descarga CSV

T+0:05    → Procesa datos
          → Clasifica (disciplina, estado)
          → Genera reportes

T+0:10    → Sincroniza con Supabase
          → INSERT 10,000+ registros
          → Actualiza vistas

T+0:15    → Listo para Looker Studio
          → Datos disponibles vía API REST
          → Dashboard refleja cambios

T+0:30    → Se repite el ciclo
```

### 2. Latencia Esperada

- **NovusBet → CSV**: 30-60 segundos
- **CSV → Supabase**: 5-10 segundos
- **Supabase → Looker**: <5 segundos (cached)
- **Looker → Dashboard**: <1 segundo
- **Total**: ~1-2 minutos

---

## 🚀 Optimizaciones

### Índices en Base de Datos
```sql
-- Ya creados en el schema
CREATE INDEX idx_transaction_records_created_at ON transaction_records(created_at);
CREATE INDEX idx_transaction_records_user_id ON transaction_records(user_id);
CREATE INDEX idx_transaction_records_discipline ON transaction_records(discipline);
CREATE INDEX idx_transaction_records_client_status ON transaction_records(client_status);
```

### Particionamiento (Para >1M registros)
```sql
-- Particiona por mes
CREATE TABLE transaction_records_2026_09 PARTITION OF transaction_records
FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
```

### Caché en Looker
- Habilita caché automático: Settings → Cache
- TTL recomendado: 1 hora (para datos semi-tiempo-real)

---

## ⚠️ Troubleshooting de Conexión

| Problema | Solución |
|----------|----------|
| "Connection refused" | Verifica IP whitelist en Supabase |
| "SSL certificate error" | Usa `sslmode=require` |
| "Authentication failed" | Verifica contraseña maestra |
| "Database does not exist" | Por defecto usa `postgres` |
| "Permission denied" | Usa rol `postgres` no `service_role` |

---

## 📈 Monitoreo de Conexión

**Script de health check:**

```python
import time
import requests
from datetime import datetime

def check_system_health():
    """Verifica salud del sistema cada 5 minutos"""
    
    checks = {
        "supabase_api": lambda: requests.get(
            f"{SUPABASE_URL}/rest/v1/transaction_records?limit=1",
            headers={
                "apikey": SUPABASE_ANON_KEY,
                "Authorization": f"Bearer {SUPABASE_ANON_KEY}"
            }
        ).status_code == 200,
        
        "database_table": lambda: requests.get(
            f"{SUPABASE_URL}/rest/v1/transaction_records?limit=0",
            headers={...}
        ).status_code == 200,
        
        "latest_data": lambda: (
            datetime.now() - 
            get_latest_record_time()
        ).seconds < 3600  # Menos de 1 hora
    }
    
    for check_name, check_func in checks.items():
        try:
            result = check_func()
            status = "✅" if result else "❌"
            print(f"{status} {check_name}")
        except Exception as e:
            print(f"❌ {check_name}: {e}")

while True:
    check_system_health()
    time.sleep(300)  # Cada 5 minutos
```

---

## 🎯 Resumen de Conexión Directa

```
┌─────────────────────────┐
│   NovusBet BackOffice   │
└────────────┬────────────┘
             │ (HTTP)
             ↓
┌─────────────────────────┐
│   Python Script         │
│   (main.py)             │
└────────────┬────────────┘
             │ (JSON REST API)
             ↓
┌─────────────────────────┐
│   Supabase PostgreSQL   │ ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ←
│   (transaction_records) │     Conexión Directa
└────────────┬────────────┘     Host: db.xxxxx.supabase.co
             │                  Port: 5432
             │ (PostgreSQL)      Database: postgres
             ↓                   User: postgres
┌─────────────────────────┐
│  Google Looker Studio   │
│  (Dashboard)            │
└─────────────────────────┘
```

**¡Sistema listo para producción!** 🚀

