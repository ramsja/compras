#!/usr/bin/env python3
"""
Sincronización en tiempo real de NovusBet con Supabase.
Ejecuta descargas periódicas y actualiza la BD automáticamente.
"""

from __future__ import annotations

import os
import sys
import time
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from main import (
    login,
    get_credentials,
    get_transactions_token,
    download_csv,
    save_csv,
    count_csv_rows,
    generate_reports,
    sync_to_supabase,
    get_date_range,
)
import requests


# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('sync.log'),
        logging.StreamHandler(),
    ]
)
logger = logging.getLogger(__name__)


def get_sync_interval() -> int:
    load_dotenv()
    minutes = int(os.getenv("SYNC_INTERVAL_MINUTES", "30"))
    return max(5, minutes)  # Mínimo 5 minutos


def test_supabase_connection() -> bool:
    """Verifica que la conexión a Supabase sea correcta."""
    load_dotenv()

    url = os.getenv("SUPABASE_URL", "").strip()
    service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()

    if not url or not service_key:
        logger.error("❌ Credenciales de Supabase no configuradas")
        return False

    try:
        headers = {
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
        }

        # Intenta acceder a la tabla
        response = requests.get(
            f"{url}/rest/v1/transaction_records?limit=1",
            headers=headers,
            timeout=10,
        )

        if response.status_code == 401:
            logger.error("❌ Autenticación fallida. Verifica tus credenciales de Supabase")
            return False
        elif response.status_code == 404:
            logger.warning("⚠️  Tabla no existe. Se creará automáticamente.")
            return True
        elif response.status_code == 200:
            logger.info("✓ Conexión a Supabase validada")
            return True
        else:
            logger.error(f"❌ Error HTTP {response.status_code}: {response.text[:500]}")
            return False

    except Exception as e:
        logger.error(f"❌ Error conectando a Supabase: {e}")
        return False


def sync_cycle() -> None:
    """Realiza un ciclo completo de sincronización."""
    try:
        logger.info("=" * 60)
        logger.info("🔄 Iniciando ciclo de sincronización...")
        logger.info("=" * 60)

        username, password = get_credentials()

        with requests.Session() as session:
            # Login
            logger.info("🔐 Autenticando en NovusBet...")
            initial_token = login(session, username, password)

            # Obtener token de transacciones
            logger.info("📄 Obteniendo token de transacciones...")
            transactions_token = get_transactions_token(session, initial_token)

            # Descargar CSV
            logger.info("📥 Descargando datos...")
            csv_content = download_csv(session, transactions_token)

            # Guardar CSV
            filepath = save_csv(csv_content)
            total_rows = count_csv_rows(filepath)

            logger.info(f"✓ CSV descargado: {total_rows:,} registros")
            logger.info(f"  Ubicación: {filepath}")

            # Generar reportes
            logger.info("📊 Generando reportes...")
            reports = generate_reports(filepath)
            logger.info(f"✓ {len(reports)} reportes generados")

            # Sincronizar con Supabase
            logger.info("💾 Sincronizando con Supabase...")
            endpoint = sync_to_supabase(filepath)

            if endpoint:
                logger.info(f"✓ Sincronización completada: {endpoint}")

        logger.info("✓ Ciclo de sincronización finalizado exitosamente")

    except Exception as e:
        logger.error(f"❌ Error en ciclo de sincronización: {e}")
        logger.exception(e)


def get_next_run_time(interval_minutes: int) -> datetime:
    """Calcula la próxima hora de ejecución."""
    return datetime.now() + timedelta(minutes=interval_minutes)


def main() -> None:
    """Loop principal de sincronización."""
    load_dotenv()

    logger.info("🚀 Iniciando servicio de sincronización en tiempo real")
    logger.info(f"📧 Email: moz.javier@gmail.com")

    # Validar conexión a Supabase
    if not test_supabase_connection():
        logger.warning("⚠️  Continuando sin validación de Supabase...")

    interval_minutes = get_sync_interval()
    logger.info(f"⏱️  Intervalo de sincronización: {interval_minutes} minutos")

    # Primera ejecución inmediata
    logger.info("🔄 Ejecutando sincronización inicial...")
    sync_cycle()

    next_run = get_next_run_time(interval_minutes)
    logger.info(f"⏰ Próxima ejecución: {next_run.strftime('%Y-%m-%d %H:%M:%S')}")

    # Loop de sincronización periódica
    try:
        while True:
            now = datetime.now()
            wait_seconds = (next_run - now).total_seconds()

            if wait_seconds > 0:
                logger.info(f"💤 Esperando {wait_seconds:.0f}s hasta próxima ejecución...")
                time.sleep(min(wait_seconds, 60))  # Comprueba cada minuto
            else:
                sync_cycle()
                next_run = get_next_run_time(interval_minutes)
                logger.info(f"⏰ Próxima ejecución: {next_run.strftime('%Y-%m-%d %H:%M:%S')}")

    except KeyboardInterrupt:
        logger.info("\n✓ Servicio detenido por el usuario")
        sys.exit(0)
    except Exception as e:
        logger.error(f"❌ Error fatal: {e}")
        logger.exception(e)
        sys.exit(1)


if __name__ == "__main__":
    main()
