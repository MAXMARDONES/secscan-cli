# 🔨 Heavy SecScan CLI

Wrapper de reconocimiento y pentesting (pasivo + semi-intrusivo) con salida en Markdown + log bruto.

---

## 🚀 Quick Start

```bash
# Instalar dependencias (macOS)
brew install nmap amass subfinder httpx wafw00f whatweb ffuf nuclei gowitness

# Clonar y ejecutar
git clone https://github.com/MAXMARDONES/secscan-cli.git
cd secscan-cli
chmod +x heavy_secscan.sh
./heavy_secscan.sh -d ejemplo.com -d https://app.otro.com/ruta
```

### Linux (Kali/Parrot)
```bash
# La mayoría ya vienen instalados, si no:
sudo apt install nmap amass whatweb ffuf
# Para el resto:
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
pip3 install wafw00f
```

---

## 📋 Requisitos

| Herramienta | Qué hace |
|-------------|----------|
| `nmap` | Port scanning |
| `amass` | Subdomain enumeration (pasivo) |
| `subfinder` | Subdomain discovery |
| `httpx` | HTTP probing |
| `wafw00f` | WAF detection |
| `whatweb` | Web fingerprinting |
| `ffuf` | Directory fuzzing |
| `nuclei` | Vulnerability scanning |
| `gowitness` | Screenshots (opcional) |

---

## 🎯 Uso

### Con flags (directo)
```bash
./heavy_secscan.sh -d dominio.com -d https://app.ejemplo.com/ruta
```

### Interactivo
```bash
./heavy_secscan.sh
# Ingresa dominios/URLs, termina con 'done'
```

Para cada dominio/URL se pregunta el modo:
- `(1)` Solo esa ruta/base (single path scan)
- `(2)` Dominio completo + subdominios (full recursive)

---

## ⚙️ Variables de Entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `TOP_PORTS` | 200 | Número de puertos top a escanear (usa 1000 para más cobertura) |
| `HTTP_PORTS` | 80,443,8080,8443,8000,9000 | Puertos HTTP a probar |
| `WORDLIST` | /usr/share/seclists/.../common.txt | Wordlist para ffuf |
| `SUBWL` | - | Wordlist para subdominios |
| `NUCLEI_TEMPLATES` | ~/nuclei-templates | Ruta de templates nuclei |
| `NUCLEI_SEVERITY` | low,medium,high,critical | Severidades a reportar |
| `NUCLEI_TAGS` | exposure,misconfig,cve | Tags de templates |
| `FFUF_THREADS` | 50 | Threads para fuzzing |
| `TIMEOUT` | 10 | Timeout en segundos |
| `USE_MASSCAN` | false | Usar masscan en vez de nmap |
| `MASSCAN_RATE` | 1000 | Rate de masscan |

### Ejemplo con variables:
```bash
TOP_PORTS=1000 NUCLEI_SEVERITY=high,critical ./heavy_secscan.sh -d target.com
```

---

## 📦 Salidas

| Archivo | Contenido |
|---------|-----------|
| `heavy_report_<fecha>.md` | Resumen en Markdown |
| `heavy_raw_<fecha>.log` | Log completo de todas las herramientas |

---

## 🔍 Qué escanea

1. **Subdominios** - amass, subfinder
2. **HTTP Probing** - httpx (encuentra qué responde)
3. **Port Scanning** - nmap top ports
4. **WAF Detection** - wafw00f
5. **Fingerprinting** - whatweb (tecnologías)
6. **Directory Fuzzing** - ffuf (rutas ocultas)
7. **Vulnerabilities** - nuclei templates
8. **Screenshots** - gowitness (opcional)

---

## ⚠️ Disclaimer

Solo usar en dominios propios o con autorización explícita. El escaneo de puertos y fuzzing puede ser detectado y/o ilegal sin permiso.

---

## 🍎 Companion: Rotten Apples MCP

Para scans rápidos desde Claude/Cursor, usa el MCP server:
- https://github.com/MAXMARDONES/rottenapples-mcp
- `claude mcp add --transport http rottenapples https://rottenapples-mcp.vercel.app/mcp`
