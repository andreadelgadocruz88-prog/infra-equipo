#!/usr/bin/env bash
# =============================================================================
#  demo.sh  -  Demostración de la sustentación final (15 minutos)
#
#  Lo que pide el docente:
#    1. Ejecutar la demostración: servicios, pruebas, alerta y respaldo.
#    2. Responder tres preguntas técnicas con evidencias.
#
#  Aquí solo se EJECUTA y se muestra el resultado. Las explicaciones están en
#  el archivo de notas (notas_exposicion.txt).
#
#  Uso:  ./demo.sh               menú
#        ./demo.sh todo          partes 1 a 4 seguidas, con cronómetro
#        ./demo.sh 1|2|3|4       una sola parte
#        ./demo.sh preguntas     evidencias para las preguntas del docente
#        ./demo.sh verificar     revisión previa
#
#  Requiere terminal UTF-8 (PuTTY: Window > Translation > UTF-8).
#  Nunca muestra el contenido de .env ni de kuma_password.
# =============================================================================

REPO="${REPO:-$HOME/infra-equipo}"
COMPOSE_DIR="$REPO/compose"
RESP="$HOME/respaldos"
PROY="compose"
DB="compose-db-1"
URL_PR="https://github.com/andreadelgadocruz88-prog/infra-equipo/pull/2"

if [ "$(locale charmap 2>/dev/null)" != "UTF-8" ]; then export LC_ALL=C.UTF-8; fi

# Tiempo sugerido por parte (segundos): 3 + 3 + 3 + 4 = 13 min; 2 min más para intro y cierre
declare -a PRESUP=(0 180 180 180 240)
declare -a NOMBRES=("" "Servicios y arquitectura" "Pruebas de humo" "Alerta de monitoreo" "Respaldo y restauración")
declare -a USADO=()
T0=0; PARTE=0; P_T0=0; PASOS=0; AJ=""; CC=""; AV=0
CHK=()

# ---------------------------------------------------------------- colores ----
if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; M=$'\e[35m'; C=$'\e[36m'
  W=$'\e[1m'; D=$'\e[2m'; N=$'\e[0m'
else
  R=''; G=''; Y=''; B=''; M=''; C=''; W=''; D=''; N=''
fi

COLS=$(tput cols 2>/dev/null)
{ [ -n "$COLS" ] && [ "$COLS" -gt 0 ]; } 2>/dev/null || COLS=100
TW=$(( COLS - 1 ))
[ "$TW" -gt 118 ] && TW=118
[ "$TW" -lt 78 ] && TW=78

H='─'; V='│'; TL='┌'; TR='┐'; BL='└'; BR='┘'; TJ='┬'; BJ='┴'; LJ='├'; RJ='┤'; X='┼'; HH='═'

# ---------------------------------------------------------------- ayudas -----
ahora()   { date +%s; }
fmt()     { printf '%02d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }
limpiar() { if [ -t 1 ] && [ "${EXPO_NOCLEAR:-0}" != 1 ]; then clear; fi; }
dc()      { ( cd "$COMPOSE_DIR" && docker compose "$@" ); }
rep()     { local s; printf -v s '%*s' "$(( $2 > 0 ? $2 : 0 ))" ''; printf '%s' "${s// /$1}"; }

ajustar() {
  AJ="$1"
  if [ "${#AJ}" -gt "$2" ]; then AJ="${AJ:0:$(( $2 - 1 ))}…"; fi
}

color_celda() {
  CC=""
  case "$1" in
    OK|healthy|UP|up|running|"Up "*|activo|"En tiempo"|"Detectada"|"Aprobada"|"unless-stopped"|always|"SIN ALERTA"|"Publicado"|"Todas las pruebas aprobadas") CC="$G" ;;
    unhealthy|DOWN|down|FALLA|FIRING|firing|Exited*|exited|FAILED|"Muy excedida"|"Hay pruebas fallidas") CC="$R" ;;
    PENDING|pending|starting|AVISO|"Excedida"|ninguna) CC="$Y" ;;
    "Interno"|"solo red interna"*) CC="$C" ;;
  esac
}

# tabla "Título" "Enc1|Enc2|..."   (las filas llegan por la entrada estándar, columnas con |)
tabla() {
  local titulo="$1" enc="$2" linea i n tot mayor sal sp col="${PCOL:-$B}"
  local top mid bot seg
  local -a cab=() filas=() anch=() celdas=()
  IFS='|' read -ra cab <<< "$enc"
  n=${#cab[@]}
  for ((i=0; i<n; i++)); do anch[i]=${#cab[i]}; done
  while IFS= read -r linea; do
    [ -z "$linea" ] && continue
    filas+=("$linea")
    IFS='|' read -ra celdas <<< "$linea"
    for ((i=0; i<n; i++)); do
      [ "${#celdas[i]}" -gt "${anch[i]}" ] && anch[i]=${#celdas[i]}
    done
  done
  if [ "${#filas[@]}" -eq 0 ]; then
    filas+=("(sin datos)")
    [ "${anch[0]}" -lt 11 ] && anch[0]=11
  fi
  while :; do
    tot=$(( 3 * n + 1 ))
    for ((i=0; i<n; i++)); do tot=$(( tot + anch[i] )); done
    [ "$tot" -le "$TW" ] && break
    mayor=0
    for ((i=1; i<n; i++)); do [ "${anch[i]}" -gt "${anch[mayor]}" ] && mayor=$i; done
    [ "${anch[mayor]}" -le 6 ] && break
    anch[mayor]=$(( anch[mayor] - 1 ))
  done
  top="$TL"; mid="$LJ"; bot="$BL"
  for ((i=0; i<n; i++)); do
    seg=$(rep "$H" $(( anch[i] + 2 )))
    if [ "$i" -lt $(( n - 1 )) ]; then
      top+="${seg}${TJ}"; mid+="${seg}${X}"; bot+="${seg}${BJ}"
    else
      top+="${seg}${TR}"; mid+="${seg}${RJ}"; bot+="${seg}${BR}"
    fi
  done
  if [ -n "$titulo" ]; then printf '%s\n' " ${W}${C}»${N} ${W}${titulo}${N}"; fi
  printf '%s\n' "${col}${top}${N}"
  sal="${col}${V}${N}"
  for ((i=0; i<n; i++)); do
    ajustar "${cab[i]}" "${anch[i]}"
    printf -v sp '%*s' "$(( anch[i] - ${#AJ} ))" ''
    sal+=" ${W}${AJ}${N}${sp} ${col}${V}${N}"
  done
  printf '%s\n' "$sal"
  printf '%s\n' "${col}${mid}${N}"
  for linea in "${filas[@]}"; do
    IFS='|' read -ra celdas <<< "$linea"
    sal="${col}${V}${N}"
    for ((i=0; i<n; i++)); do
      ajustar "${celdas[i]:-}" "${anch[i]}"
      color_celda "$AJ"
      printf -v sp '%*s' "$(( anch[i] - ${#AJ} ))" ''
      sal+=" ${CC}${AJ}${N}${sp} ${col}${V}${N}"
    done
    printf '%s\n' "$sal"
  done
  printf '%s\n' "${col}${bot}${N}"
}

comando() { echo; echo "  ${D}\$${N} ${G}$*${N}"; echo; }

# ejecutar "texto visible" ["comando real"]: muestra el comando y lo ejecuta tal cual
ejecutar() {
  local visible="$1" real="${2:-$1}"
  comando "$visible"
  eval "$real"
  return $?
}

banner() {
  local izq=" PARTE ${PARTE} · ${NOMBRES[$PARTE]} " der rel
  der=" sugerido $(fmt "${PRESUP[$PARTE]}") · parte $(fmt $(( $(ahora) - P_T0 ))) · total $(fmt $(( $(ahora) - T0 ))) "
  rel=$(( TW - ${#izq} - ${#der} - 2 )); [ "$rel" -lt 1 ] && rel=1
  printf '%s\n' "${W}${B}${HH}${izq}$(rep "$HH" "$rel")${der}${HH}${N}"
}

parte_ini() { PARTE="$1"; P_T0=$(ahora); PASOS=0; [ "$T0" -eq 0 ] && T0=$(ahora); }

pausa() {
  echo
  printf '%s' "${D}  ── Enter para continuar ──${N} "
  read -r _ || true
}

# paso "Título": espera Enter (salvo el primero), limpia la pantalla y muestra el título
paso() {
  [ "$PASOS" -gt 0 ] && pausa
  PASOS=$(( PASOS + 1 ))
  limpiar; banner; echo
  echo "  ${W}${C}${PARTE}.${PASOS}${N}  ${W}$1${N}"
}

parte_fin() {
  local t=$(( $(ahora) - P_T0 )) lim="${PRESUP[$PARTE]}" col="$G"
  USADO[$PARTE]=$t
  [ "$t" -gt "$lim" ] && col="$Y"
  [ "$t" -gt $(( lim * 13 / 10 )) ] && col="$R"
  echo
  echo "${col}  Parte ${PARTE} terminada: $(fmt "$t") (sugerido $(fmt "$lim"))${N}"
}

confirmar() {
  local r
  printf '%s [S/n] ' "  ${Y}?${N} $1"
  read -r r || r=S
  case "$r" in n|N) return 1 ;; *) return 0 ;; esac
}

rc_texto() { if [ "$1" -eq 0 ]; then echo "Todas las pruebas aprobadas"; else echo "Hay pruebas fallidas"; fi; }

esperar_http() {
  local url="$1" max="$2" i=0 c
  printf '  Esperando %s ' "$url"
  while [ "$i" -lt "$max" ]; do
    c=$(curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
    if [ "$c" = "200" ]; then echo " ${G}listo (${i} s)${N}"; return 0; fi
    printf '.'; sleep 2; i=$(( i + 2 ))
  done
  echo " ${Y}sin respuesta tras ${max} s${N}"; return 1
}

# --------------------------------------------------- consultas a la base ------
sql()  { docker exec -i "$DB" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"' _ "$1"; }
sqlq() { docker exec "$DB" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "$1"' _ "$1" 2>/dev/null; }
sqlt() { docker exec "$DB" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -F"|" -c "$1"' _ "$1" 2>/dev/null; }

preparar_tabla() {
  local n
  sql "CREATE TABLE IF NOT EXISTS prueba_respaldo (id serial PRIMARY KEY, valor int);" >/dev/null 2>&1
  n=$(sqlq "SELECT count(*) FROM prueba_respaldo;")
  if [ "${n:-0}" = "0" ]; then
    sql "INSERT INTO prueba_respaldo (valor) VALUES (10),(20),(30);" >/dev/null 2>&1
  fi
}
filas_demo() { local n; n=$(sqlq "SELECT count(*) FROM prueba_respaldo;"); echo "${n:-}"; }

# ----------------------------------------- datos reales (una fila por línea) --
svc_de() { docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}}' "$1" 2>/dev/null; }

funcion_servicio() {
  case "$1" in
    web)           echo "Servidor web (Nginx)" ;;
    app)           echo "Adminer: gestor web de la base de datos" ;;
    db)            echo "PostgreSQL: base de datos" ;;
    prometheus)    echo "Recolecta métricas y evalúa alertas" ;;
    grafana)       echo "Dashboards de monitoreo" ;;
    node-exporter) echo "Métricas del servidor (CPU, memoria, disco)" ;;
    cadvisor)      echo "Métricas de cada contenedor" ;;
    uptime-kuma)   echo "Disponibilidad de los servicios" ;;
    *)             echo "—" ;;
  esac
}

datos_servicios() {
  local c
  for c in $(docker ps -a --filter "label=com.docker.compose.project=$PROY" -q); do
    docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}}|{{.Config.Image}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$c"
  done | sort | while IFS='|' read -r s img est; do
    printf '%s|%s|%s|%s\n' "$s" "$(funcion_servicio "$s")" "$img" "$est"
  done
}

datos_puertos() {
  local ip c s pubs int pub _f
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  for c in $(docker ps --filter "label=com.docker.compose.project=$PROY" -q); do
    s=$(svc_de "$c")
    pubs=$(docker port "$c" 2>/dev/null | grep -F '0.0.0.0:')
    if [ -n "$pubs" ]; then
      while read -r int _f pub; do
        printf '%s|%s|%s|%s|%s\n' "$s" "${pub##*:}" "$int" "http://${ip}:${pub##*:}" "Publicado"
      done <<< "$pubs"
    else
      int=$(docker inspect -f '{{range $p,$v := .Config.ExposedPorts}}{{$p}} {{end}}' "$c" 2>/dev/null)
      printf '%s|—|%s|solo red interna|Interno\n' "$s" "${int:-—}"
    fi
  done | sort
}

datos_accesos() {
  local ip
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  printf 'Grafana (dashboards)|http://%s:3000\n' "$ip"
  printf 'Prometheus (métricas y alertas)|http://%s:9090\n' "$ip"
  printf 'Uptime Kuma (disponibilidad)|http://%s:3001\n' "$ip"
}

datos_redes() {
  local n d m k
  for n in $(docker network ls --filter "label=com.docker.compose.project=$PROY" --format '{{.Name}}'); do
    d=$(docker network inspect -f '{{.Driver}}' "$n" 2>/dev/null)
    m=$(docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' "$n" 2>/dev/null \
        | sed -E 's/compose-//g; s/-[0-9]+( |$)/\1/g' | xargs)
    k=$(echo "$m" | wc -w)
    printf '%s|%s|%s|%s\n' "$n" "$d" "$(echo "$m" | sed 's/ /, /g')" "$k"
  done
}

descripcion_volumen() {
  case "${1#${PROY}_}" in
    datos-db)         echo "Datos de PostgreSQL (tablas y registros)" ;;
    grafana-datos)    echo "Dashboards y configuración de Grafana" ;;
    kuma-datos)       echo "Monitores e historial de Uptime Kuma" ;;
    prometheus-datos) echo "Histórico de métricas de Prometheus" ;;
    *)                echo "—" ;;
  esac
}

datos_volumenes() {
  local v u
  for v in $(docker volume ls --filter "label=com.docker.compose.project=$PROY" --format '{{.Name}}'); do
    u=$(docker ps -a --filter "volume=$v" --format '{{.Names}}' | sed -E 's/^compose-//; s/-[0-9]+$//' | tr '\n' ' ' | xargs | sed 's/ /, /g')
    printf '%s|%s|%s|%s\n' "$v" "${u:-—}" "$(descripcion_volumen "$v")" "$(docker volume inspect -f '{{.Driver}}' "$v" 2>/dev/null)"
  done
}

datos_politicas() {
  local c
  for c in $(docker ps -a --filter "label=com.docker.compose.project=$PROY" -q); do
    docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}}|{{.HostConfig.RestartPolicy.Name}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}sin healthcheck{{end}}|{{.State.Status}}|{{.RestartCount}}|{{.State.StartedAt}}' "$c"
  done | sort | while IFS='|' read -r s pol sal est rc ini; do
    if [ -z "$pol" ] || [ "$pol" = "no" ]; then pol="ninguna"; fi
    ini="${ini%%.*}"; ini="${ini%Z}"; ini="${ini/T/ }"
    printf '%s|%s|%s|%s|%s|%s\n' "$s" "$pol" "$sal" "$est" "$rc" "$ini"
  done
}

datos_reinicio_vm() {
  printf 'Máquina encendida desde|%s\n' "$(uptime -s 2>/dev/null)"
  printf 'Tiempo encendida|%s\n' "$(uptime -p 2>/dev/null | sed 's/^up //')"
}

reglas_prometheus() {
  curl -s --max-time 5 localhost:9090/api/v1/rules | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    for g in d["data"]["groups"]:
        for r in g["rules"]:
            print("%s|%s|%s|%ss|%s" % (g["name"], r["name"], r.get("state", "-"), int(r.get("duration", 0)), r.get("labels", {}).get("severity", "-")))
except Exception:
    pass
' 2>/dev/null
}

objetivos_prometheus() {
  curl -s --max-time 5 localhost:9090/api/v1/targets | python3 -c '
import sys, json
try:
    for t in json.load(sys.stdin)["data"]["activeTargets"]:
        print("%s|%s|%s" % (t["labels"].get("job", "?"), t["labels"].get("instance", "?"), t["health"]))
except Exception:
    pass
' 2>/dev/null
}

estado_alertas() {
  curl -s --max-time 5 localhost:9090/api/v1/alerts | python3 -c '
import sys, json
try:
    for x in json.load(sys.stdin)["data"]["alerts"]:
        print("%s|%s|%s" % (x["labels"].get("alertname"), x["state"].upper(), x["labels"].get("job", "?")))
except Exception:
    pass
' 2>/dev/null
}

tipo_respaldo() {
  case "$1" in
    bd-*)      echo "Base de datos (pg_dump)" ;;
    docs-*)    echo "Documentos (tar.gz)" ;;
    *.sha256)  echo "Huella de integridad" ;;
    *)         echo "—" ;;
  esac
}

datos_respaldos() {
  local f b s h
  for f in $(ls -t "$RESP"/* 2>/dev/null | head -n 6); do
    b=$(basename "$f"); s=$(stat -c '%s' "$f")
    h=$(numfmt --to=iec --suffix=B "$s" 2>/dev/null || echo "${s} B")
    printf '%s|%s|%s|%s\n' "$b" "$(tipo_respaldo "$b")" "$h" "$(stat -c '%y' "$f" | cut -c1-16)"
  done
}

datos_hashes() {
  local f
  ( cd "$RESP" 2>/dev/null && for f in $(ls -t ./*.sha256 2>/dev/null | head -n 2); do
      sha256sum -c "$f" 2>&1 | sed -E 's#^\./##; s/: /|/' | grep '|'
    done )
}

restaurar_bd() {
  local f
  f=$(ls -t "$RESP"/bd-*.sql.gz 2>/dev/null | head -n 1)
  if [ -z "$f" ]; then echo "  No hay respaldos de la base en $RESP"; return 1; fi
  echo "  Archivo usado: $(basename "$f")"
  zcat "$f" | docker exec -i "$DB" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' 2>&1 \
    | grep -E 'CREATE TABLE|COPY|ERROR'
}

restaurar_docs() {
  local f
  f=$(ls -t "$RESP"/docs-*.tar.gz 2>/dev/null | head -n 1)
  if [ -z "$f" ]; then echo "  No hay respaldos de documentos en $RESP"; return 1; fi
  echo "  Archivo usado: $(basename "$f")"
  rm -rf /tmp/restauracion; mkdir -p /tmp/restauracion
  tar -xzf "$f" -C /tmp/restauracion 2>/dev/null
}

datos_docs_restaurados() {
  find /tmp/restauracion -type f -printf '%P|%s bytes\n' 2>/dev/null | head -n 15
}

correccion_defecto() {
  case "$1" in
    D-01) echo "restart: unless-stopped en los 8 servicios" ;;
    D-02) echo "Clave leída con password_file y clave rotada" ;;
    D-03) echo "Volumen para Grafana y migración de dashboards" ;;
    D-04) echo "Documentado: Docker publica puertos fuera de UFW" ;;
    *)    echo "—" ;;
  esac
}

datos_defectos() {
  grep -E '^## D-[0-9]+' docs/defectos.md 2>/dev/null \
    | sed -E 's/^## (D-[0-9]+)[ :.—–-]*(.*)$/\1|\2/' \
    | while IFS='|' read -r id t; do
        printf '%s|%s|%s\n' "$id" "$t" "$(correccion_defecto "$id")"
      done
}

datos_commits() { git log --date=short --format='%h|%ad|%s' -n "${1:-12}" 2>/dev/null; }

datos_git() {
  local rama pend
  rama=$(git branch --show-current 2>/dev/null)
  pend=$(git status --short 2>/dev/null | wc -l)
  printf 'Rama actual|%s\n' "${rama:-?}"
  printf 'Commits de la rama respecto a main|%s\n' "$(git rev-list --count main..HEAD 2>/dev/null || echo '?')"
  if [ "$pend" -eq 0 ]; then printf 'Cambios sin guardar|Ninguno\n'; else printf 'Cambios sin guardar|%s archivo(s)\n' "$pend"; fi
  printf 'Pull Request|%s\n' "$URL_PR"
}

comprobar_secretos() {
  if git ls-files 2>/dev/null | grep -qE 'kuma_password|(^|/)\.env$'; then return 1; fi
  return 0
}

datos_seguridad() {
  local est ufw perm
  if comprobar_secretos; then est=OK; else est=FALLA; fi
  printf 'Secretos fuera de Git|%s|Ni .env ni kuma_password aparecen en git ls-files\n' "$est"
  if git check-ignore -q compose/monitoring/kuma_password && git check-ignore -q compose/.env; then est=OK; else est=AVISO; fi
  printf '.gitignore protege los secretos|%s|git check-ignore reconoce kuma_password y .env\n' "$est"
  if grep -q 'password_file' compose/monitoring/prometheus.yml 2>/dev/null; then est=OK; else est=AVISO; fi
  printf 'Clave de Kuma fuera del YAML|%s|prometheus.yml la lee con password_file\n' "$est"
  perm=$(stat -c '%a' compose/monitoring/kuma_password 2>/dev/null)
  if [ -n "$perm" ]; then est=OK; else est=AVISO; fi
  printf 'Permisos del archivo de la clave|%s|Permisos %s (Prometheus necesita leerla)\n' "$est" "${perm:-?}"
  if docker port "$DB" 2>/dev/null | grep -q .; then est=AVISO; else est=OK; fi
  printf 'PostgreSQL sin puerto publicado|%s|Solo accesible desde la red interna de Docker\n' "$est"
  ufw=$(sudo -n ufw status 2>/dev/null | head -n 1)
  if [ -n "$ufw" ]; then printf 'Cortafuegos UFW|OK|%s\n' "$ufw"
  else printf 'Cortafuegos UFW|AVISO|Requiere sudo (ejecutar antes: sudo ufw status)\n'; fi
}

funcion_archivo() {
  case "$1" in
    README.md)                                   echo "Presentación general del proyecto" ;;
    compose/docker-compose.yml)                  echo "Define los 8 servicios, sus redes y volúmenes" ;;
    compose/monitoring/prometheus.yml)           echo "Qué vigila Prometheus y cada cuánto" ;;
    compose/monitoring/alertas.yml)              echo "Regla de alerta ServicioCaido" ;;
    compose/monitoring/dashboard-monitoreo.json) echo "Dashboard de Grafana exportado" ;;
    scripts/pruebas.sh)                          echo "Pruebas de humo: 9 comprobaciones" ;;
    scripts/respaldo.sh)                         echo "Respaldo de documentos y base, con huella sha256" ;;
    scripts/exposicion.sh)                       echo "Guía de la sustentación (versión anterior)" ;;
    scripts/demo.sh)                             echo "Demostración de la sustentación" ;;
    docs/defectos.md)                            echo "Registro de defectos y su corrección" ;;
    docs/reflexion-semana15.md)                  echo "Reflexión de la semana 15" ;;
    *)                                           echo "—" ;;
  esac
}

datos_estructura() {
  local f n
  while read -r f; do
    printf '%s|%s\n' "$f" "$(funcion_archivo "$f")"
  done < <( cd "$REPO" && { find compose scripts docs -type f ! -name kuma_password ! -name '.env' 2>/dev/null; echo README.md; } | sort )
  n=$(find "$REPO/semana09" -type f 2>/dev/null | wc -l)
  if [ "$n" -gt 0 ]; then printf 'semana09/ (%s archivos)|Scripts de automatización de la semana 9\n' "$n"; fi
}

# =============================================================================
#                         LAS 4 PARTES DE LA DEMOSTRACIÓN
# =============================================================================
parte1() {
  parte_ini 1

  paso "Los 8 servicios del proyecto"
  comando "docker ps -a --filter label=com.docker.compose.project=$PROY"
  datos_servicios | tabla "Servicios" "Servicio|Función|Imagen|Estado"

  paso "Puertos publicados y accesos"
  comando "docker port <contenedor>   (uno por servicio)"
  datos_puertos | tabla "Puertos" "Servicio|Puerto en la VM|Puerto interno|Acceso|Exposición"
  echo
  datos_accesos | tabla "Para abrir en el navegador" "Herramienta|Dirección"

  paso "Volúmenes y redes"
  comando "docker volume ls --filter label=com.docker.compose.project=$PROY"
  datos_volumenes | tabla "Volúmenes (los datos viven aquí, fuera del contenedor)" "Volumen|Usado por|Qué guarda|Tipo"
  comando "docker network ls --filter label=com.docker.compose.project=$PROY"
  datos_redes | tabla "Redes" "Red|Tipo|Servicios conectados|N.°"

  paso "Reinicio automático y salud"
  comando "docker inspect -f '{{.HostConfig.RestartPolicy.Name}} {{.State.Health.Status}}' <contenedor>"
  datos_politicas | tabla "Política de reinicio y salud" "Servicio|Reinicio automático|Salud|Estado|Reinicios|Iniciado (UTC)"
  echo
  datos_reinicio_vm | tabla "Prueba de reinicio de la VM" "Dato|Valor"

  paso "Herramientas adicionales en la VM (fuera de los 8 servicios)"
  comando "docker ps --format '{{.Names}}|{{.Status}}|{{.Ports}}'"
  docker ps --format '{{.Names}}|{{.Status}}|{{.Ports}}' 2>/dev/null | grep -v '^compose-' \
    | tabla "Portainer, n8n y otros (no pertenecen al compose del proyecto)" "Contenedor|Estado|Puertos"
  parte_fin
}

parte2() {
  parte_ini 2
  local rc rc1 rc2

  paso "Ejecutar las 9 pruebas de humo"
  ejecutar "./scripts/pruebas.sh"
  rc=$?
  echo
  printf 'Código de salida|%s|%s\n' "$rc" "$(rc_texto "$rc")" | tabla "" "Dato|Valor|Interpretación"

  paso "Falla provocada: apagar Grafana (opcional)"
  echo
  if ! confirmar "¿Apagar Grafana para demostrar que las pruebas detectan la falla?"; then
    echo "  Omitido."
    parte_fin; return
  fi
  trap 'echo; echo "Interrumpido: encendiendo Grafana..."; dc start grafana >/dev/null 2>&1; exit 130' INT
  ejecutar "docker compose stop grafana" "dc stop grafana"
  ejecutar "./scripts/pruebas.sh"
  rc1=$?

  paso "Recuperar Grafana y repetir las pruebas"
  ejecutar "docker compose start grafana" "dc start grafana"
  esperar_http "http://localhost:3000/login" 120
  ejecutar "./scripts/pruebas.sh"
  rc2=$?
  trap - INT
  echo
  {
    printf 'Grafana apagado|%s|%s|%s\n' "$rc1" "$(rc_texto "$rc1")" "$([ "$rc1" -ne 0 ] && echo Detectada || echo AVISO)"
    printf 'Grafana recuperado|%s|%s|%s\n' "$rc2" "$(rc_texto "$rc2")" "$([ "$rc2" -eq 0 ] && echo Aprobada || echo AVISO)"
  } | tabla "Comparación" "Fase|Código de salida|Interpretación|Estado"
  parte_fin
}

parte3() {
  parte_ini 3

  paso "La regla de alerta"
  comando "cat -n compose/monitoring/alertas.yml"
  cat -n compose/monitoring/alertas.yml 2>/dev/null | head -n 40

  paso "Reglas y objetivos cargados en Prometheus"
  comando "curl -s localhost:9090/api/v1/rules"
  reglas_prometheus | tabla "Reglas de alerta" "Grupo|Regla|Estado|Duración|Severidad"
  comando "curl -s localhost:9090/api/v1/targets"
  objetivos_prometheus | tabla "Objetivos monitoreados" "Job|Dirección|Salud"

  paso "Alerta en vivo: apagar node-exporter (≈ 1,5 min)"
  echo
  if ! confirmar "¿Provocar la alerta apagando node-exporter?"; then
    echo "  Omitido."
    parte_fin; return
  fi
  trap 'echo; echo "Interrumpido: encendiendo node-exporter..."; dc start node-exporter >/dev/null 2>&1; exit 130' INT
  ejecutar "docker compose stop node-exporter" "dc stop node-exporter"
  local t=0 out est prev=""
  local -a trans=()
  echo
  while [ "$t" -le 150 ]; do
    out=$(estado_alertas)
    if echo "$out" | grep -q FIRING; then est="FIRING"
    elif echo "$out" | grep -q PENDING; then est="PENDING"
    else est="SIN ALERTA"; fi
    printf '  %s[%3s s]%s  %s\n' "$D" "$t" "$N" "$est"
    if [ "$est" != "$prev" ]; then trans+=("${t} s|${est}"); prev="$est"; fi
    [ "$est" = "FIRING" ] && break
    sleep 10; t=$(( t + 10 ))
  done
  echo
  printf '%s\n' "${trans[@]}" | tabla "Evolución de la alerta" "Tiempo|Estado"
  echo
  ejecutar "docker compose start node-exporter" "dc start node-exporter"
  sleep 25
  trap - INT
  echo
  local activas; activas=$(estado_alertas)
  if [ -z "$activas" ]; then
    echo "  ${G}Sin alertas activas: node-exporter se recuperó y la alerta se resolvió.${N}"
  else
    echo "$activas" | tabla "Alertas activas tras recuperar el servicio" "Alerta|Estado|Job"
  fi
  parte_fin
}

parte4() {
  parte_ini 4
  local n0 n1 n2 otras

  paso "Estado inicial de los datos"
  preparar_tabla
  comando "SELECT id, valor FROM prueba_respaldo;"
  sqlt "SELECT id, valor FROM prueba_respaldo ORDER BY id;" | tabla "Tabla prueba_respaldo (antes)" "id|valor"
  n0=$(filas_demo)

  paso "Crear el respaldo y comprobar su integridad"
  ejecutar "bash scripts/respaldo.sh"
  echo
  datos_respaldos | tabla "Archivos más recientes en ~/respaldos" "Archivo|Tipo|Tamaño|Creado"
  comando "sha256sum -c <archivo>.sha256"
  datos_hashes | tabla "Comprobación de integridad" "Archivo|Resultado"

  paso "Simular el desastre: borrar la tabla"
  ejecutar "DROP TABLE prueba_respaldo;" 'sql "DROP TABLE prueba_respaldo;"'
  ejecutar "SELECT * FROM prueba_respaldo;" 'sql "SELECT * FROM prueba_respaldo;" 2>&1'
  n1=$(filas_demo)

  paso "Restaurar la base desde el respaldo"
  otras=$(sqlq "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name<>'prueba_respaldo';")
  if [ "${otras:-0}" != "0" ]; then
    echo
    echo "  ${Y}Precaución:${N} la base tiene $otras tabla(s) además de la de demostración."
    echo "  Restaurar el respaldo completo sobre la base en uso podría duplicar sus datos."
    echo
    if ! confirmar "¿Restaurar de todos modos?"; then
      echo "  Restauración omitida."
      parte_fin; return
    fi
  fi
  ejecutar "zcat bd-FECHA.sql.gz | psql" "restaurar_bd"
  n2=$(filas_demo)
  echo
  sqlt "SELECT id, valor FROM prueba_respaldo ORDER BY id;" | tabla "Tabla prueba_respaldo (después de restaurar)" "id|valor"
  echo
  {
    printf 'Antes del desastre|%s|OK\n' "${n0:-?}"
    printf 'Tras borrar la tabla|%s|FALLA\n' "${n1:-tabla inexistente}"
    if [ -n "$n2" ] && [ "$n2" = "$n0" ]; then printf 'Tras restaurar el respaldo|%s|OK\n' "$n2"
    else printf 'Tras restaurar el respaldo|%s|AVISO\n' "${n2:-sin datos}"; fi
  } | tabla "Resumen del ciclo" "Momento|Filas en la tabla|Estado"

  paso "Restaurar los documentos"
  ejecutar "tar -xzf docs-FECHA.tar.gz -C /tmp/restauracion" "restaurar_docs"
  echo
  datos_docs_restaurados | tabla "Archivos recuperados (primeros 15)" "Ruta|Tamaño"
  parte_fin
}

# =============================================================================
#              PREGUNTAS DEL DOCENTE: SOLO LA EVIDENCIA EN VIVO
# =============================================================================
pregunta() { limpiar; echo; echo "  ${W}${M}PREGUNTA${N}  ${W}$1${N}"; echo; }

q_puertos() {
  pregunta "¿Qué puertos usa la plataforma y por qué app y db no publican puerto?"
  comando "docker port <contenedor>"
  datos_puertos | tabla "Puertos del proyecto" "Servicio|Puerto en la VM|Puerto interno|Acceso|Exposición"
}
q_volumenes() {
  pregunta "¿Qué pasa con los datos si se borra un contenedor? ¿Dónde se guardan?"
  comando "docker volume ls --filter label=com.docker.compose.project=$PROY"
  datos_volumenes | tabla "Volúmenes" "Volumen|Usado por|Qué guarda|Tipo"
  local v mp
  v=$(docker volume ls --filter "label=com.docker.compose.project=$PROY" --format '{{.Name}}' | head -n 1)
  if [ -n "$v" ]; then
    comando "docker volume inspect -f '{{.Mountpoint}}' $v"
    docker volume inspect -f '{{.Mountpoint}}' "$v" 2>/dev/null
  fi
}
q_redes() {
  pregunta "¿Por qué dos redes y cómo se comunican los contenedores?"
  comando "docker network ls  +  docker network inspect <red>"
  datos_redes | tabla "Redes" "Red|Tipo|Servicios conectados|N.°"
}
q_reinicio() {
  pregunta "¿Qué hace restart: unless-stopped y cómo lo comprobaste?"
  datos_politicas | tabla "Reinicio automático y salud" "Servicio|Reinicio automático|Salud|Estado|Reinicios|Iniciado (UTC)"
  echo
  datos_reinicio_vm | tabla "Máquina virtual" "Dato|Valor"
  comando "grep -i -n 'reinicio' docs/defectos.md"
  grep -i -n 'reinicio' docs/defectos.md 2>/dev/null | head -n 8
}
q_pruebas() {
  pregunta "¿Qué es una prueba de humo y cómo compruebas que una corrección no rompió otra cosa?"
  ejecutar "./scripts/pruebas.sh | tail -n 12" "./scripts/pruebas.sh | tail -n 12"
  echo
  comando "git log --oneline -n 8"
  git log --oneline -n 8 2>/dev/null
}
q_seguridad() {
  pregunta "¿Qué medidas de seguridad aplicaste?"
  datos_seguridad | tabla "Medidas de seguridad" "Medida|Estado|Evidencia"
  comando "grep -n -B2 -A2 'password_file' compose/monitoring/prometheus.yml"
  grep -n -B2 -A2 'password_file' compose/monitoring/prometheus.yml 2>/dev/null
}
q_defectos() {
  pregunta "¿Qué defectos encontraste y cómo los corregiste?"
  comando "grep -n '^## D-' docs/defectos.md"
  datos_defectos | tabla "Defectos detectados y corregidos" "ID|Defecto|Corrección aplicada"
}
q_git() {
  pregunta "¿Cómo usaste Git? ¿Qué es el Pull Request?"
  datos_git | tabla "Estado del repositorio" "Dato|Valor"
  comando "git log --date=short --format='%h|%ad|%s' -n 12"
  datos_commits 12 | tabla "Últimos commits" "Commit|Fecha|Mensaje"
  comando "git diff --stat main...HEAD"
  git diff --stat main...HEAD 2>/dev/null | tail -n 14
}
q_alerta() {
  pregunta "¿Cómo funciona la alerta y qué le falta?"
  reglas_prometheus | tabla "Reglas de alerta" "Grupo|Regla|Estado|Duración|Severidad"
  estado_alertas | tabla "Alertas activas" "Alerta|Estado|Job"
  comando "sed -n '1,40p' compose/monitoring/alertas.yml"
  sed -n '1,40p' compose/monitoring/alertas.yml 2>/dev/null
}
q_monitoreo() {
  pregunta "¿Qué hace cada herramienta de monitoreo?"
  objetivos_prometheus | tabla "Objetivos de Prometheus" "Job|Dirección|Salud"
  comando "curl -s localhost:9100/metrics | head -n 3"
  curl -s --max-time 5 localhost:9100/metrics 2>/dev/null | head -n 3
}
q_respaldo() {
  pregunta "¿Cómo respaldas y cómo compruebas que se puede restaurar?"
  datos_respaldos | tabla "Archivos en ~/respaldos" "Archivo|Tipo|Tamaño|Creado"
  datos_hashes | tabla "Comprobación de integridad" "Archivo|Resultado"
  comando "crontab -l"
  crontab -l 2>/dev/null | grep -v '^#'
}
q_estructura() {
  pregunta "¿Cómo está organizado el repositorio?"
  comando "find compose scripts docs -type f | sort"
  datos_estructura | tabla "Contenido del repositorio" "Archivo|Para qué sirve"
}

q_readme() {
  pregunta "¿Qué contiene el README? (despliegue, pruebas y respaldo)"
  comando "grep -n '^#' README.md"
  grep -n '^#' README.md 2>/dev/null
  echo
  {
    local t
    for t in "Despliegue|despliegue|docker compose up" "Pruebas|pruebas.sh|pruebas" "Respaldo|respaldo.sh|respaldo"; do
      IFS='|' read -r nombre a b <<< "$t"
      if grep -qiE "$a|$b" README.md 2>/dev/null; then printf '%s|Mencionado en el README|OK\n' "$nombre"
      else printf '%s|No se encontró en el README|AVISO\n' "$nombre"; fi
    done
  } | tabla "Secciones que pide la actividad" "Tema|Resultado|Estado"
}

menu_preguntas() {
  local op
  while true; do
    limpiar
    echo
    {
      printf '1|Puertos|¿Qué puertos usa y por qué app y db no publican?\n'
      printf '2|Volúmenes|¿Qué pasa con los datos si se borra un contenedor?\n'
      printf '3|Redes|¿Por qué dos redes y cómo se comunican?\n'
      printf '4|Reinicio automático|¿Qué hace unless-stopped?\n'
      printf '5|Pruebas|¿Qué es una prueba de humo y la regresión?\n'
      printf '6|Seguridad|¿Qué medidas de seguridad aplicaste?\n'
      printf '7|Defectos|¿Qué defectos encontraste y cómo los corregiste?\n'
      printf '8|Git y Pull Request|¿Cómo usaste Git?\n'
      printf '9|Alerta|¿Cómo funciona la alerta y qué le falta?\n'
      printf '10|Monitoreo|¿Qué hace cada herramienta?\n'
      printf '11|Respaldo|¿Cómo compruebas que se puede restaurar?\n'
      printf '12|Estructura|¿Cómo está organizado el repositorio?\n'
      printf '13|README|¿Qué contiene: despliegue, pruebas y respaldo?\n'
      printf '0|Volver|Regresar al menú principal\n'
    } | tabla "Preguntas del docente (evidencia en vivo)" "N.°|Tema|Pregunta típica"
    echo
    printf '%s' "  Tema: "
    read -r op || return
    case "$op" in
      1) q_puertos ;; 2) q_volumenes ;; 3) q_redes ;; 4) q_reinicio ;;
      5) q_pruebas ;; 6) q_seguridad ;; 7) q_defectos ;; 8) q_git ;;
      9) q_alerta ;; 10) q_monitoreo ;; 11) q_respaldo ;; 12) q_estructura ;; 13) q_readme ;;
      0|"") return ;;
      *) echo "  Opción no válida"; sleep 1; continue ;;
    esac
    pausa
  done
}

# =============================================================================
#                          VERIFICACIÓN PREVIA
# =============================================================================
chk() { CHK+=("$1|$2|$3"); case "$3" in AVISO|FALLA) AV=$(( AV + 1 )) ;; esac; }

verificar() {
  local tot san p v f pub falta
  limpiar; AV=0; CHK=()
  echo; echo "  Comprobando, un momento..."; echo

  if ! command -v docker >/dev/null 2>&1; then
    chk "Docker" "Docker instalado" FALLA
  elif ! docker info >/dev/null 2>&1; then
    chk "Docker" "Docker responde (permisos o servicio detenido)" AVISO
  else
    chk "Docker" "Docker responde" OK
    tot=$(docker ps --filter "label=com.docker.compose.project=$PROY" -q | wc -l)
    san=$(docker ps --filter "label=com.docker.compose.project=$PROY" --filter health=healthy -q | wc -l)
    if [ "$tot" -eq 8 ]; then chk "Servicios" "8 contenedores del proyecto en ejecución" OK; else chk "Servicios" "Solo $tot de 8 contenedores en ejecución" AVISO; fi
    if [ "$san" -eq 8 ]; then chk "Servicios" "8 contenedores healthy" OK; else chk "Servicios" "Healthy: $san de 8" AVISO; fi
    pub=$(docker ps --filter "label=com.docker.compose.project=$PROY" --format '{{.Ports}}' | grep -oE '0\.0\.0\.0:[0-9]+' | cut -d: -f2 | sort -u)
    falta=""
    for p in 8080 9090 3000 3001 8081 9100; do echo "$pub" | grep -qx "$p" || falta+=" $p"; done
    if [ -z "$falta" ]; then chk "Puertos" "Publicados: 8080, 9090, 3000, 3001, 8081 y 9100" OK; else chk "Puertos" "No están publicados:$falta" AVISO; fi
    if echo "$pub" | grep -qx 5432; then chk "Puertos" "PostgreSQL publica el 5432 (no debería)" FALLA; else chk "Puertos" "PostgreSQL no publica puertos" OK; fi
    falta=""
    for v in compose_datos-db compose_grafana-datos compose_kuma-datos compose_prometheus-datos; do
      docker volume ls -q | grep -qx "$v" || falta+=" $v"
    done
    if [ -z "$falta" ]; then chk "Volúmenes" "Los 4 volúmenes de datos existen" OK; else chk "Volúmenes" "Faltan:$falta" AVISO; fi
  fi

  falta=""
  for f in README.md scripts/pruebas.sh scripts/respaldo.sh docs/defectos.md docs/reflexion-semana15.md \
           compose/docker-compose.yml compose/monitoring/alertas.yml compose/monitoring/prometheus.yml \
           compose/monitoring/dashboard-monitoreo.json; do
    [ -f "$REPO/$f" ] || falta+=" $f"
  done
  if [ -z "$falta" ]; then chk "Archivos" "Los 9 archivos del repositorio están presentes" OK; else chk "Archivos" "Faltan:$falta" AVISO; fi
  if [ -s "$REPO/compose/monitoring/kuma_password" ]; then chk "Archivos" "kuma_password existe (contenido no mostrado)" OK; else chk "Archivos" "kuma_password falta o está vacío" AVISO; fi

  if comprobar_secretos; then chk "Git" "Ningún secreto (.env, kuma_password) está versionado" OK; else chk "Git" "Hay secretos versionados" FALLA; fi
  if [ -z "$(git -C "$REPO" status --short 2>/dev/null)" ]; then chk "Git" "Árbol de trabajo limpio" OK; else chk "Git" "Hay cambios sin commit" AVISO; fi
  chk "Git" "Rama actual: $(git -C "$REPO" branch --show-current 2>/dev/null)" OK

  if ./scripts/pruebas.sh >/dev/null 2>&1; then chk "Pruebas" "pruebas.sh: 9 de 9 aprobadas" OK; else chk "Pruebas" "pruebas.sh reporta fallas" FALLA; fi
  if reglas_prometheus | grep -q ServicioCaido; then chk "Alerta" "Regla ServicioCaido cargada" OK; else chk "Alerta" "Regla ServicioCaido no encontrada" AVISO; fi
  if ls "$RESP"/bd-*.sql.gz >/dev/null 2>&1; then chk "Respaldo" "Hay respaldos de la base en $RESP" OK; else chk "Respaldo" "No hay respaldos de la base" AVISO; fi
  if [ -n "$(sqlq "SELECT to_regclass('prueba_respaldo');")" ]; then chk "Respaldo" "Tabla de demostración prueba_respaldo existe" OK
  else chk "Respaldo" "La tabla prueba_respaldo no existe (la parte 4 la crea sola)" AVISO; fi

  printf '%s\n' "${CHK[@]}" | tabla "Resultado de la verificación" "Área|Comprobación|Estado"
  echo
  if [ "$AV" -eq 0 ]; then echo "  ${G}Todo listo para la sustentación.${N}"
  else echo "  ${Y}Hay $AV aviso(s) o falla(s) por revisar antes de empezar.${N}"; fi
}

# =============================================================================
#                              EJECUCIÓN
# =============================================================================
resumen_tiempos() {
  local i tot=0 u est
  echo
  {
    for i in 1 2 3 4; do
      u="${USADO[$i]:-0}"; tot=$(( tot + u ))
      est="En tiempo"
      [ "$u" -gt "${PRESUP[$i]}" ] && est="Excedida"
      [ "$u" -gt $(( PRESUP[i] * 13 / 10 )) ] && est="Muy excedida"
      printf '%s|%s|%s|%s|%s\n' "$i" "${NOMBRES[$i]}" "$(fmt "$u")" "$(fmt "${PRESUP[$i]}")" "$est"
    done
    printf 'Total||%s|13:00|\n' "$(fmt "$tot")"
  } | tabla "Resumen de tiempos (quedan 2 min para introducción y cierre)" "N.°|Parte|Usado|Sugerido|Resultado"
}

todo() {
  local i
  T0=$(ahora); USADO=()
  for i in 1 2 3 4; do
    "parte$i"
    [ "$i" -lt 4 ] && pausa
  done
  resumen_tiempos
}

menu() {
  local op
  while true; do
    limpiar
    echo
    {
      printf '1|Servicios y arquitectura|Servicios, puertos, volúmenes, redes y reinicio\n'
      printf '2|Pruebas de humo|Ejecuta las 9 pruebas y la falla provocada\n'
      printf '3|Alerta de monitoreo|Regla, objetivos y alerta en vivo\n'
      printf '4|Respaldo y restauración|Respaldo, desastre y recuperación\n'
      printf '5|Todo (partes 1 a 4)|Recorrido completo con cronómetro\n'
      printf '6|Preguntas del docente|Evidencia en vivo por tema\n'
      printf '7|Verificación previa|Comprueba que todo esté listo\n'
      printf '0|Salir|Cierra el programa\n'
    } | tabla "SUSTENTACIÓN FINAL · DEMOSTRACIÓN" "Opción|Qué hace|Detalle"
    echo
    printf '%s' "  Opción: "
    read -r op || exit 0
    case "$op" in
      1|2|3|4) T0=$(ahora); "parte$op"; pausa ;;
      5) todo; pausa ;;
      6) menu_preguntas ;;
      7) verificar; pausa ;;
      0) exit 0 ;;
      *) echo "  Opción no válida"; sleep 1 ;;
    esac
  done
}

# ----------------------------------------------------------------- inicio ----
if [ ! -d "$REPO" ]; then
  echo "${R}No existe $REPO. Ajusta la variable REPO.${N}"; exit 1
fi
cd "$REPO" || exit 1

case "${1:-menu}" in
  1|2|3|4)       T0=$(ahora); "parte$1" ;;
  todo|ensayo)   todo ;;
  preguntas)     menu_preguntas ;;
  verificar)     verificar ;;
  menu)          menu ;;
  *) echo "Uso: ./demo.sh [menu|1|2|3|4|todo|preguntas|verificar]"; exit 1 ;;
esac
