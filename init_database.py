#!/usr/bin/env python3
"""
Inicializa la base de datos en Supabase.
Crea las tablas, índices y vistas necesarias.
"""

from __future__ import annotations

import os
import sys
import logging

import requests
from dotenv import load_dotenv


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


SCHEMA_SQL = """
-- Tabla principal de transacciones
create table if not exists transaction_records (
  id bigint generated always as identity primary key,
  source_transaction_id text,
  created_at timestamptz,
  site text,
  parent_id text,
  user_id text,
  username text,
  user_type text,
  currency text,
  income numeric,
  status numeric,
  total numeric,
  commission numeric,
  balance numeric,
  current_balance numeric,
  wallet text,
  transaction_type text,
  causal_group text,
  causal text,
  causal_product text,
  description text,
  note text,
  ip_address inet,
  discipline text not null default 'otros',
  client_status text not null default 'otros',
  source_file text,
  raw jsonb not null,
  imported_at timestamptz default now()
);

-- Índices para optimización
create index if not exists idx_transaction_records_created_at on transaction_records(created_at);
create index if not exists idx_transaction_records_discipline on transaction_records(discipline);
create index if not exists idx_transaction_records_user_id on transaction_records(user_id);
create index if not exists idx_transaction_records_client_status on transaction_records(client_status);
create index if not exists idx_transaction_records_imported_at on transaction_records(imported_at);
create index if not exists idx_transaction_records_username on transaction_records(username);

-- Tabla de estadísticas en tiempo real
create table if not exists transaction_summary (
  id bigint generated always as identity primary key,
  report_date date not null unique,
  total_records bigint,
  total_amount numeric,
  total_income numeric,
  active_users bigint,
  disciplines_count jsonb,
  client_statuses_count jsonb,
  updated_at timestamptz default now()
);

-- Vista de resumen por disciplina
create or replace view v_discipline_summary as
select
  discipline,
  client_status,
  count(*) as records,
  count(distinct user_id) as unique_users,
  sum(total) as total_amount,
  sum(income) as total_income,
  min(created_at) as first_transaction,
  max(created_at) as last_transaction
from transaction_records
group by discipline, client_status;

-- Vista de resumen por cliente
create or replace view v_client_summary as
select
  user_id,
  username,
  client_status,
  count(*) as transaction_count,
  sum(total) as total_amount,
  sum(income) as total_income,
  min(created_at) as first_transaction,
  max(created_at) as last_transaction,
  count(distinct discipline) as disciplines_count
from transaction_records
where user_id is not null
group by user_id, username, client_status;

-- Vista de tendencias diarias
create or replace view v_daily_trends as
select
  date_trunc('day', created_at) as transaction_date,
  discipline,
  count(*) as records,
  sum(total) as total_amount,
  sum(income) as total_income,
  count(distinct user_id) as unique_users
from transaction_records
group by date_trunc('day', created_at), discipline;

-- Vista de clientes activos hoy
create or replace view v_active_today as
select
  user_id,
  username,
  discipline,
  count(*) as transactions_today,
  sum(total) as amount_today,
  max(created_at) as last_activity
from transaction_records
where date_trunc('day', created_at) = current_date
  and client_status = 'activo'
group by user_id, username, discipline;
"""


def get_supabase_config() -> tuple[str, str]:
    """Obtiene configuración de Supabase desde variables de entorno."""
    load_dotenv()

    url = os.getenv("SUPABASE_URL", "").strip()
    service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()

    if not url or not service_key:
        raise RuntimeError(
            "❌ SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY no están configuradas. "
            "Configúralas en tu archivo .env"
        )

    return url, service_key


def execute_sql(
    url: str,
    service_key: str,
    sql: str,
) -> bool:
    """Ejecuta SQL en Supabase."""
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
    }

    payload = {
        "query": sql,
    }

    try:
        response = requests.post(
            f"{url}/rest/v1/rpc/exec_sql",
            headers=headers,
            json=payload,
            timeout=30,
        )

        if response.status_code in (200, 201):
            logger.info("✓ SQL ejecutado exitosamente")
            return True

        # Intenta con endpoint alternativo
        logger.info("⚠️  Intentando con método alternativo...")
        response = requests.post(
            f"{url}/rest/v1/",
            headers=headers,
            json={"query": sql},
            timeout=30,
        )

        if response.status_code in (200, 201):
            logger.info("✓ SQL ejecutado con método alternativo")
            return True

        logger.error(f"❌ Error HTTP {response.status_code}: {response.text[:500]}")
        return False

    except Exception as e:
        logger.error(f"❌ Error ejecutando SQL: {e}")
        return False


def test_connection(url: str, service_key: str) -> bool:
    """Prueba la conexión a Supabase."""
    logger.info("🔌 Probando conexión a Supabase...")

    try:
        headers = {
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
        }

        response = requests.get(
            f"{url}/rest/v1/",
            headers=headers,
            timeout=10,
        )

        if response.status_code in (200, 204):
            logger.info("✓ Conexión a Supabase exitosa")
            return True

        if response.status_code == 401:
            logger.error("❌ Autenticación fallida. Verifica tu service role key.")
            return False

        logger.error(f"❌ Error HTTP {response.status_code}")
        return False

    except Exception as e:
        logger.error(f"❌ No se pudo conectar: {e}")
        return False


def create_table_via_postgrest(
    url: str,
    service_key: str,
) -> bool:
    """
    Intenta crear la tabla usando el SDK de Supabase.
    """
    logger.info("📋 Creando esquema de base de datos...")
    logger.info("   (Nota: Esto requiere ejecutar el SQL directamente en el Editor SQL de Supabase)")

    # Escribe el SQL en un archivo para que el usuario lo copie
    sql_file = "supabase_schema.sql"
    with open(sql_file, "w") as f:
        f.write(SCHEMA_SQL)

    logger.info(f"✓ Schema guardado en: {sql_file}")
    logger.info("")
    logger.info("=" * 70)
    logger.info("📝 PRÓXIMOS PASOS:")
    logger.info("=" * 70)
    logger.info("")
    logger.info("1. Ve a tu dashboard de Supabase:")
    logger.info("   https://app.supabase.com/project/_/sql/new")
    logger.info("")
    logger.info("2. Copia el contenido del archivo 'supabase_schema.sql'")
    logger.info("")
    logger.info("3. Pégalo en el Editor SQL y ejecuta")
    logger.info("")
    logger.info("4. Espera a que se completen las operaciones")
    logger.info("")
    logger.info("Alternativamente, puedes ejecutar este archivo desde la terminal:")
    logger.info(f"   psql -h db.xxxx.supabase.co -U postgres -d postgres < {sql_file}")
    logger.info("")
    logger.info("=" * 70)

    return True


def verify_tables(url: str, service_key: str) -> bool:
    """Verifica que las tablas se hayan creado."""
    logger.info("🔍 Verificando tablas...")

    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
    }

    try:
        response = requests.get(
            f"{url}/rest/v1/transaction_records?limit=0",
            headers=headers,
            timeout=10,
        )

        if response.status_code == 200:
            logger.info("✓ Tabla 'transaction_records' existe y es accesible")
            return True

        if response.status_code == 404:
            logger.warning("⚠️  Tabla aún no existe. Asegúrate de ejecutar el SQL en Supabase.")
            return False

        logger.error(f"❌ Error verificando tabla: HTTP {response.status_code}")
        return False

    except Exception as e:
        logger.error(f"❌ Error verificando tablas: {e}")
        return False


def main() -> None:
    """Ejecuta la inicialización de la base de datos."""
    logger.info("🚀 Inicializando base de datos en Supabase...")
    logger.info("")

    try:
        # Obtener configuración
        url, service_key = get_supabase_config()
        logger.info(f"📍 URL: {url}")

        # Probar conexión
        if not test_connection(url, service_key):
            logger.error("❌ No se pudo conectar a Supabase")
            sys.exit(1)

        # Crear esquema
        if not create_table_via_postgrest(url, service_key):
            logger.error("❌ No se pudo crear el esquema")
            sys.exit(1)

        # Verificar (esto fallará hasta que ejecutes el SQL)
        verify_tables(url, service_key)

        logger.info("")
        logger.info("✓ Inicialización completada")
        logger.info("")
        logger.info("📌 Próximos pasos:")
        logger.info("   1. Ejecuta el SQL en el Editor SQL de Supabase")
        logger.info("   2. Configura tu archivo .env con las credenciales")
        logger.info("   3. Ejecuta: python main.py   (descarga una vez)")
        logger.info("   4. Ejecuta: python sync_realtime.py  (sincronización periódica)")

    except Exception as e:
        logger.error(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
