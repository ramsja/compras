# 📊 Dashboard de Reportes en Tiempo Real - NovusBet

Sistema de descarga, procesamiento y sincronización en tiempo real de datos de transacciones desde NovusBet hacia Supabase (PostgreSQL) y Google Looker Studio.

## ✨ Características

- ✅ **Descarga automática** de transacciones desde NovusBet
- ✅ **Sincronización en tiempo real** con Supabase (PostgreSQL)
- ✅ **Clasificación automática** por disciplina (casino, deportes, otros)
- ✅ **Segmentación de clientes** por estado (activo, inactivo, etc.)
- ✅ **Generación de reportes** en CSV y JSON
- ✅ **Conexión a Google Looker Studio** para visualizaciones
- ✅ **API REST** integrada (Supabase PostgREST)
- ✅ **Índices optimizados** para consultas rápidas

## 🚀 Inicio Rápido

### 1. Clonar el repositorio
```bash
git clone https://github.com/ramsja/compras.git
cd compras
```

### 2. Configurar variables de entorno
```bash
cp .env.example .env
```

Edita `.env` con tus credenciales:
```env
# NovusBet BackOffice
BO_USERNAME=FinanceSV
BO_PASSWORD=Anma07covi*
START_DATE=2026-09-01
END_DATE=2026-09-07
CAUSAL_PRODUCT_ID=xxxxx

# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=xxxxx
SUPABASE_TABLE=transaction_records

# Sincronización
SYNC_INTERVAL_MINUTES=30
```

### 3. Instalar dependencias
```bash
pip install -r requirements.txt
```

### 4. Inicializar base de datos
```bash
python init_database.py
```

Esto generará un archivo `supabase_schema.sql` que debes ejecutar en tu dashboard de Supabase.

### 5. Primera descarga
```bash
python main.py
```

### 6. Sincronización continua
```bash
python sync_realtime.py
```

## 📁 Estructura del Proyecto

```
compras/
├── main.py                      # Script principal de descarga
├── sync_realtime.py             # Sincronización periódica automática
├── init_database.py             # Inicializador de BD
├── .env.example                 # Template de variables
├── .env                         # Credenciales (no commitar)
├── requirements.txt             # Dependencias Python
├── descargas/                   # CSVs descargados
│   └── transacciones_*.csv
├── reportes/                    # Reportes generados
│   ├── transacciones-casino.csv
│   ├── transacciones-deportes.csv
│   ├── transacciones-otros.csv
│   ├── clientes-activos.csv
│   ├── clientes-inactivos.csv
│   ├── clientes-resumen.json
│   ├── resumen-campos.json
│   └── supabase-schema.sql
├── sync.log                     # Log de sincronización
└── README.md                    # Este archivo
```

## 🔄 Flujo de Datos

```
NovusBet BackOffice
        ↓
    (Login & Download)
        ↓
    CSV Local
        ↓
   (Procesamiento)
        ↓
    ┌───────────────────────┐
    │  Reportes en CSV/JSON │
    └───────────────────────┘
        ↓
    Supabase (PostgreSQL)
        ↓
    ┌───────────────────────┐
    │  Google Looker Studio │
    │  (Visualizaciones)    │
    └───────────────────────┘
```

## 📊 Base de Datos

### Tabla Principal: `transaction_records`

| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | bigint | ID único generado automáticamente |
| source_transaction_id | text | ID de la transacción original |
| created_at | timestamptz | Fecha y hora de la transacción |
| user_id | text | ID del usuario |
| username | text | Nombre de usuario |
| total | numeric | Monto total |
| income | numeric | Ingresos |
| discipline | text | Clasificación (casino, deportes, otros) |
| client_status | text | Estado del cliente (activo, inactivo, etc.) |
| raw | jsonb | Datos originales en JSON |
| imported_at | timestamptz | Fecha de importación a la BD |

### Vistas (Views)

- **v_discipline_summary**: Resumen por disciplina
- **v_client_summary**: Resumen por cliente
- **v_daily_trends**: Tendencias diarias
- **v_active_today**: Clientes activos hoy

## 🔐 Seguridad

⚠️ **Importantes consideraciones**:

1. **Nunca commites el archivo `.env`** con credenciales
2. Usa **Service Role Key** para sincronización automática (scripts Python)
3. Usa **Anon Key** solo en frontend/Looker Studio
4. Configura **Row Level Security (RLS)** en Supabase si es necesario
5. Mantén las credenciales en secretos del CI/CD (GitHub Actions, etc.)

## 📈 Integraciones

### Google Looker Studio

Para conectar con Looker Studio, sigue [GOOGLE_LOOKER_SETUP.md](./GOOGLE_LOOKER_SETUP.md)

Dashboards disponibles:
- 📊 KPIs principales
- 📈 Tendencias por disciplina
- 👥 Análisis de clientes
- 💰 Ingresos vs gastos
- 📍 Distribución geográfica

### BigQuery (Opcional)

Para análisis avanzado con BigQuery:
```python
from google.cloud import bigquery

client = bigquery.Client()
# ... código para sincronizar con BigQuery
```

## 🔧 Configuración Avanzada

### Variables de Entorno

```env
# Descarga
START_DATE=2026-09-01              # Fecha inicio (YYYY-MM-DD)
END_DATE=2026-09-07                # Fecha fin (YYYY-MM-DD)
CAUSAL_PRODUCT_ID=                 # ID del producto (dejar en blanco para todos)

# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=xxxxx    # Para scripts Python
SUPABASE_ANON_KEY=xxxxx            # Para frontend
SUPABASE_TABLE=transaction_records

# Sincronización
SYNC_INTERVAL_MINUTES=30           # Intervalo entre sincronizaciones
DEBUG=false                        # Modo debug
```

### Ejecutar con Cron (Linux/Mac)

```bash
# Cada 30 minutos
*/30 * * * * cd /home/user/compras && python sync_realtime.py >> sync.log 2>&1

# Diariamente a las 6 AM
0 6 * * * cd /home/user/compras && python main.py >> main.log 2>&1
```

### Docker (Opcional)

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["python", "sync_realtime.py"]
```

```bash
docker build -t novusbet-sync .
docker run -d --env-file .env novusbet-sync
```

## 📋 Scripts Disponibles

| Script | Función |
|--------|---------|
| `main.py` | Descarga única de transacciones |
| `sync_realtime.py` | Sincronización periódica automática |
| `init_database.py` | Inicializa esquema en Supabase |

## 🐛 Troubleshooting

### Error: "No se pudo conectar a Supabase"
```bash
# Verifica credenciales en .env
python -c "from dotenv import load_dotenv; load_dotenv(); import os; print(os.getenv('SUPABASE_URL'))"
```

### Error: "Tabla no existe"
```bash
# Ejecuta el inicializador
python init_database.py
# Luego copia el SQL a tu dashboard Supabase
```

### Datos no se actualizan en Looker
- Verifica que `sync_realtime.py` esté ejecutándose
- Fuerza actualización manual en Looker Studio
- Revisa el log: `tail -f sync.log`

### Error de autenticación NovusBet
- Verifica credenciales en `.env`
- Comprueba que tu IP no esté bloqueada
- Revisa si la sesión ha expirado

## 📞 Soporte

- 📧 Email: moz.javier@gmail.com
- 🐙 GitHub Issues: Reporta bugs o solicita features
- 📚 Documentación: Ver archivos `.md` en el repositorio

## 📄 Licencia

Propietario - Todos los derechos reservados

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:
1. Fork el repositorio
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

---

**Última actualización**: 2026-09-07
**Rama**: `claude/dashboard-reportes-tiempo-real-elogsq`
