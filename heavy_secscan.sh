#!/usr/bin/env bash
# heavy_secscan.sh
# Wrapper “heavy” de reconocimiento/pentesting pasivo+semiintrusivo.
# Requiere: amass, subfinder, dnsx, httpx, naabu (o nmap), nuclei, ffuf, wafw00f, whatweb, jq, tee.
# Opcional: masscan, gowitness/gowitness, feroxbuster/gobuster, wpscan.
# Salida: Markdown consolidado heavy_report_<fecha>.md

set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="heavy_report_${TS}.md"
RAWLOG="heavy_raw_${TS}.log"
TOP_PORTS="${TOP_PORTS:-200}"                  # Ajusta a 1000 para más puertos
HTTP_PORTS="${HTTP_PORTS:-80,443,8080,8443,8000,9000}"
WORDLIST="${WORDLIST:-/usr/share/seclists/Discovery/Web-Content/common.txt}"
SUBWL="${SUBWL:-/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt}"
NUCLEI_TEMPLATES="${NUCLEI_TEMPLATES:-$HOME/nuclei-templates}"
NUCLEI_SEVERITY="${NUCLEI_SEVERITY:-low,medium,high,critical}"
NUCLEI_TAGS="${NUCLEI_TAGS:-exposure,misconfig,config,cve}"
FFUF_THREADS="${FFUF_THREADS:-50}"
TIMEOUT="${TIMEOUT:-10}"
MASSCAN_RATE="${MASSCAN_RATE:-10000}"
USE_MASSCAN="${USE_MASSCAN:-false}"            # true para usar masscan previo a nmap/naabu

need() { command -v "$1" >/dev/null || { echo "❌ Falta $1"; exit 1; }; }

write_header() {
  {
    echo "# Heavy Security Report"
    echo "| Date: $(date -u) | Script: heavy_secscan.sh |"
    echo
  } >> "$REPORT"
}

log()  { echo "[$(date -u +%H:%M:%S)] $*" | tee -a "$RAWLOG"; }

scan_domain() {
  local domain="$1"
  local scope_mode="$2"   # "single" or "recursive"
  local base_url="$3"     # may be "" for domain-only

  log "Scanning domain: $domain (mode=$scope_mode, base_url=$base_url)"
  {
    echo "## $domain"
    echo "- Date: $(date -u)"
    echo "- Mode: $scope_mode"
    [[ -n "$base_url" ]] && echo "- Base URL: $base_url"
    echo
  } >> "$REPORT"

  # 1) Subdominios (amass + subfinder + dnsx)
  echo "### Subdomain enumeration" >> "$REPORT"
  amass enum -d "$domain" -passive -norecursive -nolocaldns 2>>"$RAWLOG" | sort -u > /tmp/subs."$domain".$$
  subfinder -silent -d "$domain" -all 2>>"$RAWLOG" | sort -u >> /tmp/subs."$domain".$$
  sort -u /tmp/subs."$domain".$$ | dnsx -silent 2>>"$RAWLOG" > /tmp/resolved."$domain".$$
  cat /tmp/resolved."$domain".$$ | sed 's/^/    /' >> "$REPORT"
  echo >> "$REPORT"

  # 2) Puertos
  echo "### Port scan" >> "$REPORT"
  if [[ "$USE_MASSCAN" == "true" ]] && command -v masscan >/dev/null; then
    log "masscan $domain ..."
    masscan -p1-65535 "$domain" --rate "$MASSCAN_RATE" 2>>"$RAWLOG" | head -300 | sed 's/^/    /' >> "$REPORT"
    echo >> "$REPORT"
  fi
  # naabu o nmap
  if command -v naabu >/dev/null; then
    log "naabu $domain ..."
    naabu -host "$domain" -top-ports "$TOP_PORTS" -silent 2>>"$RAWLOG" | sed 's/^/    /' >> "$REPORT"
  else
    log "nmap $domain ..."
    nmap -sV -sC -T4 -Pn --top-ports "$TOP_PORTS" "$domain" 2>>"$RAWLOG" | sed 's/^/    /' >> "$REPORT"
  fi
  echo >> "$REPORT"

  # 3) HTTP fingerprinting (httpx)
  echo "### HTTP probe (httpx)" >> "$REPORT"
  httpx -l /tmp/resolved."$domain".$$ -ports "$HTTP_PORTS" -title -tech-detect -status-code -silent -follow-redirects \
    -timeout "$TIMEOUT" 2>>"$RAWLOG" | sed 's/^/    /' >> "$REPORT"
  echo >> "$REPORT"

  # 4) WAF detection
  echo "### WAF detection (wafw00f)" >> "$REPORT"
  wafw00f "https://$domain" 2>>"$RAWLOG" | sed 's/^/    /' >> "$REPORT"
  echo >> "$REPORT"

  # 5) WhatWeb
  echo "### WhatWeb" >> "$REPORT"
  whatweb -a 3 "https://$domain" 2>>"$RAWLOG" | sed 's/^/    /' >> "$REPORT"
  echo >> "$REPORT"

  # 6) Nuclei (exposures/misconfig/CVE)
  echo "### Nuclei" >> "$REPORT"
  nuclei -u "https://$domain" \
    -severity "$NUCLEI_SEVERITY" \
    -tags "$NUCLEI_TAGS" \
    -templates "$NUCLEI_TEMPLATES" \
    -silent 2>>"$RAWLOG" | sed 's/^/    /' >> "$REPORT"
  echo >> "$REPORT"

  # 7) FFUF (fuzzing de rutas comunes)
  if [[ -f "$WORDLIST" ]]; then
    echo "### FFUF (common paths)" >> "$REPORT"
    ffuf -u "https://$domain/FUZZ" -w "$WORDLIST" -mc all -fc 404 -fs 0 -t "$FFUF_THREADS" -timeout "$TIMEOUT" -ac 2>>"$RAWLOG" \
      | head -200 | sed 's/^/    /' >> "$REPORT"
    echo >> "$REPORT"
  fi

  # 8) Opcional: gowitness screenshots (si instalado)
  if command -v gowitness >/dev/null; then
    echo "### Screenshots (gowitness) - rutas base" >> "$REPORT"
    gowitness single "https://$domain" --disable-logging --timeout "$TIMEOUT" 2>>"$RAWLOG" | sed 's/^/    /' >> "$REPORT"
    echo >> "$REPORT"
  fi

  # 9) Limpieza temporal
  rm -f /tmp/subs."$domain".$$ /tmp/resolved."$domain".$$
}

main() {
  need amass; need subfinder; need dnsx; need httpx; need wafw00f; need whatweb; need ffuf; need nuclei
  if ! command -v naabu >/dev/null && ! command -v nmap >/dev/null; then
    echo "❌ Falta naabu o nmap"; exit 1;
  fi

  DOMAINS=()
  # Flags: -d / --domain to add domains; rest positional also accepted.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--domain)
        shift; [[ $# -gt 0 ]] && DOMAINS+=("$1"); shift || true
        ;;
      -h|--help)
        echo "Uso: $0 [-d dominio] ... [dominios|URLs]"
        echo "Variables opcionales: TOP_PORTS, HTTP_PORTS, WORDLIST, SUBWL, NUCLEI_TEMPLATES, NUCLEI_SEVERITY, NUCLEI_TAGS, FFUF_THREADS, TIMEOUT, USE_MASSCAN, MASSCAN_RATE"
        exit 0
        ;;
      *)
        DOMAINS+=("$1"); shift
        ;;
    esac
  done

  if [[ ${#DOMAINS[@]} -eq 0 ]]; then
    echo "Ingresa dominios o URLs (uno por línea). Escribe 'done' para terminar:"
    while read -r line; do
      [[ -z "$line" ]] && continue
      [[ "$line" == "done" ]] && break
      DOMAINS+=("$line")
    done
  fi

  write_header
  echo "# Raw logs" > "$RAWLOG"

  for input in "${DOMAINS[@]}"; do
    # Detect si es URL con ruta o solo dominio
    if [[ "$input" == http*://*/* ]]; then
      domain=$(echo "$input" | sed -E 's#^https?://##; s#/.*$##')
      base_url="$input"
    else
      domain=$(echo "$input" | sed -E 's#^https?://##; s#/.*$##')
      base_url=""
    fi

    # Preguntar modo
    echo "Dominio/URL: $input"
    echo "Selecciona modo: (1) solo esta ruta/base, (2) dominio completo + subdominios"
    read -r mode
    case "$mode" in
      1) scope_mode="single" ;;
      2) scope_mode="recursive" ;;
      *) scope_mode="recursive" ;;
    esac

    scan_domain "$domain" "$scope_mode" "$base_url"
  done

  echo "✅ Raw log: $RAWLOG"
  echo "✅ Reporte markdown: $REPORT"
}

main "$@"

