#!/usr/bin/env bash
# =============================================================================
#  pruebas.sh - Pruebas de humo del proyecto integrador (Semana 15)
#
#  ¿Qué es una prueba de humo?
#    Es una comprobación rápida de que cada servicio está vivo y responde.
#    No prueba todas sus funciones: solo confirma que lo básico funciona.
#
#  ¿Qué hace este script?
#    Ejecuta UNA prueba por servicio (9 en total):
#
#      Servicio        Cómo se prueba
#      --------------  ---------------------------------------------------
#      Nginx (web)     Petición HTTP al puerto 8080
#      Adminer (app)   Estado de salud (healthcheck) del contenedor
#      PostgreSQL      Comando pg_isready dentro del contenedor
#      Prometheus      Petición HTTP al puerto 9090
#      Prometheus      Que sus objetivos de monitoreo estén todos "up"
#      Grafana         Petición HTTP al puerto 3000
#      node-exporter   Petición HTTP al puerto 9100
#      Uptime Kuma     Petición HTTP al puerto 3001
#      cAdvisor        Petición HTTP al puerto 8081
#
#  Antes de ejecutarlo:   cd compose && docker compose up -d
#  Uso:                   ./scripts/pruebas.sh
#  Guardar la evidencia:  ./scripts/pruebas.sh | tee evidencia/salida_pruebas.txt
#  Código de salida:      0 = todas aprobadas, 1 = al menos una falló
# =============================================================================

# -----------------------------------------------------------------------------
#  1. CONFIGURACIÓN (si cambian nombres o puertos, solo se edita esta sección)
# -----------------------------------------------------------------------------
HOST="localhost"
CONTENEDOR_APP="compose-app-1"        # Adminer
CONTENEDOR_DB="compose-db-1"          # PostgreSQL
PUERTO_WEB=8080
PUERTO_PROMETHEUS=9090
PUERTO_GRAFANA=3000
PUERTO_NODE_EXPORTER=9100
PUERTO_KUMA=3001
PUERTO_CADVISOR=8081
ESPERA_MAXIMA=10                      # segundos máximos por petición HTTP

# -----------------------------------------------------------------------------
#  2. COLORES Y CONTADORES
#     (los colores se ven en pantalla; con "| tee" se desactivan, salvo que
#      ejecutes:  COLOR=si ./scripts/pruebas.sh | tee archivo.txt )
# -----------------------------------------------------------------------------
if [ -t 1 ] || [ "${COLOR:-}" = "si" ]; then
  VERDE=$'\e[32m'; ROJO=$'\e[31m'; CYAN=$'\e[36m'; FIN=$'\e[0m'
else
  VERDE=''; ROJO=''; CYAN=''; FIN=''
fi

TOTAL=0
APROBADAS=0

# -----------------------------------------------------------------------------
#  3. FUNCIONES AUXILIARES
# -----------------------------------------------------------------------------

# aprobar "Nombre" "detalle"  -> registra una prueba exitosa
aprobar() {
  TOTAL=$(( TOTAL + 1 ))
  APROBADAS=$(( APROBADAS + 1 ))
  printf '[%s OK %s]    %s %s(%s)%s\n' "$VERDE" "$FIN" "$1" "$VERDE" "$2" "$FIN"
}

# fallar "Nombre" "detalle"   -> registra una prueba fallida
fallar() {
  TOTAL=$(( TOTAL + 1 ))
  printf '[%sFALLA%s]    %s %s(%s)%s\n' "$ROJO" "$FIN" "$1" "$ROJO" "$2" "$FIN"
}

# codigo_http URL  -> imprime el código HTTP que devuelve la dirección
#   (no se siguen redirecciones: un 302 o un 307 también indica que responde)
codigo_http() {
  curl -s -o /dev/null -m "$ESPERA_MAXIMA" -w '%{http_code}' "$1" 2>/dev/null
}

# probar_http "Nombre" PUERTO RUTA "códigos aceptados"
#   Ejemplo: probar_http "Grafana" 3000 /login "200"
probar_http() {
  local nombre="$1" puerto="$2" ruta="$3" aceptados="$4" codigo c
  codigo=$(codigo_http "http://${HOST}:${puerto}${ruta}")
  for c in $aceptados; do
    if [ "$codigo" = "$c" ]; then
      aprobar "$nombre" "HTTP $codigo"
      return
    fi
  done
  fallar "$nombre" "HTTP ${codigo:-sin respuesta}, se esperaba: $aceptados"
}

# -----------------------------------------------------------------------------
#  4. VERIFICACIÓN PREVIA: Docker debe estar disponible
# -----------------------------------------------------------------------------
if ! docker info >/dev/null 2>&1; then
  echo "${ROJO}Docker no responde. Revisa que el servicio esté activo o usa sudo.${FIN}"
  exit 1
fi

# -----------------------------------------------------------------------------
#  5. LAS 9 PRUEBAS DE HUMO
# -----------------------------------------------------------------------------
echo "${CYAN}=== Pruebas de humo - proyecto integrador - $(date '+%Y-%m-%d %H:%M:%S') ===${FIN}"

# 1) Nginx (web): la página principal debe responder 200
probar_http "Nginx (web)" "$PUERTO_WEB" "/" "200"

# 2) Adminer (app): no publica puerto, así que se revisa el healthcheck de Docker
estado_app=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CONTENEDOR_APP" 2>/dev/null)
if [ "$estado_app" = "healthy" ]; then
  aprobar "Adminer (app)" "healthcheck: healthy"
else
  fallar "Adminer (app)" "estado: ${estado_app:-contenedor no encontrado}"
fi

# 3) PostgreSQL (db): tampoco publica puerto; pg_isready se ejecuta dentro del contenedor
if docker exec "$CONTENEDOR_DB" sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
  aprobar "PostgreSQL (db)" "pg_isready: accepting connections"
else
  fallar "PostgreSQL (db)" "pg_isready no confirma conexiones"
fi

# 4) Prometheus: endpoint de salud
probar_http "Prometheus" "$PUERTO_PROMETHEUS" "/-/healthy" "200"

# 5) Prometheus: todos sus objetivos de monitoreo deben estar en "up"
objetivos=$(curl -s -m "$ESPERA_MAXIMA" "http://${HOST}:${PUERTO_PROMETHEUS}/api/v1/targets" | python3 -c '
import sys, json
objetivos = json.load(sys.stdin)["data"]["activeTargets"]
print(sum(1 for o in objetivos if o["health"] == "up"), len(objetivos))
' 2>/dev/null)
read -r en_up total_objetivos <<< "$objetivos"
if [ -n "${total_objetivos:-}" ] && [ "$total_objetivos" -gt 0 ] && [ "$en_up" = "$total_objetivos" ]; then
  aprobar "Prometheus: objetivos" "$en_up de $total_objetivos en up"
else
  fallar "Prometheus: objetivos" "${en_up:-0} de ${total_objetivos:-?} en up"
fi

# 6) Grafana: la página de inicio de sesión debe responder 200
probar_http "Grafana" "$PUERTO_GRAFANA" "/login" "200"

# 7) node-exporter: sus métricas deben estar disponibles
probar_http "node-exporter" "$PUERTO_NODE_EXPORTER" "/metrics" "200"

# 8) Uptime Kuma: redirige a su página de acceso (302 es una respuesta válida)
probar_http "Uptime Kuma" "$PUERTO_KUMA" "/" "200 302"

# 9) cAdvisor: redirige a /containers/ (307 es una respuesta válida)
probar_http "cAdvisor" "$PUERTO_CADVISOR" "/" "200 307"

# -----------------------------------------------------------------------------
#  6. RESULTADO FINAL
# -----------------------------------------------------------------------------
echo
if [ "$APROBADAS" -eq "$TOTAL" ]; then
  echo "${VERDE}RESULTADO: ${APROBADAS} de ${TOTAL} pruebas aprobadas${FIN}"
  exit 0
else
  echo "${ROJO}RESULTADO: ${APROBADAS} de ${TOTAL} pruebas aprobadas (revisar las que dicen FALLA)${FIN}"
  exit 1
fi
