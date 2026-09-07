# ⚡ QUICK START - Fase 1 (Copy & Paste Commands)

**Duración**: 45 minutos  
**Dificultad**: Fácil  
**Requisitos**: Terminal, navegador web

---

## 🚀 FASE 1: SETUP COMPLETO

### PASO 1️⃣: Crear Supabase (5 min) - EN EL NAVEGADOR

```
1. Abre https://app.supabase.com
2. Click "New Project"
3. Nombre: novusbet-dashboard
4. Espera creación (2-3 min)
5. Copia estos 3 valores (los necesitarás):
   - Project URL: https://xxxxx.supabase.co
   - Service Role Key: eyJhbGc...
   - Anon Key: eyJhbGc...
```

**Guardar en archivo temporal (ejemplo):**
```
Mi Supabase:
URL: https://xxxxx.supabase.co
Service Role Key: eyJhbGc...
Anon Key: eyJhbGc...
```

---

### PASO 2️⃣: Configurar .env (5 min) - EN TERMINAL

```bash
# Navega al directorio
cd /home/user/compras

# Copia el template
cp .env.example .env

# EDITA EL ARCHIVO CON TUS VALORES
# Opción A: Si tienes VS Code instalado
code .env

# Opción B: Si tienes nano
nano .env
# (Ctrl+X para guardar en nano)

# Opción C: Si tienes vim
vim .env
# (:wq para guardar en vim)
```

**Qué cambiar en .env:**
```env
# Línea 16 - Reemplaza ESTO:
SUPABASE_URL=https://your-project.supabase.co
# CON ESTO (tu URL real):
SUPABASE_URL=https://xxxxx.supabase.co

# Línea 17 - Reemplaza ESTO:
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
# CON ESTO (tu llave real):
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...

# Línea 18 - Reemplaza ESTO:
SUPABASE_ANON_KEY=your-anon-key-here
# CON ESTO (tu anon key real):
SUPABASE_ANON_KEY=eyJhbGc...
```

**Verifica que quedó bien:**
```bash
# Debería mostrar tus valores reales (sin "your-")
grep SUPABASE .env
```

---

### PASO 3️⃣: Instalar Dependencias (2 min) - EN TERMINAL

```bash
# Desde /home/user/compras
pip install -r requirements.txt

# Espera a que termine (~30 segundos)
# Debería terminar con "Successfully installed"
```

**Verificación:**
```bash
python -c "import requests, bs4; print('✅ OK')"
# Debería mostrar: ✅ OK
```

---

### PASO 4️⃣: Generar Schema SQL (1 min) - EN TERMINAL

```bash
# Desde /home/user/compras
python init_database.py

# Verifica que se creó
ls -la supabase_schema.sql
# Debería mostrar un archivo de ~2500 líneas
```

---

### PASO 5️⃣: Ejecutar SQL en Supabase (5 min) - EN EL NAVEGADOR

```
1. Abre https://app.supabase.com → Tu proyecto
2. Click izquierdo: "SQL Editor"
3. Click derecho: "New Query"
4. Abre archivo supabase_schema.sql (en tu editor)
5. Copia TODO el contenido
6. Pega en Supabase SQL Editor
7. Click botón "Run" (verde)
8. Espera ✅ "Query executed successfully"
```

**Verificación en Supabase:**
```
- Debe haber tabla "transaction_records"
- Debe haber 4 vistas (v_discipline_summary, etc)
- Debe haber índices en la tabla
```

---

### PASO 6️⃣: Validar Conexión (5 min) - EN TERMINAL

```bash
# Copiar y pegar COMPLETO en terminal:
python << 'EOF'
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

try:
    response = requests.get(
        f'{url}/rest/v1/transaction_records?limit=1',
        headers=headers,
        timeout=5
    )
    
    if response.status_code == 200:
        print('✅ CONEXIÓN EXITOSA')
        print(f'   URL: {url}')
        print(f'   Status Code: {response.status_code}')
        print('   Tabla transaction_records: ACCESIBLE')
    else:
        print(f'❌ ERROR: {response.status_code}')
        print(f'   {response.text[:200]}')
except Exception as e:
    print(f'❌ ERROR: {e}')
    
EOF
```

**Resultado esperado:**
```
✅ CONEXIÓN EXITOSA
   URL: https://xxxxx.supabase.co
   Status Code: 200
   Tabla transaction_records: ACCESIBLE
```

---

### PASO 7️⃣: Primera Descarga de Datos (10 min) - EN TERMINAL

```bash
# Ejecuta desde /home/user/compras
python main.py

# Deberías ver output como:
# ✓ Iniciando sesión en NovusBet...
# ✓ Descargando datos...
# ✓ Procesando transacciones...
# ✓ Sincronizando con Supabase...
# ✓ Generando reportes...

# Espera a que termine (puede ser 2-5 minutos)
```

**Verifica que funcionó:**
```bash
# Deberían existir reportes
ls -la reportes/

# Deberían mostrar varios archivos CSV
# Ejemplo:
# transacciones_2026-09-07.csv
# resumen_diario.csv
# resumen_por_disciplina.csv
```

**Verifica datos en Supabase:**

En SQL Editor de Supabase:
```sql
SELECT COUNT(*) as total_records FROM transaction_records;
```

Deberías ver un número > 0 (ejemplo: 10500 registros)

---

### PASO 8️⃣: Configurar Sincronización Automática (5 min)

**OPCIÓN A: Cron Job (Linux/Mac)**

```bash
# Edita el crontab
crontab -e

# Agrega esta línea al final del archivo:
*/30 * * * * cd /home/user/compras && python sync_realtime.py >> /home/user/compras/sync.log 2>&1

# Guarda (Ctrl+X en nano, :wq en vim)

# Verifica que quedó instalado:
crontab -l | grep sync_realtime
# Debería mostrar la línea que agregaste
```

**OPCIÓN B: GitHub Actions (Recomendado)**

```bash
# Desde /home/user/compras

# 1. Crea directorio workflows
mkdir -p .github/workflows

# 2. Crea archivo
cat > .github/workflows/sync-novusbet.yml << 'EOF'
name: Sincronizar NovusBet

on:
  schedule:
    - cron: '*/30 * * * *'

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
EOF

# 3. Commit y push
git add .github/workflows/sync-novusbet.yml
git commit -m "Add GitHub Actions sync workflow"
git push origin claude/dashboard-reportes-tiempo-real-elogsq
```

**En GitHub (después de push):**
```
1. Abre https://github.com/ramsja/compras
2. Ir a: Settings → Secrets and variables → Actions
3. Agregar 4 secretos:
   - BO_USERNAME: FinanceSV
   - BO_PASSWORD: Anma07covi*
   - SUPABASE_URL: https://xxxxx.supabase.co
   - SUPABASE_SERVICE_ROLE_KEY: eyJhbGc...
4. Listo - se ejecutará cada 30 minutos
```

---

## ✅ CHECKLIST FINAL FASE 1

```bash
# Copia esto y marca conforme completas:

☐ Supabase proyecto creado (https://app.supabase.com)
☐ .env configurado con credenciales Supabase
☐ Dependencies instaladas (pip install -r requirements.txt)
☐ Schema SQL generado (python init_database.py)
☐ SQL ejecutado en Supabase (paste en SQL Editor)
☐ Conexión validada (python script de validación)
☐ Primera descarga ejecutada (python main.py)
☐ Reportes generados (ls reportes/)
☐ Datos en Supabase (SELECT COUNT verified > 0)
☐ Sincronización automática configurada (cron O GitHub Actions)
☐ Documentación actualizada

FASE 1: ✅ COMPLETADA
```

---

## 🆘 TROUBLESHOOTING RÁPIDO

| Error | Solución |
|-------|----------|
| `ModuleNotFoundError: No module named 'requests'` | `pip install -r requirements.txt` |
| `Connection refused` a Supabase | Verifica SUPABASE_URL en .env (usa https://xxxxx.supabase.co, sin trailing slash) |
| `Invalid authentication` | Copia Service Role Key nuevamente desde Supabase |
| `Table does not exist` | Verifica que ejecutaste el SQL en Supabase SQL Editor |
| `HTTP 401` | El .env tiene credenciales incorrectas |
| `NovusBet login falla` | Verifica que BO_USERNAME y BO_PASSWORD son correctos en .env |

---

## 📊 RESULTADO ESPERADO FASE 1

Después de completar los 8 pasos, deberías tener:

✅ Base de datos PostgreSQL en Supabase  
✅ Schema con 8 tablas creadas  
✅ 4 vistas analíticas  
✅ 500-10,000+ registros de NovusBet  
✅ Sincronización automática cada 30 minutos  
✅ Reportes CSV generados en `/reportes`  

**Siguiente paso**: FASE 2 - Conectar Google Looker Studio

---

## ⏱️ TIMELINE

```
Paso 1: Crear Supabase           5 min
Paso 2: Configurar .env          5 min
Paso 3: Instalar deps            2 min
Paso 4: Generar schema           1 min
Paso 5: Ejecutar SQL             5 min
Paso 6: Validar conexión         5 min
Paso 7: Primera descarga        10 min
Paso 8: Setup automático         5 min
                              -------
TOTAL:                      38 minutos
```

**Hora de inicio**: Cuando comiences  
**Hora de fin estimada**: +45 minutos

---

**¡Listo para empezar? 🚀 Comienza con PASO 1**
