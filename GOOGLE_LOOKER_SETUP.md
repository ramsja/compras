# 🎯 Guía: Conectar Google Looker Studio con Supabase

## 1. Preparativos en Supabase

### 1.1 Obtener credenciales de conexión

1. Ve a tu proyecto en [Supabase](https://app.supabase.com)
2. En el sidebar, selecciona **"Settings"** (Configuración)
3. Ve a **"Database"** (Base de datos)
4. Copia estos datos:
   - **Host**: `db.xxxxx.supabase.co`
   - **Port**: `5432`
   - **Database**: `postgres`
   - **User**: `postgres`
   - **Password**: (tu contraseña maestra)

### 1.2 Habilitar acceso público a la API REST

1. En Supabase, ve a **"Settings"** → **"API"**
2. Copia tu **Project URL** (ej: `https://xxxxx.supabase.co`)
3. Copia tu **Public API Key** (ANON_KEY)

## 2. Opción A: Conectar mediante Supabase API (Recomendado)

### 2.1 En Google Looker Studio

1. Ve a [Looker Studio](https://datastudio.google.com)
2. Crea un nuevo **Data Source** (Fuente de Datos)
3. Selecciona **"PostgreSQL"** o **"BigQuery"** (si usas BigQuery)

### 2.2 Si usas PostgreSQL directamente

**⚠️ Nota**: Supabase usa PostgreSQL, pero Looker Studio requiere un conector especial.

#### Opción 2.2.1: Usar Google Sheets como intermediario

1. **En Google Sheets**:
   ```
   =IMPORTDATA("https://xxxxx.supabase.co/rest/v1/transaction_records?limit=1000", {"apikey": "xxxxx"})
   ```

2. **O usar Apps Script**:
   ```javascript
   function fetchFromSupabase() {
     const url = "https://xxxxx.supabase.co/rest/v1/transaction_records";
     const apiKey = "YOUR_ANON_KEY";
     
     const options = {
       method: "GET",
       headers: {
         "apikey": apiKey,
         "Authorization": "Bearer " + apiKey
       }
     };
     
     const response = UrlFetchApp.fetch(url, options);
     const data = JSON.parse(response.getContentText());
     
     // Coloca los datos en la hoja
     const sheet = SpreadsheetApp.getActiveSheet();
     // ... código para insertar datos ...
   }
   ```

3. **Luego en Looker Studio**:
   - Crea una fuente de datos conectada a esa Google Sheet
   - Looker Studio reconocerá automáticamente las columnas

#### Opción 2.2.2: Usar BigQuery como intermediario

Este es el **método más recomendado** para datos en tiempo real.

1. **Configura BigQuery**:
   ```bash
   # Instala Google Cloud CLI
   gcloud init
   gcloud auth login
   
   # Crea un dataset
   bq mk --dataset my_novusbet
   ```

2. **En tu script Python, sincroniza con BigQuery**:
   ```python
   from google.cloud import bigquery
   
   def sync_to_bigquery(dataframe):
       client = bigquery.Client()
       table_id = "my-project.my_novusbet.transaction_records"
       
       job = client.load_table_from_dataframe(
           dataframe,
           table_id,
           job_config=bigquery.LoadJobConfig(
               write_disposition="WRITE_APPEND",
           ),
       )
       job.result()
   ```

3. **Conecta a Looker Studio**:
   - Ve a Looker Studio
   - Selecciona "BigQuery" como fuente de datos
   - Selecciona tu tabla
   - Crea visualizaciones

## 3. Opción B: Crear un Conector Personalizado

Si necesitas una conexión más directa a Supabase:

### 3.1 Script de Google Apps Script

En tu proyecto de Google Cloud, crea un conector:

```javascript
// ConectorSupabase.gs

const SUPABASE_URL = "https://xxxxx.supabase.co";
const SUPABASE_KEY = "your_anon_key_here";

function getAuthType() {
  return cc.AuthType.NONE;
}

function getConfig() {
  const config = cc.getConfig();
  
  config.newInfo()
    .setId("instructions")
    .setText("Conector para Supabase - Transacciones NovusBet");
  
  return config.build();
}

function getSchema() {
  return {
    schema: [
      {
        name: "id",
        label: "ID",
        dataType: "STRING",
        semanticType: "DIMENSION"
      },
      {
        name: "user_id",
        label: "User ID",
        dataType: "STRING",
        semanticType: "DIMENSION"
      },
      {
        name: "username",
        label: "Username",
        dataType: "STRING",
        semanticType: "DIMENSION"
      },
      {
        name: "total",
        label: "Total",
        dataType: "NUMBER",
        semanticType: "METRIC"
      },
      {
        name: "income",
        label: "Income",
        dataType: "NUMBER",
        semanticType: "METRIC"
      },
      {
        name: "discipline",
        label: "Discipline",
        dataType: "STRING",
        semanticType: "DIMENSION"
      },
      {
        name: "client_status",
        label: "Client Status",
        dataType: "STRING",
        semanticType: "DIMENSION"
      },
      {
        name: "created_at",
        label: "Created At",
        dataType: "STRING",
        semanticType: "DIMENSION"
      }
    ]
  };
}

function getData(request) {
  const url = SUPABASE_URL + "/rest/v1/transaction_records?limit=1000";
  
  const options = {
    method: "GET",
    headers: {
      "apikey": SUPABASE_KEY,
      "Authorization": "Bearer " + SUPABASE_KEY
    },
    muteHttpExceptions: true
  };
  
  const response = UrlFetchApp.fetch(url, options);
  const data = JSON.parse(response.getContentText());
  
  const rows = [];
  data.forEach(record => {
    rows.push([
      record.id,
      record.user_id,
      record.username,
      record.total,
      record.income,
      record.discipline,
      record.client_status,
      record.created_at
    ]);
  });
  
  return {
    rows: rows,
    filtersApplied: [],
    rowCount: rows.length
  };
}
```

## 4. Dashboards Recomendados en Looker Studio

Una vez conectado, crea estas visualizaciones:

### 4.1 KPIs Principales
- **Total de Transacciones**: `COUNT(*)`
- **Monto Total**: `SUM(total)`
- **Ingresos Totales**: `SUM(income)`
- **Usuarios Activos**: `COUNT(DISTINCT user_id)`

### 4.2 Gráficos
- **Por Disciplina**: Gráfico de pastel con `discipline`
- **Por Estado de Cliente**: Gráfico de barras con `client_status`
- **Tendencia Diaria**: Gráfico de líneas con `created_at` y `SUM(total)`
- **Top Usuarios**: Tabla ordenada por `SUM(income)`

### 4.3 Filtros
- Rango de fechas (`created_at`)
- Disciplina (casino, deportes, otros)
- Estado del cliente (activo, inactivo, etc.)

## 5. Mantener Datos Actualizados

### 5.1 Actualización Manual
En Looker Studio, los datos se actualizan automáticamente cada 24 horas.

### 5.2 Actualización en Tiempo Real
Configura tu `sync_realtime.py` para ejecutarse cada 30 minutos:

```bash
# En Linux/Mac con cron
*/30 * * * * cd /home/user/compras && python sync_realtime.py >> sync.log 2>&1
```

### 5.3 Webhook para actualizaciones inmediatas
Configura un webhook en tu infraestructura para que Supabase notifique a Looker cuando haya nuevos datos.

## 6. Troubleshooting

| Problema | Solución |
|----------|----------|
| "No puedo conectar a Supabase" | Verifica tu URL y API Key en el archivo `.env` |
| "Permiso denegado" | Usa tu **Service Role Key** (no la anon key) en scripts |
| "Datos no se actualizan" | Configura la frecuencia de actualización en Looker Studio settings |
| "La tabla está vacía" | Ejecuta primero `python main.py` para descargar datos |

## 7. URLs Útiles

- 📊 [Looker Studio](https://datastudio.google.com)
- 🗄️ [Supabase Dashboard](https://app.supabase.com)
- ☁️ [Google Cloud Console](https://console.cloud.google.com)
- 📚 [Documentación Supabase API](https://supabase.com/docs/reference/api)
- 📖 [Documentación Looker Studio](https://support.google.com/looker-studio)

## 8. Ejemplo de SQL para Supabase

Estos son algunos queries útiles que puedes usar en Looker:

```sql
-- Total por disciplina
SELECT discipline, COUNT(*) as records, SUM(total) as amount
FROM transaction_records
GROUP BY discipline;

-- Clientes activos en los últimos 7 días
SELECT DISTINCT username, client_status
FROM transaction_records
WHERE created_at > NOW() - INTERVAL '7 days'
  AND client_status = 'activo';

-- Ingresos por día
SELECT DATE(created_at) as day, SUM(income) as daily_income
FROM transaction_records
GROUP BY DATE(created_at)
ORDER BY day DESC;
```

---

¿Necesitas ayuda? Contacta a **moz.javier@gmail.com**
