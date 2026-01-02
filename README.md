# heavy_secscan.sh

Wrapper de reconocimiento/pentesting (pasivo + semi-intrusivo) con salida en Markdown + log bruto.

## Requisitos
- amass, subfinder, dnsx, httpx, wafw00f, whatweb, ffuf, nuclei
- naabu o nmap (uno de los dos)
- Opcional: masscan, gowitness, wordlists (SecLists)

## Variables ajustables (env)
- `TOP_PORTS` (por defecto 200) — usa 1000 para más cobertura
- `HTTP_PORTS` (por defecto `80,443,8080,8443,8000,9000`)
- `WORDLIST` (ruta wordlist ffuf, ej. `/usr/share/seclists/Discovery/Web-Content/common.txt`)
- `SUBWL` (wordlist subdominios)
- `NUCLEI_TEMPLATES` (ruta de templates nuclei; por defecto `~/nuclei-templates`)
- `NUCLEI_SEVERITY` (low,medium,high,critical)
- `NUCLEI_TAGS` (ej. exposure,misconfig,cve)
- `FFUF_THREADS` (por defecto 50)
- `TIMEOUT` (por defecto 10)
- `USE_MASSCAN` (true/false) y `MASSCAN_RATE`

## Uso
```bash
chmod +x heavy_secscan.sh
# con flags
./heavy_secscan.sh -d dominio.com -d https://app.ejemplo.com/ruta
# o interactivo
./heavy_secscan.sh
# ingresa dominios/URLs, termina con 'done'
```

Para cada dominio/URL se pregunta el modo:
- (1) solo esa ruta/base (single)
- (2) dominio completo + subdominios (recursive)

## Salidas
- `heavy_report_<fecha>.md` — resumen Markdown
- `heavy_raw_<fecha>.log` — log completo de las herramientas

## Nota
El script **no instala dependencias**. Instala los binarios requeridos (Kali/Parrot ya los incluye en su mayoría; en macOS puedes usar brew). Ajusta wordlists y rutas según tu entorno.### Add File: /Users/max/Desktop/test/light-mcp-server.js
// Minimal backend HTTP (Node.js) – super light.
// No dependencies beyond Node stdlib. To run: node light-mcp-server.js
// Routes:
//   GET /health  -> 200 ok
//   GET /echo?q= -> echoes query

const http = require('http');
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (url.pathname === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'ok' }));
  }
  if (url.pathname === '/echo') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ q: url.searchParams.get('q') || '' }));
  }
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not found' }));
});

server.listen(port, () => {
  console.log(`Light server listening on :${port}`);
});

