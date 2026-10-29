#!/usr/bin/env bash
# =============================================================================
#  demo_semana15.sh - Demostración de la actividad de la semana 15
#
#  Recorre, paso a paso, lo que pide la actividad:
#    1. Servicios levantados con Docker Compose
#    2. Pruebas de humo (pruebas.sh)
#    3. Una falla provocada y su recuperación
#    4. Registro de defectos corregidos con commits
#    5. README: despliegue, pruebas y respaldo
#    6. Respaldo de la base de datos
#
#  Uso:  ./scripts/demo_semana15.sh
#  Cada paso se muestra, se ejecuta y espera Enter antes de continuar.
#  Duración aproximada: 5 minutos.
# =============================================================================

REPO="$HOME/infra-equipo"
COMPOSE_DIR="$REPO/compose"
RESPALDOS="$HOME/respaldos"

# ---- Colores (solo si hay terminal) ----
if [ -t 1 ]; then
  VERDE=$'\e[32m'; AMARILLO=$'\e[33m'; CYAN=$'\e[36m'; NEGRITA=$'\e[1m'; FIN=$'\e[0m'
else
  VERDE=''; AMARILLO=''; CYAN=''; NEGRITA=''; FIN=''
fi

# ---- Funciones de presentación ----

# titulo "texto": limpia la pantalla y muestra el nombre del paso
titulo() {
  clear
  echo "${NEGRITA}${CYAN}=== $1 ===${FIN}"
  echo
}

# mostrar "comando": escribe el comando en pantalla y lo ejecuta
mostrar() {
  echo "${VERDE}\$ $*${FIN}"
  echo
  ( eval "$*" )
  echo
}

# esperar: pausa hasta que se presione Enter
esperar() {
  echo
  read -r -p "${AMARILLO}[Enter para continuar]${FIN} " _
}

cd "$REPO" || { echo "No existe $REPO"; exit 1; }

# ---- Paso 1: servicios ----
titulo "1. Servicios levantados con Docker Compose"
mostrar "cd compose && docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'"
echo "Son 8 servicios: web, app (Adminer), db (PostgreSQL), Prometheus,"
echo "Grafana, node-exporter, cAdvisor y Uptime Kuma."
esperar

# ---- Paso 2: pruebas de humo ----
titulo "2. Pruebas de humo: una por servicio"
mostrar "./scripts/pruebas.sh"
esperar

# ---- Paso 3: falla provocada ----
titulo "3. Falla provocada: apagar Grafana"
read -r -p "${AMARILLO}¿Apagar Grafana para mostrar que las pruebas detectan la falla? [s/N]${FIN} " resp
if [ "$resp" = "s" ] || [ "$resp" = "S" ]; then
  # Si se interrumpe con Ctrl+C, Grafana se vuelve a encender
  trap 'echo; (cd "$COMPOSE_DIR" && docker compose start grafana >/dev/null 2>&1); exit 130' INT

  mostrar "cd compose && docker compose stop grafana"
  mostrar "./scripts/pruebas.sh"
  echo "Las pruebas detectaron la falla de Grafana."
  esperar

  titulo "3. Recuperación: encender Grafana y repetir las pruebas"
  mostrar "cd compose && docker compose start grafana"
  echo "Esperando a que Grafana esté listo..."
  for _ in $(seq 1 30); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/login)" = "200" ] && break
    sleep 2
  done
  mostrar "./scripts/pruebas.sh"
  trap - INT
else
  echo "Paso omitido."
fi
esperar

# ---- Paso 4: defectos y commits ----
titulo "4. Defectos encontrados y corregidos con commits"
mostrar "grep '^## D-' docs/defectos.md"
mostrar "git log --oneline -n 10"
esperar

# ---- Paso 5: README ----
titulo "5. README: despliegue, pruebas y respaldo"
mostrar "grep -n '^#' README.md"
esperar

# ---- Paso 6: respaldo ----
titulo "6. Respaldo de la base de datos"
mostrar "bash scripts/respaldo.sh"
mostrar "ls -lh $RESPALDOS | tail -n 6"
mostrar "cd $RESPALDOS && sha256sum -c \$(ls -t *.sha256 | head -n 1)"

echo "${NEGRITA}${VERDE}Demostración terminada.${FIN}"
