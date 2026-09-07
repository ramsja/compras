# 🚀 FASE 1: IMPLEMENTACIÓN - Paso a Paso

**Estado Actual**: 2/14 tareas completadas (14%)  
**Objetivo Fase 1**: Tener Supabase listo + primera sincronización  
**Duración Estimada**: 2-3 horas  
**Fecha Inicio**: 2026-09-07

---

## 📋 CHECKLIST FASE 1

### ✅ PASO 1: Crear Cuenta Supabase (5 minutos)

- [ ] Ve a https://app.supabase.com
- [ ] Clic en "New Project"
- [ ] Ingresa nombre del proyecto: `novusbet-dashboard`
- [ ] **Copia y guarda:**
  - Project URL: `https://xxxxx.supabase.co`
  - Service Role Key: `eyJhbGc...` (será muy largo)
  - Anon Key: `eyJhbGc...`

**Nota**: Estos datos son PRIVADOS. Guárdalos en un lugar seguro.

---

### ✅ PASO 2: Configurar Archivo .env (5 minutos)

```bash
# Desde la terminal en /home/user/compras/

# 1. Copia el template
cp .env.example .env

# 2. Abre con tu editor (nano, vim, vscode, etc)
nano .env

# 3. Reemplaza estos valores CON LOS TUYOS:

# Línea 16 - Tu URL de Supabase
SUPABASE_URL=https://xxxxx.supabase.co

# Línea 17 - Tu Service Role Key
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...

# Línea 18 - Tu Anon Key (para Looker después)
SUPABASE_ANON_KEY=eyJhbGc...

# 4. Guarda el archivo
```

**Verificación:**
```bash
# Verifica que .env está configurado
cat .env | grep SUPABASE
```

---

### ✅ PASO 3: Instalar Dependencias Python (2 minutos)

```bash
# Navega al directorio
cd /home/user/compras

# Instala requirements
pip install -r requirements.txt

# Verifica
python -c "import requests; import bs4; print('✅ Dependencias OK')"
```

---

### ✅ PASO 4: Ejecutar init_database.py (2 minutos)

Este script genera el schema SQL para Supabase.

```bash
# Ejecuta
python init_database.py

# Verifica que se creó el archivo
ls -la supabase_schema.sql
```

**Resultado esperado:**
```
✅ Archivo supabase_schema.sql generado
  - 8 tablas creadas
  - 4 vistas analíticas
  - Índices de performance
  - 2,456 líneas de SQL
```

---

### ✅ PASO 5: Crear Schema en Supabase (5 minutos)

**En Supabase Console:**

1. Abre https://app.supabase.com → Tu proyecto
2. Ve a **SQL Editor** → New Query
3. Abre el archivo `supabase_schema.sql` (copiar contenido)
4. Pega TODO el contenido en el SQL Editor
5. Click "Run" (botón verde)
6. Espera a que se ejecute ✅

**Verificación en Supabase:**
- Tabla `transaction_records` debe aparecer en Tables
- 4 Vistas en el panel de Views
- Índices creados correctamente

---

### ✅ PASO 6: Validar Conexión (5 minutos)

```bash
# Ejecuta desde terminal
python -c "
import os
from dotenv import load_dotenv
import requests

load_dotenv()
url = os.getenv('SUPABASE_URL')
key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

headers = {
    'apikey': key,
    'Authorization': f'Bearer {key}',
}

response = requests.get(
    f'{url}/rest/v1/transaction_records?limit=1',
    headers=headers
)

if response.status_code == 200:
    print('✅ Conexión exitosa a Supabase')
    print(f'   URL: {url}')
    print(f'   Status: {response.status_code}')
else:
    print(f'❌ Error: {response.status_code}')
    print(response.text)
"
```

**Resultado esperado:**
```
✅ Conexión exitosa a Supabase
   URL: https://xxxxx.supabase.co
   Status: 200
```

---

### ✅ PASO 7: Primera Descarga de Datos (10 minutos)

```bash
# Ejecuta el script principal
python main.py

# Verifica en terminal:
# - Inicio de sesión ✓
# - Descarga CSV ✓
# - Procesamiento ✓
# - Sincronización ✓
# - Reportes generados ✓
```

**Archivos generados:**
```
/reportes/
├── transacciones_2026-09-07.csv
├── transacciones_2026-09-07.json
├── resumen_diario.csv
├── resumen_por_disciplina.csv
└── resumen_por_cliente.csv
```

**En Supabase - Verifica datos:**
1. Ve a SQL Editor
2. Ejecuta:
```sql
SELECT COUNT(*) as total FROM transaction_records;
SELECT DATE(created_at), COUNT(*) FROM transaction_records 
GROUP BY DATE(created_at) ORDER BY DATE DESC LIMIT 5;
```

---

### ✅ PASO 8: Configurar Sincronización Automática (5 minutos)

**Opción A: Cron Job (Linux/Mac)**

```bash
# Edita crontab
crontab -e

# Agrega esta línea (se ejecuta cada 30 minutos)
*/30 * * * * cd /home/user/compras && python sync_realtime.py >> /home/user/compras/sync.log 2>&1

# Guarda y verifica
crontab -l | grep sync_realtime
```

**Opción B: GitHub Actions (Recomendado)**

1. Ve al repositorio GitHub
2. Crea `.github/workflows/sync-novusbet.yml`
3. Copia el contenido:

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

4. Configura Secrets en GitHub:
   - Settings → Secrets and variables → Actions
   - Agrega: `BO_USERNAME`, `BO_PASSWORD`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`

---

## ✅ VALIDACIÓN FINAL FASE 1

Ejecuta esta validación completa:

```bash
#!/bin/bash
echo "🔍 VALIDACIÓN FASE 1"
echo "===================="

# 1. Verifica .env
echo -n "1. .env configurado? "
if grep -q "supabase.co" .env; then echo "✅"; else echo "❌"; fi

# 2. Verifica dependencias
echo -n "2. Python dependencies? "
if python -c "import requests, bs4" 2>/dev/null; then echo "✅"; else echo "❌"; fi

# 3. Verifica schema SQL
echo -n "3. supabase_schema.sql? "
if [ -f supabase_schema.sql ]; then echo "✅ ($(wc -l < supabase_schema.sql) líneas)"; else echo "❌"; fi

# 4. Verifica conexión Supabase
echo -n "4. Conexión Supabase? "
curl -s -X GET \
  "$(grep SUPABASE_URL .env | cut -d= -f2)/rest/v1/transaction_records?limit=1" \
  -H "apikey: $(grep SUPABASE_SERVICE_ROLE_KEY .env | cut -d= -f2)" \
  -H "Authorization: Bearer $(grep SUPABASE_SERVICE_ROLE_KEY .env | cut -d= -f2)" \
  | grep -q "id" && echo "✅" || echo "❌"

# 5. Verifica reportes
echo -n "5. Reportes generados? "
if [ -d reportes ] && [ $(ls reportes | wc -l) -gt 0 ]; then 
  echo "✅ ($(ls reportes | wc -l) archivos)"
else 
  echo "❌"
fi

# 6. Verifica cron (si aplica)
echo -n "6. Cron sincronización? "
crontab -l 2>/dev/null | grep -q sync_realtime && echo "✅" || echo "⏳ Pendiente"

echo "===================="
echo "Estado: Listo para Fase 2"
```

---

## 🎯 PRÓXIMOS PASOS (Después de Fase 1)

### Fase 2: Google Looker Studio (1-2 horas)
- Conectar PostgreSQL directo a Looker
- Crear dashboards KPI, Tendencias, Clientes
- Configurar filtros interactivos

### Fase 3: Producción (1 hora)
- Configurar backups automáticos en Supabase
- Habilitar Row Level Security (RLS)
- Configurar alertas de cuota

---

## 📞 TROUBLESHOOTING FASE 1

| Problema | Solución |
|----------|----------|
| `ModuleNotFoundError` | `pip install -r requirements.txt` |
| `Connection refused` a Supabase | Verifica SUPABASE_URL en .env (sin trailing slash) |
| `Authentication failed` | Verifica SUPABASE_SERVICE_ROLE_KEY es válido |
| `Table does not exist` | Ejecuta el SQL en Supabase SQL Editor |
| `CSV no descarga` | Verifica BO_USERNAME y BO_PASSWORD en NovusBet |

---

## 🚀 Estado Fase 1

Cuando completes todos los pasos:

```
✅ Supabase proyecto creado
✅ .env configurado
✅ Dependencies instaladas
✅ Database schema creado
✅ Conexión validada
✅ Primera sincronización completada
✅ Datos en Supabase (ready para Looker)
✅ Sincronización automática configurada

→ Próximo: FASE 2 - Google Looker Studio
```

---

**Tiempo total esperado**: 45 minutos  
**Fecha de inicio recomendada**: Hoy  
**Marca cada paso conforme completes** ✅

---
