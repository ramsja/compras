# ⚡ SETUP FINAL - Dashboard en Tiempo Real

## 🎯 Resumen de lo que has recibido

Un **sistema completo** de:
1. **Descarga automática** de datos de NovusBet
2. **Base de datos PostgreSQL** en Supabase
3. **Sincronización en tiempo real** cada 30 minutos
4. **Dashboard en Google Looker Studio**
5. **Reportes automáticos** en CSV y JSON

---

## 📋 PASO 1: Configurar Supabase (5 minutos)

### 1.1 Crear cuenta en Supabase
1. Ve a https://app.supabase.com
2. Haz clic en "New Project"
3. Elige un nombre (ej: "novusbet-dashboard")
4. Copia tu **Project URL** y **Service Role Key**

### 1.2 En tu archivo `.env`
```bash
# Edita .env con tus credenciales
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...
```

### 1.3 Inicializar la base de datos
```bash
python init_database.py
```

Esto generará un archivo `supabase_schema.sql`. 

**⚠️ IMPORTANTE**: Copia ese SQL y pégalo en:
1. Ve a tu proyecto en Supabase
2. SQL Editor → New Query
3. Pega el contenido y ejecuta

---

## 📊 PASO 2: Descargar datos iniciales (10 minutos)

```bash
# Configura .env con credenciales de NovusBet
BO_USERNAME=FinanceSV
BO_PASSWORD=Anma07covi*
START_DATE=2026-09-01
END_DATE=2026-09-07
CAUSAL_PRODUCT_ID=

# Instala dependencias
pip install -r requirements.txt

# Primera descarga
python main.py
```

✅ Deberías ver:
- ✓ Inicio de sesión correcto
- ✓ Descarga del CSV
- ✓ Sincronización con Supabase
- ✓ Reportes generados en `/reportes`

---

## 🔄 PASO 3: Configurar sincronización automática (5 minutos)

### Opción A: En tu máquina (para desarrollo)

```bash
# Ejecuta el servicio de sincronización
python sync_realtime.py

# Abre otra terminal y verifica el log
tail -f sync.log
```

### Opción B: Con Cron (Linux/Mac - Producción)

```bash
# Edita crontab
crontab -e

# Agrega esta línea (se ejecuta cada 30 minutos)
*/30 * * * * cd /home/user/compras && python sync_realtime.py >> sync.log 2>&1
```

### Opción C: Con GitHub Actions (Recomendado para CI/CD)

Crea `.github/workflows/sync-novusbet.yml`:

```yaml
name: Sincronizar NovusBet

on:
  schedule:
    - cron: '*/30 * * * *'  # Cada 30 minutos

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - env:
          BO_USERNAME: ${{ secrets.BO_USERNAME }}
          BO_PASSWORD: ${{ secrets.BO_PASSWORD }}
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
        run: python sync_realtime.py
```

---

## 📈 PASO 4: Conectar Google Looker Studio (10 minutos)

### 4.1 Obtén credenciales de Supabase
1. En tu proyecto Supabase → Settings → API
2. Copia **Project URL** y **Public API Key (ANON_KEY)**

### 4.2 En Looker Studio
1. Ve a https://datastudio.google.com
2. Create → Data Source
3. Selecciona "PostgreSQL"

**Configura la conexión:**
- Host: `db.xxxxx.supabase.co`
- Port: `5432`
- Database: `postgres`
- Username: `postgres`
- Password: (tu contraseña maestra de Supabase)

### 4.3 Crea tu primer dashboard

**KPIs principales:**
```
- Total de transacciones
- Monto total
- Ingresos totales
- Usuarios activos hoy
```

**Gráficos:**
- Pie chart: Por disciplina
- Bar chart: Estado de clientes
- Line chart: Tendencia diaria
- Table: Top 10 usuarios

**Filtros:**
- Rango de fechas
- Disciplina
- Estado del cliente

📖 Ver detalles completos en [GOOGLE_LOOKER_SETUP.md](./GOOGLE_LOOKER_SETUP.md)

---

## ✅ VERIFICACIÓN

### Checklist de implementación

- [ ] Cuenta Supabase creada
- [ ] `.env` configurado con credenciales
- [ ] `init_database.py` ejecutado
- [ ] SQL ejecutado en Supabase
- [ ] `python main.py` ejecutó correctamente
- [ ] Datos aparecen en Supabase (verifica tabla)
- [ ] `sync_realtime.py` ejecutándose
- [ ] Google Looker conectado
- [ ] Dashboard creado en Looker

### Verifica que todo funciona

```bash
# 1. Chequea la conexión a Supabase
python -c "
import requests
from dotenv import load_dotenv
import os

load_dotenv()
url = os.getenv('SUPABASE_URL')
key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

headers = {
    'apikey': key,
    'Authorization': f'Bearer {key}',
}

response = requests.get(f'{url}/rest/v1/transaction_records?limit=1', headers=headers)
print(f'Status: {response.status_code}')
print(f'Registros: {len(response.json())}')
"

# 2. Cuenta de registros en Supabase
# Ejecuta en SQL Editor de Supabase:
# SELECT COUNT(*) FROM transaction_records;
```

---

## 📚 Documentación Completa

| Archivo | Descripción |
|---------|-------------|
| `README.md` | Guía general del proyecto |
| `GOOGLE_LOOKER_SETUP.md` | Setup de Looker Studio |
| `main.py` | Script de descarga |
| `sync_realtime.py` | Sincronización automática |
| `init_database.py` | Inicializador de BD |

---

## 🆘 Troubleshooting Rápido

### "ImportError: No module named 'requests'"
```bash
pip install -r requirements.txt
```

### "Error de autenticación NovusBet"
- Verifica credenciales en `.env`
- Asegúrate de que `BO_USERNAME` y `BO_PASSWORD` son correctos
- Prueba login manual en headoffice.novusbet.com

### "Connection refused" a Supabase
- Verifica que `SUPABASE_URL` sea correcto (sin trailing slash)
- Verifica que `SUPABASE_SERVICE_ROLE_KEY` sea válido
- En Supabase Settings → API, copia nuevas credenciales

### Datos no aparecen en Looker
- Espera a que se ejecute la primera sincronización (30 min)
- Fuerza descarga manual: `python main.py`
- En Looker Studio, refresca: Ctrl+R

### "Table does not exist"
- Ejecuta `python init_database.py`
- Copia el SQL a Supabase SQL Editor
- Espera 30 segundos y actualiza

---

## 🚀 Próximos Pasos

### Mejoras opcionales

1. **Alertas en tiempo real**
   - Configura notificaciones por email en Supabase
   - Agregaciones automáticas

2. **Machine Learning**
   - Predicción de comportamiento de clientes
   - Segmentación con redes neuronales

3. **Webhooks**
   - Integración con Slack
   - Notificaciones personalizadas

4. **Data Warehouse**
   - Exportar a BigQuery
   - Análisis con BI tools avanzadas

---

## 📞 Soporte Rápido

- **Email**: moz.javier@gmail.com
- **GitHub**: ramsja/compras
- **Rama**: `claude/dashboard-reportes-tiempo-real-elogsq`

---

## ⏱️ Timeline Esperado

| Tarea | Tiempo |
|-------|--------|
| Setup Supabase | 5 min |
| Configurar .env | 2 min |
| Descarga inicial | 10 min |
| Setup Looker | 10 min |
| Crear dashboard | 10 min |
| **Total** | **~40 min** |

---

## 🎯 Resultado Final

```
NovusBet Data
    ↓ (Python script)
    ↓ (Descarga automática cada 30 min)
Supabase PostgreSQL
    ↓ (API REST)
    ↓ (Datos en tiempo real)
Google Looker Studio
    ↓
📊 Dashboard interactivo visible
```

---

**¡Listo! Tu sistema está operacional.** 🎉

Próximo paso: Ejecuta `python main.py` para descargar la primera tanda de datos.

