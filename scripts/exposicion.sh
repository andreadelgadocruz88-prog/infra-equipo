#!/usr/bin/env bash
# =============================================================================
#  exposicion.sh  -  Sustentación final del proyecto integrador (Semana 16)
#
#  Guía de presentación en pantalla. Cada paso muestra:
#    - Qué se verá          (descripción de lo que aparece en pantalla)
#    - Qué hace el código   (explicación del comando o script que se usa)
#    - Cómo se usó aquí     (cómo se aplicó en el proyecto)
#  y a continuación el resultado real en cuadros ordenados. Los datos se leen
#  en vivo desde Docker, Git y Prometheus: nada está escrito a mano.
#
#    presentacion : 10 partes guiadas (15 min), paso a paso
#    ensayo       : igual, con cronómetro y tiempo asignado por parte
#    preguntas    : preguntas del profesor, respuesta sugerida y evidencia
#    verificar    : revisión previa a la sustentación
#    parte N      : ejecuta solo la parte N (1 a 10)
#
#  Uso:   bash exposicion.sh            (menú)
#         bash exposicion.sh ensayo
#
#  Requiere una terminal con codificación UTF-8 (PuTTY: Window > Translation).
#  Variable opcional: EXPO_NOCLEAR=1 evita borrar la pantalla entre pasos.
#  Nunca muestra el contenido de .env ni de kuma_password.
# =============================================================================

REPO="${REPO:-$HOME/infra-equipo}"
COMPOSE_DIR="$REPO/compose"
RESP="$HOME/respaldos"
PROY="compose"
DB="compose-db-1"
URL_PR="https://github.com/andreadelgadocruz88-prog/infra-equipo/pull/2"
AUTORA="Andrea"
CURSO="Gestión de Plataformas y Servicios de TI"
INSTITUCION="IESTP Paiján"

ENSAYO=0
AV=0
T0=0
SEC=0
SEC_T0=0
SCR=0
AJ=""
CC=""
LINEAS=()
CHK=()

# La codificación debe ser UTF-8 para que los cuadros y las tildes se vean bien
if [ "$(locale charmap 2>/dev/null)" != "UTF-8" ]; then export LC_ALL=C.UTF-8; fi

declare -a PRESUP=(0 60 120 90 90 90 120 150 60 60 60)
declare -a USADO=()
declare -a NOMBRES=("" "Introducción y estructura" "Arquitectura y servicios" \
  "Persistencia y reinicio" "Pruebas de humo" "Falla provocada y recuperación" \
  "Alerta de monitoreo" "Respaldo y restauración" "Seguridad" \
  "Defectos y control de versiones" "Cierre")

# ---------------------------------------------------------------- colores ----
if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; M=$'\e[35m'; C=$'\e[36m'
  W=$'\e[1m'; D=$'\e[2m'; N=$'\e[0m'
else
  R=''; G=''; Y=''; B=''; M=''; C=''; W=''; D=''; N=''
fi

# --------------------------------------------------- ancho y caracteres ------
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

rep() { local s; printf -v s '%*s' "$(( $2 > 0 ? $2 : 0 ))" ''; printf '%s' "${s// /$1}"; }

# recorta un texto al ancho indicado (resultado en la variable AJ)
ajustar() {
  AJ="$1"
  if [ "${#AJ}" -gt "$2" ]; then AJ="${AJ:0:$(( $2 - 1 ))}…"; fi
}

# color según el contenido de la celda (resultado en la variable CC)
color_celda() {
  CC=""
  case "$1" in
    OK|healthy|UP|up|running|"Up "*|activo|inactive|"En tiempo"|"Detectada"|"Aprobada"|"unless-stopped"|always|"SIN ALERTA"|"Publicado") CC="$G" ;;
    unhealthy|DOWN|down|FALLA|FIRING|firing|Exited*|exited|FAILED|"Muy excedida") CC="$R" ;;
    PENDING|pending|starting|AVISO|"Excedida"|ninguna) CC="$Y" ;;
    "Interno"|"solo red interna"*) CC="$C" ;;
  esac
}

# divide un texto en líneas del ancho indicado (resultado en el arreglo LINEAS)
envolver() {
  local ancho="$1" texto="$2" sangria="" linea="" palabra
  local -a pal=()
  LINEAS=()
  case "$texto" in "• "*) sangria="  " ;; esac
  read -ra pal <<< "$texto"
  for palabra in "${pal[@]}"; do
    if [ -z "$linea" ]; then
      linea="$palabra"
    elif [ $(( ${#linea} + 1 + ${#palabra} )) -le "$ancho" ]; then
      linea+=" $palabra"
    else
      LINEAS+=("$linea"); linea="${sangria}${palabra}"
    fi
  done
  [ -n "$linea" ] && LINEAS+=("$linea")
  [ "${#LINEAS[@]}" -eq 0 ] && LINEAS=("")
}

# ------------------------------------------------------ elementos visuales ----
# panel "Título" "párrafo 1" "párrafo 2" ...   (color: variable PCOL)
panel() {
  local titulo="$1" col="${PCOL:-$C}" cw=$(( TW - 4 )) p linea rel pad
  shift
  rel=$(( TW - 5 - ${#titulo} )); [ "$rel" -lt 1 ] && rel=1
  printf '%s\n' "${col}${TL}${H} ${W}${titulo}${N}${col} $(rep "$H" "$rel")${TR}${N}"
  for p in "$@"; do
    envolver "$cw" "$p"
    for linea in "${LINEAS[@]}"; do
      printf -v pad '%*s' "$(( cw - ${#linea} > 0 ? cw - ${#linea} : 0 ))" ''
      printf '%s\n' "${col}${V}${N} ${linea}${pad} ${col}${V}${N}"
    done
  done
  printf '%s\n' "${col}${BL}$(rep "$H" $(( TW - 2 )))${BR}${N}"
}

# ficha "Etiqueta" "texto" "Etiqueta" "texto" ...   (cuadro de dos columnas)
ficha() {
  local col="${PCOL:-$B}" lw=0 cw i et1 lin pad1 pad2 primera
  local -a et=() tx=()
  while [ "$#" -ge 2 ]; do et+=("$1"); tx+=("$2"); shift 2; done
  for et1 in "${et[@]}"; do [ "${#et1}" -gt "$lw" ] && lw=${#et1}; done
  cw=$(( TW - 7 - lw ))
  printf '%s\n' "${col}${TL}$(rep "$H" $(( lw + 2 )))${TJ}$(rep "$H" $(( cw + 2 )))${TR}${N}"
  for i in "${!et[@]}"; do
    if [ "$i" -gt 0 ]; then
      printf '%s\n' "${col}${LJ}$(rep "$H" $(( lw + 2 )))${X}$(rep "$H" $(( cw + 2 )))${RJ}${N}"
    fi
    envolver "$cw" "${tx[$i]}"
    primera=1
    for lin in "${LINEAS[@]}"; do
      et1=""; [ "$primera" = 1 ] && et1="${et[$i]}"; primera=0
      printf -v pad1 '%*s' "$(( lw - ${#et1} ))" ''
      printf -v pad2 '%*s' "$(( cw - ${#lin} > 0 ? cw - ${#lin} : 0 ))" ''
      printf '%s\n' "${col}${V}${N} ${W}${et1}${N}${pad1} ${col}${V}${N} ${lin}${pad2} ${col}${V}${N}"
    done
  done
  printf '%s\n' "${col}${BL}$(rep "$H" $(( lw + 2 )))${BJ}$(rep "$H" $(( cw + 2 )))${BR}${N}"
}

# tabla "Título" "Enc1|Enc2|..."   (filas por la entrada estándar, columnas con |)
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
    [ "${anch[0]}" -lt 10 ] && anch[0]=10
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

# bloque_salida "Título" [n]   (muestra texto de la entrada estándar en un cuadro)
bloque_salida() {
  local titulo="$1" num="${2:-}" col="$D" cw=$(( TW - 4 )) linea n=1 txt rel pad vacio=1
  rel=$(( TW - 5 - ${#titulo} )); [ "$rel" -lt 1 ] && rel=1
  printf '%s\n' "${col}${TL}${H} ${N}${W}${titulo}${N}${col} $(rep "$H" "$rel")${TR}${N}"
  while IFS= read -r linea; do
    vacio=0
    linea="${linea//$'\t'/    }"
    if [ -n "$num" ]; then printf -v txt '%3d  %s' "$n" "$linea"; else txt="$linea"; fi
    n=$(( n + 1 ))
    ajustar "$txt" "$cw"; txt="$AJ"
    printf -v pad '%*s' "$(( cw - ${#txt} ))" ''
    printf '%s\n' "${col}${V}${N} ${txt}${pad} ${col}${V}${N}"
  done
  if [ "$vacio" = 1 ]; then
    txt="(sin salida)"; printf -v pad '%*s' "$(( cw - ${#txt} ))" ''
    printf '%s\n' "${col}${V}${N} ${txt}${pad} ${col}${V}${N}"
  fi
  printf '%s\n' "${col}${BL}$(rep "$H" $(( TW - 2 )))${BR}${N}"
}

comando() {
  echo
  echo "  ${D}Comando:${N} ${G}\$ $*${N}"
  echo
}

# ejecutar "texto visible" ["comando real"]: muestra el comando y lo ejecuta
ejecutar() {
  local visible="$1" real="${2:-$1}"
  comando "$visible"
  eval "$real"
  return $?
}

cabecera_parte() {
  local izq=" PARTE ${SEC} de 10 · ${NOMBRES[$SEC]} " der="" rel
  if [ "$ENSAYO" = 1 ]; then
    der=" asignado $(fmt "${PRESUP[$SEC]}") · parte $(fmt $(( $(ahora) - SEC_T0 ))) · total $(fmt $(( $(ahora) - T0 ))) "
  fi
  rel=$(( TW - ${#izq} - ${#der} - 2 )); [ "$rel" -lt 1 ] && rel=1
  printf '%s\n' "${W}${B}${HH}${izq}$(rep "$HH" "$rel")${der}${HH}${N}"
}

# inicio de una parte: pantalla de presentación con su descripción
seccion() {
  SEC="$1"; shift
  SEC_T0=$(ahora); SCR=0
  limpiar
  cabecera_parte
  echo
  PCOL=$C panel "De qué trata esta parte" "$@"
  SCR=1
}

pausa() {
  local extra=""
  [ "$ENSAYO" = 1 ] && extra="  ·  reloj $(fmt $(( $(ahora) - T0 )))"
  echo
  printf '%s' "${D}  ── Enter para continuar${extra} ──${N} "
  read -r _ || true
}

# nueva pantalla dentro de la parte (espera Enter y limpia)
pantalla() {
  if [ "$SCR" -gt 0 ]; then pausa; fi
  SCR=$(( SCR + 1 ))
  limpiar
  cabecera_parte
  echo
  echo "  ${W}${C}PASO ${SEC}.$(( SCR - 1 ))${N}  ${W}$1${N}"
  echo
}

confirmar() {
  local r
  printf '%s [S/n] ' "  ${Y}?${N} $1"
  read -r r || r=S
  case "$r" in n|N) return 1 ;; *) return 0 ;; esac
}

fin_seccion() {
  local t=$(( $(ahora) - SEC_T0 )) lim="${PRESUP[$SEC]}" col="$G"
  USADO[$SEC]=$t
  if [ "$ENSAYO" = 1 ]; then
    [ "$t" -gt "$lim" ] && col="$Y"
    [ "$t" -gt $(( lim * 13 / 10 )) ] && col="$R"
    echo
    echo "${col}  Parte $SEC: $(fmt "$t") usados de $(fmt "$lim") · total acumulado $(fmt $(( $(ahora) - T0 )))${N}"
  fi
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

datos_proyecto() {
  local remoto
  remoto=$(git -C "$REPO" remote get-url origin 2>/dev/null | sed -E 's#//[^@/]*@#//#')
  printf 'Proyecto|Plataforma TI integrada con Docker Compose\n'
  printf 'Módulo|%s\n' "$CURSO"
  printf 'Institución|%s\n' "$INSTITUCION"
  printf 'Presenta|%s\n' "$AUTORA"
  printf 'Servicios|8 contenedores: web, app, db, prometheus, grafana, node-exporter, uptime-kuma, cadvisor\n'
  printf 'Repositorio|%s\n' "${remoto:-no configurado}"
}

datos_entorno() {
  printf 'Usuario|%s\n' "$(whoami)"
  printf 'Equipo|%s\n' "$(hostname)"
  printf 'Dirección IP|%s\n' "$(hostname -I 2>/dev/null | awk '{print $1}')"
  printf 'Sistema operativo|%s\n' "$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-desconocido}")"
  printf 'Docker|%s\n' "$(docker --version 2>/dev/null | sed 's/^Docker version //')"
  printf 'Docker Compose|%s\n' "$(docker compose version 2>/dev/null | sed 's/^Docker Compose version //')"
  printf 'Fecha y hora|%s\n' "$(date '+%Y-%m-%d %H:%M')"
}

datos_agenda() {
  local i tot=0
  for i in 1 2 3 4 5 6 7 8 9 10; do
    printf '%s|%s|%s\n' "$i" "${NOMBRES[$i]}" "$(fmt "${PRESUP[$i]}")"
    tot=$(( tot + PRESUP[i] ))
  done
  printf 'Total||%s\n' "$(fmt "$tot")"
}

funcion_archivo() {
  case "$1" in
    README.md)                                echo "Presentación general del proyecto" ;;
    compose/docker-compose.yml)               echo "Define los 8 servicios, sus redes y volúmenes" ;;
    compose/monitoring/prometheus.yml)        echo "Configuración de Prometheus: qué vigila y cada cuánto" ;;
    compose/monitoring/alertas.yml)           echo "Regla de alerta ServicioCaido" ;;
    compose/monitoring/dashboard-monitoreo.json) echo "Dashboard de Grafana exportado" ;;
    scripts/pruebas.sh)                       echo "Pruebas de humo: 9 comprobaciones" ;;
    scripts/respaldo.sh)                      echo "Respaldo de documentos y base de datos, con huella sha256" ;;
    scripts/exposicion.sh)                    echo "Guía de esta sustentación" ;;
    docs/defectos.md)                         echo "Registro de defectos y su corrección" ;;
    docs/reflexion-semana15.md)               echo "Reflexión de la semana 15" ;;
    *)                                        echo "—" ;;
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

ubicacion_volumenes() {
  local v
  v=$(docker volume ls --filter "label=com.docker.compose.project=$PROY" --format '{{.Name}}' | head -n 1)
  [ -n "$v" ] && docker volume inspect -f '{{.Mountpoint}}' "$v" 2>/dev/null
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

datos_pruebas() {
  printf 'Nginx (web)|Respuesta HTTP|200\n'
  printf 'Adminer (app)|Estado de salud del contenedor|healthy\n'
  printf 'PostgreSQL (db)|Acepta conexiones (pg_isready)|listo\n'
  printf 'Prometheus|Respuesta HTTP|200\n'
  printf 'Objetivos de Prometheus|Objetivos activos|4 de 4\n'
  printf 'Grafana|Respuesta HTTP|200\n'
  printf 'node-exporter|Respuesta HTTP|200\n'
  printf 'Uptime Kuma|Respuesta HTTP (redirección)|302\n'
  printf 'cAdvisor|Respuesta HTTP (redirección)|307\n'
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

datos_commits() { git log --date=short --format='%h|%ad|%s' -n "${1:-14}" 2>/dev/null; }

datos_git() {
  local rama pend
  rama=$(git branch --show-current 2>/dev/null)
  pend=$(git status --short 2>/dev/null | wc -l)
  printf 'Rama actual|%s\n' "${rama:-?}"
  printf 'Commits de la rama respecto a main|%s\n' "$(git rev-list --count main..HEAD 2>/dev/null || echo '?')"
  if [ "$pend" -eq 0 ]; then printf 'Cambios sin guardar|Ninguno (árbol de trabajo limpio)\n'; else printf 'Cambios sin guardar|%s archivo(s)\n' "$pend"; fi
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
  else printf 'Cortafuegos UFW|N/D|Requiere sudo (ejecutar antes: sudo ufw status)\n'; fi
}

datos_resumen() {
  local tot san est u n
  tot=$(docker ps --filter "label=com.docker.compose.project=$PROY" -q | wc -l)
  san=$(docker ps --filter "label=com.docker.compose.project=$PROY" --filter health=healthy -q | wc -l)
  if [ "$san" -eq 8 ]; then est=OK; else est=AVISO; fi
  printf 'Servicios healthy|%s de 8 (en ejecución: %s)|%s\n' "$san" "$tot" "$est"
  if ./scripts/pruebas.sh >/dev/null 2>&1; then printf 'Pruebas de humo|9 de 9 aprobadas|OK\n'; else printf 'Pruebas de humo|Con fallas|FALLA\n'; fi
  if reglas_prometheus | grep -q ServicioCaido; then printf 'Alerta ServicioCaido|Cargada en Prometheus|OK\n'; else printf 'Alerta ServicioCaido|No encontrada|AVISO\n'; fi
  u=$(ls -t "$RESP"/bd-*.sql.gz 2>/dev/null | head -n 1)
  if [ -n "$u" ]; then printf 'Último respaldo de la base|%s|OK\n' "$(basename "$u")"; else printf 'Último respaldo de la base|No hay respaldos|AVISO\n'; fi
  if comprobar_secretos; then printf 'Secretos en Git|Ninguno versionado|OK\n'; else printf 'Secretos en Git|Hay secretos versionados|FALLA\n'; fi
  n=$(git rev-list --count main..HEAD 2>/dev/null || echo '?')
  printf 'Commits de la rama|%s|OK\n' "$n"
}

# =============================================================================
#                            LAS 10 PARTES
# =============================================================================
parte1() {
  seccion 1 \
    "Esta sustentación recorre el proyecto integrador completo: una plataforma de TI formada por 8 servicios que corren en contenedores con Docker Compose. Incluye monitoreo con alertas, pruebas automáticas, respaldo con restauración comprobada y toda la documentación en Git." \
    "Todo lo que se muestra se lee en vivo desde la máquina virtual: los puertos, volúmenes y redes se consultan a Docker en el momento, no están escritos a mano." \
    "En esta primera parte se verá:" \
    "• La ficha del proyecto y el entorno donde funciona." \
    "• La agenda de la demostración." \
    "• Cómo está organizado el repositorio."

  pantalla "Ficha del proyecto y entorno de ejecución"
  ficha \
    "Qué se verá" "Los datos generales del proyecto y las características de la máquina donde se ejecuta: usuario, equipo, dirección IP, sistema operativo y versiones de Docker y Compose." \
    "Qué hace el código" "La función datos_entorno consulta el sistema con comandos estándar (whoami, hostname, /etc/os-release, docker --version) y la tabla ordena los resultados en pares dato-valor." \
    "Cómo se usó aquí" "La plataforma corre en una máquina virtual Ubuntu en VirtualBox, a la que se accede por SSH. Docker y Docker Compose son la única dependencia: con ellos se levanta todo el proyecto."
  echo
  datos_proyecto | tabla "Ficha del proyecto" "Dato|Valor"
  comando "whoami · hostname · cat /etc/os-release · docker --version · docker compose version"
  datos_entorno | tabla "Entorno de ejecución" "Dato|Valor"

  pantalla "Agenda de la demostración"
  ficha \
    "Qué se verá" "Las 10 partes de la sustentación con el tiempo asignado a cada una, que suman 15 minutos." \
    "Qué hace el código" "El arreglo PRESUP guarda los segundos asignados a cada parte; la función fmt los convierte a formato minutos:segundos." \
    "Cómo se usó aquí" "El modo ensayo usa estos mismos tiempos para mostrar un cronómetro y avisar, en verde, amarillo o rojo, si una parte se está pasando."
  echo
  datos_agenda | tabla "Agenda (15 minutos)" "N.°|Parte|Tiempo"

  pantalla "Estructura del repositorio"
  ficha \
    "Qué se verá" "Los archivos del repositorio infra-equipo, organizados por carpeta, con una descripción de para qué sirve cada uno." \
    "Qué hace el comando" "find recorre las carpetas compose, scripts y docs y lista solo archivos (-type f), dejando fuera los secretos; sort los ordena. La descripción de cada archivo se asigna según su ruta." \
    "Cómo se usó aquí" "Todo está ordenado por función: compose/ contiene la infraestructura, scripts/ las pruebas y el respaldo, docs/ la documentación y semana09/ la automatización inicial."
  echo
  comando "find compose scripts docs -type f | sort"
  datos_estructura | tabla "Contenido del repositorio" "Archivo|Para qué sirve"
  echo
  PCOL=$Y panel "Archivos que no se muestran" \
    "Los archivos .env y kuma_password existen en la VM pero no se listan ni se suben a Git: contienen datos sensibles."
}

parte2() {
  seccion 2 \
    "Docker Compose describe toda la plataforma en un único archivo y la levanta con un solo comando. Esta parte muestra cómo quedó armada: qué servicios la forman, por qué puertos se accede a cada uno y cómo se comunican entre sí por las redes internas." \
    "En esta parte se verá:" \
    "• Los 8 servicios, su función y su estado de salud." \
    "• Los puertos publicados y los que se mantienen internos." \
    "• Las redes que separan la aplicación del monitoreo."

  pantalla "Servicios en ejecución"
  ficha \
    "Qué se verá" "Una tabla con los 8 servicios del proyecto: para qué sirve cada uno, la imagen de Docker de la que parte y su estado actual." \
    "Qué hace el comando" "docker ps -a, filtrado por la etiqueta com.docker.compose.project=$PROY, lista solo los contenedores del proyecto. Luego docker inspect completa el estado de salud que reportan los healthchecks." \
    "Cómo se usó aquí" "Cada servicio tiene un healthcheck: Docker comprueba cada cierto tiempo que el servicio realmente responda, no solo que el proceso esté vivo. Un servicio en 'healthy' está funcionando de verdad."
  comando "docker ps -a --filter label=com.docker.compose.project=$PROY  +  docker inspect"
  datos_servicios | tabla "Servicios del proyecto" "Servicio|Función|Imagen|Estado"

  pantalla "Puertos publicados y puertos internos"
  ficha \
    "Qué se verá" "Qué puerto de la máquina virtual corresponde a cada servicio, a qué puerto interno del contenedor apunta y la dirección para abrirlo en el navegador." \
    "Qué hace el comando" "docker port consulta a Docker los puertos realmente publicados, sin escribirlos a mano. Para los servicios que no publican puerto se leen sus puertos internos con docker inspect." \
    "Cómo se usó aquí" "Solo se publican los servicios que una persona necesita abrir: web, Prometheus, Grafana, Uptime Kuma, cAdvisor y node-exporter. La aplicación (app) y la base de datos (db) no publican puerto: solo se alcanzan desde la red interna de Docker. Es una decisión de seguridad que reduce la superficie de ataque."
  comando "docker port <contenedor>   (uno por servicio)"
  datos_puertos | tabla "Puertos del proyecto" "Servicio|Puerto en la VM|Puerto interno|Acceso|Exposición"
  echo
  datos_accesos | tabla "Para abrir en el navegador" "Herramienta|Dirección"

  pantalla "Redes internas"
  ficha \
    "Qué se verá" "Las redes que Docker creó para el proyecto y qué servicios están conectados a cada una." \
    "Qué hace el comando" "docker network ls filtra las redes del proyecto y docker network inspect indica el tipo de red y los contenedores conectados." \
    "Cómo se usó aquí" "Se separaron dos redes: red-app para la aplicación y red-monitoreo para la observabilidad, de modo que cada servicio solo alcance lo que necesita. Dentro de una red, Docker ofrece un DNS interno: un contenedor llama a otro por el nombre de su servicio (por ejemplo, Prometheus consulta a node-exporter)."
  comando "docker network ls  +  docker network inspect <red>"
  datos_redes | tabla "Redes del proyecto" "Red|Tipo|Servicios conectados|N.°"
}

parte3() {
  seccion 3 \
    "Un contenedor es descartable: si se elimina o se recrea, lo que tenía dentro desaparece. Los datos, en cambio, deben sobrevivir. Esta parte muestra cómo se logra con volúmenes con nombre y cómo la política de reinicio hace que la plataforma se recupere sola tras reiniciar la máquina." \
    "En esta parte se verá:" \
    "• Los volúmenes que guardan los datos y quién los usa." \
    "• La política de reinicio y la salud de cada servicio." \
    "• La prueba real de reinicio de la máquina virtual."

  pantalla "Volúmenes de datos"
  ficha \
    "Qué se verá" "Los volúmenes que guardan los datos de la base, Grafana, Uptime Kuma y Prometheus, y qué servicio usa cada uno." \
    "Qué hace el comando" "docker volume ls filtra los volúmenes del proyecto; docker ps --filter volume=<nombre> averigua qué contenedores los montan; docker volume inspect revela su ubicación física." \
    "Cómo se usó aquí" "Cada servicio con datos importantes guarda su información en un volumen. Si el contenedor se borra, los datos siguen ahí. Por eso nunca se usa 'docker compose down -v', que sí eliminaría los volúmenes."
  comando "docker volume ls --filter label=com.docker.compose.project=$PROY"
  datos_volumenes | tabla "Volúmenes del proyecto" "Volumen|Usado por|Qué guarda|Tipo"
  echo
  local mp; mp=$(ubicacion_volumenes)
  PCOL=$C panel "Dónde viven los datos" \
    "Los volúmenes están en el disco de la máquina virtual, fuera del contenedor. Ejemplo de ubicación real: ${mp:-/var/lib/docker/volumes/<nombre>/_data}"

  pantalla "Política de reinicio y salud"
  ficha \
    "Qué se verá" "Para cada servicio: su política de reinicio, su estado de salud, cuántas veces Docker lo ha reiniciado y desde cuándo está en marcha." \
    "Qué hace el comando" "docker inspect lee la configuración (RestartPolicy) y el estado (Health, RestartCount, StartedAt) de cada contenedor." \
    "Cómo se usó aquí" "Los 8 servicios usan 'restart: unless-stopped': Docker los vuelve a levantar si caen o si se reinicia la VM, salvo que se detengan a mano. Antes algunos tenían la política 'no' y quedaban apagados tras reiniciar (estado Exited 255): ese fue el defecto D-01."
  comando "docker inspect -f '{{.HostConfig.RestartPolicy.Name}} ...' <contenedor>"
  datos_politicas | tabla "Reinicio automático y salud" "Servicio|Reinicio automático|Salud|Estado|Reinicios|Iniciado (UTC)"

  pantalla "Prueba de reinicio de la máquina virtual"
  ficha \
    "Qué se verá" "Desde cuándo está encendida la máquina virtual y la anotación escrita de la prueba de reinicio que se hizo." \
    "Qué hace el comando" "uptime -s indica el momento del último arranque; grep -i busca en docs/defectos.md la línea donde quedó registrada la prueba." \
    "Cómo se usó aquí" "Se reinició la VM a propósito y se comprobó que los 8 servicios volvieron solos, sin intervención. El resultado quedó documentado con su fecha."
  echo
  datos_reinicio_vm | tabla "Estado de la máquina" "Dato|Valor"
  comando "grep -i -n 'prueba de reinicio' docs/defectos.md"
  grep -i -n 'prueba de reinicio' docs/defectos.md 2>/dev/null | bloque_salida "docs/defectos.md"
}

parte4() {
  seccion 4 \
    "Una prueba de humo comprueba lo esencial de cada servicio: que responda. Ver un contenedor en estado 'Up' no alcanza, porque un proceso puede estar vivo y no atender. Esta parte presenta el script de pruebas, qué verifica y su ejecución en vivo." \
    "En esta parte se verá:" \
    "• Qué comprueba cada una de las 9 pruebas." \
    "• La revisión de sintaxis del script." \
    "• La ejecución real y su código de salida."

  pantalla "Qué comprueba cada prueba"
  ficha \
    "Qué se verá" "La lista de las 9 comprobaciones que ejecuta scripts/pruebas.sh y el resultado que se espera de cada una." \
    "Qué hace el código" "El script consulta cada servicio (código HTTP, estado de salud o pg_isready) y compara lo obtenido con el valor esperado. Un código 302 o 307 es una redirección, normal en Uptime Kuma y cAdvisor." \
    "Cómo se usó aquí" "Se diseñó una prueba por servicio. Si alguna falla, el script termina con código de salida 1; si todas pasan, con 0. Ese código permite automatizar el control."
  echo
  datos_pruebas | tabla "Pruebas de humo" "Servicio|Qué se comprueba|Resultado esperado"

  pantalla "Revisión del script"
  ficha \
    "Qué se verá" "La verificación de sintaxis del script de pruebas y su tamaño." \
    "Qué hace el comando" "bash -n lee el script sin ejecutarlo y avisa si tiene errores de escritura; wc -l cuenta sus líneas." \
    "Cómo se usó aquí" "Antes de ejecutar cualquier script se revisa su sintaxis: es una buena práctica que evita fallos a mitad de una prueba."
  comando "bash -n scripts/pruebas.sh  ·  wc -l scripts/pruebas.sh"
  {
    if bash -n scripts/pruebas.sh 2>/dev/null; then printf 'Sintaxis|OK\n'; else printf 'Sintaxis|FALLA\n'; fi
    printf 'Líneas de código|%s\n' "$(wc -l < scripts/pruebas.sh 2>/dev/null)"
  } | tabla "Revisión de scripts/pruebas.sh" "Verificación|Resultado"

  pantalla "Ejecución en vivo"
  ficha \
    "Qué se verá" "La salida completa de las pruebas, servicio por servicio, y el código de salida con el que termina el script." \
    "Qué hace el comando" "./scripts/pruebas.sh ejecuta las 9 comprobaciones y devuelve 0 si todas pasan o 1 si alguna falla. El código se lee con la variable \$?." \
    "Cómo se usó aquí" "Se ejecutó después de cada cambio importante (pruebas de regresión) para confirmar que una corrección no rompió otra cosa: 9 de 9 aprobadas y código 0."
  ejecutar "./scripts/pruebas.sh" "./scripts/pruebas.sh"
  local rc=$?
  echo
  printf 'Código de salida|%s|%s\n' "$rc" "$(rc_texto "$rc")" | tabla "Resultado" "Dato|Valor|Interpretación"
}

parte5() {
  seccion 5 \
    "Una prueba que nunca falla no demuestra nada. Para comprobar que las pruebas realmente detectan problemas, se apaga a propósito un servicio (Grafana), se observa cómo el script lo detecta y luego se recupera el servicio." \
    "Atención: esta parte modifica el estado de la plataforma. Pedirá confirmación antes de empezar y, si se interrumpe con Ctrl+C, vuelve a encender Grafana." \
    "En esta parte se verá:" \
    "• La falla provocada y su detección por las pruebas." \
    "• La recuperación del servicio." \
    "• Una tabla comparativa de ambos resultados."

  pantalla "Provocar la falla: apagar Grafana"
  ficha \
    "Qué se verá" "Se detiene el servicio de Grafana y se ejecutan las pruebas de humo. Lo esperado es que falle únicamente la prueba de Grafana y que las otras 8 sigan aprobadas." \
    "Qué hace el comando" "docker compose stop grafana apaga solo ese contenedor, sin tocar los demás ni borrar sus datos. Después pruebas.sh detecta que el puerto 3000 ya no responde (código 000 en lugar de 200) y termina con código 1." \
    "Cómo se usó aquí" "Así se demuestra que las pruebas son confiables: la falla queda aislada en un solo servicio y el código de salida distinto de cero permite detectarla de forma automática."
  echo
  if ! confirmar "¿Apagar Grafana para provocar la falla?"; then
    PCOL=$Y panel "Parte omitida" "La demostración de falla fue omitida por decisión del presentador."
    return
  fi
  trap 'echo; echo "Interrumpido: restaurando Grafana..."; dc start grafana >/dev/null 2>&1; exit 130' INT
  ejecutar "docker compose stop grafana" "dc stop grafana"
  ejecutar "./scripts/pruebas.sh" "./scripts/pruebas.sh"
  local rc1=$?

  pantalla "Recuperación del servicio"
  ficha \
    "Qué se verá" "Se vuelve a encender Grafana, se espera a que responda y se repiten las pruebas. Lo esperado es volver a 9 de 9 y código 0." \
    "Qué hace el comando" "docker compose start grafana reanuda el contenedor; la espera consulta http://localhost:3000/login hasta recibir el código 200." \
    "Cómo se usó aquí" "Los dashboards siguen disponibles porque Grafana guarda sus datos en un volumen (defecto D-03 corregido): recuperar el servicio no significa perder la configuración."
  ejecutar "docker compose start grafana" "dc start grafana"
  esperar_http "http://localhost:3000/login" 120
  ejecutar "./scripts/pruebas.sh" "./scripts/pruebas.sh"
  local rc2=$?
  trap - INT

  pantalla "Resultado comparado"
  ficha \
    "Qué se verá" "Una tabla que resume lo ocurrido en cada fase, con el código de salida de las pruebas." \
    "Qué hace el código" "Cada ejecución de pruebas.sh guardó su código de salida en una variable; la tabla los compara." \
    "Cómo se usó aquí" "Con la falla provocada el código fue distinto de cero (la prueba detectó el problema); tras recuperar el servicio volvió a 0."
  echo
  {
    printf 'Falla provocada (Grafana apagado)|%s|%s|%s\n' "$rc1" "$(rc_texto "$rc1")" "$([ "$rc1" -ne 0 ] && echo Detectada || echo AVISO)"
    printf 'Servicio recuperado|%s|%s|%s\n' "$rc2" "$(rc_texto "$rc2")" "$([ "$rc2" -eq 0 ] && echo Aprobada || echo AVISO)"
  } | tabla "Comparación de fases" "Fase|Código de salida|Interpretación|Estado"
}

parte6() {
  seccion 6 \
    "El monitoreo no sirve si nadie se entera de una caída. Esta parte muestra la regla de alerta definida en Prometheus, las reglas y objetivos que tiene cargados y, de forma opcional, cómo la alerta se activa en vivo al apagar un servicio." \
    "En esta parte se verá:" \
    "• El archivo donde está escrita la regla de alerta." \
    "• Las reglas y los objetivos que Prometheus tiene cargados." \
    "• La alerta en vivo, con su paso de PENDING a FIRING (opcional)."

  pantalla "La regla de alerta"
  ficha \
    "Qué se verá" "El contenido del archivo alertas.yml, donde está escrita la regla de alerta." \
    "Qué hace el código" "La regla ServicioCaido evalúa la métrica 'up', que vale 1 cuando Prometheus logra consultar un servicio y 0 cuando no. Si 'up' vale 0 durante 1 minuto seguido, la alerta se activa con severidad crítica; el resumen indica el nombre del servicio caído." \
    "Cómo se usó aquí" "Como la métrica 'up' existe para cada objetivo monitoreado, la misma regla sirve para vigilar a cualquiera de ellos."
  comando "cat compose/monitoring/alertas.yml"
  sed -n '1,40p' compose/monitoring/alertas.yml 2>/dev/null | bloque_salida "compose/monitoring/alertas.yml" n

  pantalla "Reglas y objetivos cargados en Prometheus"
  ficha \
    "Qué se verá" "Las reglas que Prometheus tiene cargadas con su estado actual, y la lista de objetivos que vigila con su salud." \
    "Qué hace el comando" "Se consulta la API de Prometheus (/api/v1/rules y /api/v1/targets) y la respuesta en formato JSON se ordena en tablas." \
    "Cómo se usó aquí" "Prometheus consulta a cada objetivo cada 15 segundos. Si uno deja de responder, su salud pasa a 'down' y la métrica 'up' cae a 0, que es justo lo que la regla vigila."
  comando "curl localhost:9090/api/v1/rules"
  reglas_prometheus | tabla "Reglas de alerta" "Grupo|Regla|Estado|Duración|Severidad"
  comando "curl localhost:9090/api/v1/targets"
  objetivos_prometheus | tabla "Objetivos monitoreados" "Job|Dirección|Salud"
  echo
  PCOL=$Y panel "Limitación conocida" \
    "La plataforma no incluye Alertmanager: la alerta se ve en Prometheus (menú Estado > Alertas) pero no envía ningún aviso. Mejora propuesta: Alertmanager con correo, o un flujo de n8n."

  pantalla "Alerta en vivo (opcional)"
  ficha \
    "Qué se verá" "Se apaga node-exporter y se observa cómo la alerta pasa de sin alerta a PENDING y luego a FIRING. El proceso tarda cerca de un minuto y medio." \
    "Qué hace el comando" "docker compose stop node-exporter apaga el exportador; cada 10 segundos se consulta /api/v1/alerts para registrar el estado de la alerta." \
    "Cómo se usó aquí" "PENDING significa que la condición ya se cumple pero aún no pasó el minuto exigido; FIRING indica que la alerta está activa. En el navegador se ve lo mismo en la página de alertas de Prometheus (puerto 9090)."
  echo
  if ! confirmar "¿Provocar la alerta apagando node-exporter (tarda ~1,5 min)?"; then
    PCOL=$Y panel "Demostración omitida" "La alerta en vivo fue omitida por decisión del presentador."
    return
  fi
  trap 'echo; echo "Interrumpido: restaurando node-exporter..."; dc start node-exporter >/dev/null 2>&1; exit 130' INT
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
  estado_alertas | tabla "Alertas activas tras recuperar el servicio" "Alerta|Estado|Job"
}

parte7() {
  seccion 7 \
    "Un respaldo que nunca se restauró no es un respaldo. Esta parte recorre el ciclo completo: crear los respaldos, comprobar su integridad, provocar la pérdida de datos y recuperarlos." \
    "Atención: se borra y se restaura una tabla de demostración (prueba_respaldo), creada solo para esta prueba." \
    "En esta parte se verá:" \
    "• El script de respaldo y lo que genera." \
    "• El estado inicial de los datos." \
    "• La creación del respaldo y la comprobación de su huella sha256." \
    "• El desastre simulado y la restauración de la base." \
    "• La restauración de los documentos."

  pantalla "El script de respaldo"
  ficha \
    "Qué se verá" "Las primeras líneas de scripts/respaldo.sh, el programa que genera los respaldos." \
    "Qué hace el código" "Crea tres cosas: un archivo comprimido (tar.gz) con la carpeta ~/documentos, un volcado de la base de datos (pg_dump) comprimido en .sql.gz, y una huella sha256 de cada archivo para comprobar después que no se alteró ni se corrompió." \
    "Cómo se usó aquí" "Los respaldos se guardan en ~/respaldos con la fecha en el nombre. Además existe una tarea programada diaria (cron, 0 14 * * *) con el script de la semana 9."
  comando "sed -n '1,30p' scripts/respaldo.sh"
  sed -n '1,30p' scripts/respaldo.sh 2>/dev/null | bloque_salida "scripts/respaldo.sh (líneas 1 a 30)" n

  pantalla "Estado inicial de los datos"
  ficha \
    "Qué se verá" "El contenido actual de la tabla de demostración prueba_respaldo, que servirá como punto de comparación." \
    "Qué hace el comando" "docker exec ejecuta psql dentro del contenedor de PostgreSQL con una consulta SELECT. Las credenciales las toma del propio contenedor, no están escritas en el script." \
    "Cómo se usó aquí" "La tabla se crea sola si no existe, con 3 registros. Es una tabla de prueba: permite destruirla y recuperarla sin riesgo para datos reales."
  preparar_tabla
  comando "SELECT id, valor FROM prueba_respaldo;"
  sqlt "SELECT id, valor FROM prueba_respaldo ORDER BY id;" | tabla "Tabla prueba_respaldo (antes)" "id|valor"
  local n0; n0=$(filas_demo)

  pantalla "Crear el respaldo y comprobar su integridad"
  ficha \
    "Qué se verá" "La ejecución del script de respaldo, los archivos que genera y la comprobación de su huella sha256." \
    "Qué hace el comando" "bash scripts/respaldo.sh crea los archivos; sha256sum -c recalcula la huella de cada uno y la compara con la guardada. 'OK' significa que el archivo está intacto." \
    "Cómo se usó aquí" "Verificar la huella permite confiar en que el respaldo no está corrupto antes de llegar a necesitarlo."
  ejecutar "bash scripts/respaldo.sh"
  echo
  datos_respaldos | tabla "Archivos más recientes en ~/respaldos" "Archivo|Tipo|Tamaño|Creado"
  comando "sha256sum -c <archivo>.sha256"
  datos_hashes | tabla "Comprobación de integridad" "Archivo|Resultado"

  pantalla "Simular el desastre"
  ficha \
    "Qué se verá" "Se elimina la tabla de demostración y se intenta consultarla: debe aparecer un error porque los datos se perdieron." \
    "Qué hace el comando" "DROP TABLE borra la tabla y sus datos. La consulta SELECT posterior falla con el mensaje 'relation does not exist' (la relación no existe)." \
    "Cómo se usó aquí" "Esto reproduce una pérdida real de información, para demostrar enseguida que el respaldo permite recuperarla."
  ejecutar "DROP TABLE prueba_respaldo;" 'sql "DROP TABLE prueba_respaldo;"'
  ejecutar "SELECT * FROM prueba_respaldo;" 'sql "SELECT * FROM prueba_respaldo;" 2>&1'
  local n1; n1=$(filas_demo)

  pantalla "Restaurar la base desde el respaldo"
  ficha \
    "Qué se verá" "La restauración de la base de datos desde el respaldo más reciente y el resultado de volver a consultar la tabla." \
    "Qué hace el comando" "zcat descomprime el archivo .sql.gz y envía su contenido a psql, que vuelve a crear la tabla (CREATE TABLE) y a cargar sus registros (COPY)." \
    "Cómo se usó aquí" "Es el procedimiento real de recuperación ante un desastre: no requiere herramientas especiales, solo el archivo de respaldo."
  local otras
  otras=$(sqlq "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name<>'prueba_respaldo';")
  if [ "${otras:-0}" != "0" ]; then
    echo
    PCOL=$Y panel "Precaución" \
      "La base tiene $otras tabla(s) además de la de demostración. Restaurar el respaldo completo sobre la base en uso podría duplicar sus datos."
    echo
    if ! confirmar "¿Restaurar de todos modos?"; then
      PCOL=$Y panel "Restauración omitida" "Se omitió la restauración para no afectar las demás tablas."
      return
    fi
  fi
  ejecutar "zcat bd-FECHA.sql.gz | psql" "restaurar_bd"
  local n2; n2=$(filas_demo)
  echo
  sqlt "SELECT id, valor FROM prueba_respaldo ORDER BY id;" | tabla "Tabla prueba_respaldo (después de restaurar)" "id|valor"
  echo
  {
    printf 'Antes del desastre|%s|OK\n' "${n0:-?}"
    printf 'Tras borrar la tabla|%s|FALLA\n' "${n1:-tabla inexistente}"
    if [ -n "$n2" ] && [ "$n2" = "$n0" ]; then printf 'Tras restaurar el respaldo|%s|OK\n' "$n2"
    else printf 'Tras restaurar el respaldo|%s|AVISO\n' "${n2:-sin datos}"; fi
  } | tabla "Resumen del ciclo de respaldo y restauración" "Momento|Filas en la tabla|Estado"

  pantalla "Restaurar los documentos"
  ficha \
    "Qué se verá" "La extracción del último respaldo de documentos en una carpeta temporal y la lista de archivos recuperados." \
    "Qué hace el comando" "tar -xzf descomprime el archivo docs-FECHA.tar.gz dentro de /tmp/restauracion; find lista lo que contiene." \
    "Cómo se usó aquí" "Así se comprueba que el respaldo de documentos también se puede abrir y que los archivos están completos."
  ejecutar "tar -xzf docs-FECHA.tar.gz -C /tmp/restauracion" "restaurar_docs"
  echo
  datos_docs_restaurados | tabla "Archivos recuperados (primeros 15)" "Ruta|Tamaño"
}

parte8() {
  seccion 8 \
    "La seguridad del proyecto se trabajó en cuatro frentes: manejo de secretos, permisos de archivos, puertos expuestos y cortafuegos. En esta parte cada medida se comprueba en vivo, en lugar de solo afirmarla." \
    "En esta parte se verá:" \
    "• Un panel con las medidas de seguridad y su comprobación." \
    "• La clave de Uptime Kuma y el defecto D-02." \
    "• Los puertos expuestos y el defecto D-04."

  pantalla "Panel de seguridad"
  ficha \
    "Qué se verá" "Una tabla con las medidas de seguridad aplicadas y el resultado de comprobarlas en este momento." \
    "Qué hace el código" "Cada fila ejecuta una verificación real: git ls-files revisa qué archivos se versionan, git check-ignore confirma que .gitignore protege los secretos, grep busca la configuración y docker port muestra si la base publica algún puerto." \
    "Cómo se usó aquí" "Los secretos (.env y kuma_password) existen en la VM pero nunca se suben a GitHub. La base de datos no publica puertos: solo se accede a ella desde la red interna."
  echo
  datos_seguridad | tabla "Medidas de seguridad" "Medida|Estado|Evidencia"

  pantalla "La clave de Uptime Kuma (defecto D-02)"
  ficha \
    "Qué se verá" "La parte del archivo prometheus.yml donde Prometheus obtiene la clave para consultar a Uptime Kuma, y los permisos del archivo que la guarda." \
    "Qué hace el comando" "grep -n -B2 -A2 password_file localiza la línea que indica a Prometheus que lea la clave desde un archivo; stat muestra los permisos de ese archivo." \
    "Cómo se usó aquí" "Defecto D-02: la clave estaba escrita en texto plano dentro de prometheus.yml. Ahora Prometheus la lee de un archivo (password_file) que no se versiona, y además se rotó: se generó una clave nueva y se descartó la anterior. El archivo tiene permisos 644 a propósito: Prometheus corre con otro usuario dentro del contenedor y con 600 no podría leerlo."
  comando "grep -n -B2 -A2 'password_file' compose/monitoring/prometheus.yml"
  grep -n -B2 -A2 'password_file' compose/monitoring/prometheus.yml 2>/dev/null | bloque_salida "compose/monitoring/prometheus.yml"
  echo
  comando "stat compose/monitoring/kuma_password   (el contenido no se muestra)"
  stat -c '%n|%a|%U|%s bytes' compose/monitoring/kuma_password 2>/dev/null | tabla "Archivo de la clave" "Archivo|Permisos|Propietario|Tamaño"

  pantalla "Puertos expuestos y cortafuegos (defecto D-04)"
  ficha \
    "Qué se verá" "Los puertos que quedan abiertos hacia afuera, el estado del cortafuegos UFW y lo que quedó documentado sobre el defecto D-04." \
    "Qué hace el comando" "docker port lista lo publicado; sudo ufw status muestra las reglas del cortafuegos (si pide contraseña, se omite); grep busca el registro del defecto en docs/defectos.md." \
    "Cómo se usó aquí" "Defecto D-04: Docker publica puertos modificando iptables, por lo que puede saltarse las reglas de UFW. Se documentó: lo que publica Docker no lo controla UFW. Por eso la medida más efectiva es no publicar lo que no hace falta."
  datos_puertos | tabla "Puertos que ve el exterior" "Servicio|Puerto en la VM|Puerto interno|Acceso|Exposición"
  comando "sudo ufw status"
  sudo -n ufw status 2>/dev/null | bloque_salida "Estado de UFW"
  comando "grep -n 'D-04' docs/defectos.md"
  grep -n 'D-04' docs/defectos.md 2>/dev/null | head -n 3 | bloque_salida "docs/defectos.md"
}

parte9() {
  seccion 9 \
    "Cada problema encontrado durante el proyecto se registró, se corrigió con un commit y se verificó. Esta parte muestra el registro de defectos, el historial de commits en Git y el flujo de trabajo con ramas y Pull Request." \
    "En esta parte se verá:" \
    "• El registro de defectos y su corrección." \
    "• El estado de Git y el historial de commits." \
    "• El Pull Request y los cambios que contiene."

  pantalla "Registro de defectos"
  ficha \
    "Qué se verá" "Los defectos registrados en docs/defectos.md junto con la corrección aplicada a cada uno." \
    "Qué hace el comando" "grep localiza los títulos con la forma '## D-xx' y sed separa el identificador del título para ordenarlos en columnas." \
    "Cómo se usó aquí" "Cada defecto tiene un identificador, una descripción y una corrección. Registrarlos demuestra que probar de verdad (reiniciar la VM, apagar servicios, restaurar) revela problemas que no se ven al construir."
  comando "grep -n '^## D-' docs/defectos.md"
  datos_defectos | tabla "Defectos detectados y corregidos" "ID|Defecto|Corrección aplicada"

  pantalla "Control de versiones con Git"
  ficha \
    "Qué se verá" "La rama de trabajo, el estado del repositorio y los últimos commits." \
    "Qué hace el comando" "git branch --show-current, git status --short y git log --format entregan la rama actual, los cambios pendientes y el historial." \
    "Cómo se usó aquí" "Se trabaja en una rama de funcionalidad con commits pequeños y un prefijo que indica su tipo: feat, fix, test o docs. Cada commit hace una sola cosa."
  echo
  datos_git | tabla "Estado del repositorio" "Dato|Valor"
  comando "git log --date=short --format='%h|%ad|%s' -n 14"
  datos_commits 14 | tabla "Últimos commits" "Commit|Fecha|Mensaje"

  pantalla "Pull Request"
  ficha \
    "Qué se verá" "El resumen de archivos modificados respecto a main y la dirección del Pull Request." \
    "Qué hace el comando" "git diff --stat main...HEAD compara la rama con main y cuenta las líneas cambiadas por archivo." \
    "Cómo se usó aquí" "El Pull Request #2 propone fusionar la rama en main para que sea revisada antes. Antes de fusionar se revisó la pestaña 'Files changed' para confirmar que no se subió ningún secreto."
  comando "git diff --stat main...HEAD"
  git diff --stat main...HEAD 2>/dev/null | tail -n 14 | bloque_salida "Cambios de la rama frente a main"
  echo
  PCOL=$C panel "Dirección del Pull Request" "$URL_PR"
}

parte10() {
  seccion 10 \
    "Para cerrar, un resumen de los resultados con datos tomados en este momento, lo aprendido durante el proyecto y las mejoras que se harían con más tiempo."

  pantalla "Resumen de resultados"
  ficha \
    "Qué se verá" "Los indicadores principales del proyecto, calculados en este instante: salud de los servicios, pruebas, alerta, respaldo, secretos y commits." \
    "Qué hace el código" "La función datos_resumen consulta a Docker, ejecuta scripts/pruebas.sh, consulta a Prometheus y revisa Git y la carpeta de respaldos; cada fila indica OK o AVISO." \
    "Cómo se usó aquí" "Es la evidencia final: todo lo presentado se puede volver a comprobar en cualquier momento con este mismo script."
  echo
  datos_resumen | tabla "Indicadores del proyecto" "Indicador|Resultado|Estado"

  pantalla "Aprendizajes y mejoras"
  PCOL=$C panel "Lo aprendido" \
    "Probar de verdad (reiniciar la máquina, apagar servicios, restaurar respaldos) revela defectos que no se ven al construir. Documentarlos y corregirlos con commits pequeños dejó una plataforma más confiable."
  echo
  PCOL=$Y panel "Mejoras que se harían con más tiempo" \
    "• Alertmanager con aviso por correo o n8n: hoy la alerta solo se ve en Prometheus." \
    "• Proxy inverso con TLS y cierre de los puertos que Docker deja abiertos (defecto D-04)." \
    "• Copia de los respaldos fuera de la máquina virtual." \
    "• Ejecutar pruebas.sh automáticamente en cada push (integración continua)."
  echo
  echo "  ${W}${G}Gracias. Quedo atenta a las preguntas.${N}"
}

# =============================================================================
#                         PREGUNTAS DEL PROFESOR
# =============================================================================
pregunta()  { limpiar; PCOL=$M panel "Pregunta del profesor" "$1"; echo; }
respuesta() {
  local x; local -a it=()
  for x in "$@"; do it+=("• $x"); done
  PCOL=$Y panel "Respuesta sugerida" "${it[@]}"
}
evidencia() { echo; echo " ${W}${C}»${N} ${W}Evidencia en vivo${N}"; echo; }

q_puertos() {
  pregunta "¿Qué puertos usa tu plataforma y por qué app y db no publican puerto?"
  respuesta \
    "web 8080, Prometheus 9090, Grafana 3000, Uptime Kuma 3001, cAdvisor 8081 y node-exporter 9100." \
    "app (Adminer) y db (PostgreSQL) no se publican: solo se alcanzan por la red interna de Docker." \
    "Así se reduce la superficie de ataque: el puerto 5432 nunca queda expuesto."
  evidencia
  datos_puertos | tabla "Puertos del proyecto" "Servicio|Puerto en la VM|Puerto interno|Acceso|Exposición"
}
q_volumenes() {
  pregunta "¿Qué pasa con los datos si borras un contenedor? ¿Dónde se guardan?"
  respuesta \
    "Se guardan en volúmenes con nombre, fuera del contenedor: base de datos, Grafana, Uptime Kuma y Prometheus." \
    "'docker compose down' conserva los volúmenes; 'down -v' los borra, por eso no se usa." \
    "Grafana no tenía volumen (defecto D-03): se corrigió y se migraron los dashboards."
  evidencia
  datos_volumenes | tabla "Volúmenes del proyecto" "Volumen|Usado por|Qué guarda|Tipo"
}
q_redes() {
  pregunta "¿Por qué dos redes y cómo se comunican los contenedores?"
  respuesta \
    "red-app (aplicación) y red-monitoreo (observabilidad): separarlas reduce el alcance de cada servicio." \
    "Docker ofrece DNS interno: un contenedor llama a otro por el nombre del servicio (por ejemplo, Prometheus consulta a node-exporter)."
  evidencia
  datos_redes | tabla "Redes del proyecto" "Red|Tipo|Servicios conectados|N.°"
}
q_compose() {
  pregunta "¿Por qué Docker Compose y qué hace restart: unless-stopped?"
  respuesta \
    "Compose describe toda la plataforma en un archivo versionable y la levanta con un comando: es reproducible." \
    "unless-stopped reinicia el contenedor si cae o si se reinicia la VM, salvo que se detenga a mano." \
    "Antes se usaba 'no': tras reiniciar los contenedores quedaban Exited (255). Era el defecto D-01."
  evidencia
  datos_politicas | tabla "Reinicio automático y salud" "Servicio|Reinicio automático|Salud|Estado|Reinicios|Iniciado (UTC)"
}
q_pruebas() {
  pregunta "¿Qué es una prueba de humo y cómo compruebas que una corrección no rompió otra cosa?"
  respuesta \
    "Prueba de humo: verificación rápida de lo esencial (que el servicio responda). Hay una por servicio, 9 en total." \
    "Regresión: tras cada cambio se repiten todas las pruebas (9 de 9, código 0), se revisa git diff y se hace un commit por corrección." \
    "El código de salida 1 ante una falla permite automatizarlo."
  evidencia
  datos_pruebas | tabla "Pruebas de humo" "Servicio|Qué se comprueba|Resultado esperado"
  ejecutar "./scripts/pruebas.sh | tail -n 3" "./scripts/pruebas.sh | tail -n 3"
}
q_defectos() {
  pregunta "¿Qué defectos encontraste y cómo los corregiste?"
  respuesta \
    "D-01: los contenedores no volvían tras reiniciar -> restart: unless-stopped." \
    "D-02: clave de Kuma en texto plano en prometheus.yml -> password_file, y se rotó la clave." \
    "D-03: Grafana sin volumen -> volumen y migración de dashboards." \
    "D-04: puertos de Docker fuera de las reglas de UFW -> documentado."
  evidencia
  datos_defectos | tabla "Defectos detectados y corregidos" "ID|Defecto|Corrección aplicada"
}
q_git() {
  pregunta "¿Cómo usaste Git? ¿Qué es el Pull Request?"
  respuesta \
    "Rama de funcionalidad, commits pequeños con prefijos (feat, fix, test, docs) y push a GitHub." \
    "El Pull Request #2 propone fusionar la rama a main para revisarla antes; se revisó que no incluyera secretos." \
    "El .gitignore excluye .env y kuma_password."
  evidencia
  datos_git | tabla "Estado del repositorio" "Dato|Valor"
  datos_commits 12 | tabla "Últimos commits" "Commit|Fecha|Mensaje"
}
q_seguridad() {
  pregunta "¿Qué medidas de seguridad aplicaste?"
  respuesta \
    "Secretos fuera de Git (.gitignore), clave de Kuma por password_file y rotada, puertos de app y db sin publicar." \
    "Se documentó que Docker puede saltarse UFW (D-04)." \
    "Permisos 644 en kuma_password porque Prometheus corre con otro usuario; el archivo no se versiona."
  evidencia
  datos_seguridad | tabla "Medidas de seguridad" "Medida|Estado|Evidencia"
}
q_respaldo() {
  pregunta "¿Cómo respaldas y cómo compruebas que se puede restaurar?"
  respuesta \
    "respaldo.sh: tar.gz de documentos, pg_dump de PostgreSQL y sha256 de cada archivo." \
    "Restauración demostrada: tabla con datos, respaldo, DROP, restauración con zcat | psql y SELECT con los datos de vuelta." \
    "Limitación: los respaldos están en la misma VM; lo ideal es copiarlos a otro equipo."
  evidencia
  datos_respaldos | tabla "Archivos en ~/respaldos" "Archivo|Tipo|Tamaño|Creado"
  comando "crontab -l"
  crontab -l 2>/dev/null | grep -v '^#' | bloque_salida "Tareas programadas (cron)"
}
q_alerta() {
  pregunta "¿Cómo funciona tu alerta y qué le falta?"
  respuesta \
    "ServicioCaido: up == 0 durante 1 minuto, severidad critical. Prometheus evalúa cada 15 s: PENDING y luego FIRING." \
    "Falta Alertmanager: hoy la alerta se ve en Prometheus pero no envía correo. Mejora: Alertmanager o un flujo de n8n." \
    "Además Uptime Kuma vigila la disponibilidad desde otro punto de vista."
  evidencia
  reglas_prometheus | tabla "Reglas de alerta" "Grupo|Regla|Estado|Duración|Severidad"
  estado_alertas | tabla "Alertas activas" "Alerta|Estado|Job"
}
q_n8n() {
  pregunta "¿Qué automatizaste con n8n e IA?"
  respuesta \
    "Flujo: disparador de programación -> editar campos -> agente de IA (modelo Groq) -> enviar correo." \
    "El prompt define rol, contexto, tarea, formato y restricción; los datos se anonimizaron antes de enviarlos a la IA." \
    "n8n corre en Docker (puerto 5678), fuera del compose del proyecto."
  evidencia
  docker ps --filter name=n8n --format '{{.Names}}|{{.Status}}|{{.Ports}}' | tabla "Contenedor de n8n" "Contenedor|Estado|Puertos"
}
q_monitoreo() {
  pregunta "¿Qué hace cada herramienta de monitoreo?"
  respuesta \
    "node-exporter: métricas del servidor (CPU, memoria, disco). cAdvisor: métricas de cada contenedor." \
    "Prometheus: recolecta (modelo pull cada 15 s) y evalúa alertas. Grafana: dashboards." \
    "Uptime Kuma: comprueba disponibilidad y expone métricas a Prometheus con clave."
  evidencia
  objetivos_prometheus | tabla "Objetivos de Prometheus" "Job|Dirección|Salud"
  comando "curl -s localhost:9100/metrics | head -n 3"
  curl -s --max-time 5 localhost:9100/metrics 2>/dev/null | head -n 3 | bloque_salida "Métricas de node-exporter (primeras líneas)"
}

menu_preguntas() {
  local op
  while true; do
    limpiar
    PCOL=$M panel "Preguntas del profesor" "Elige un tema para ver la respuesta sugerida y la evidencia en vivo."
    echo
    {
      printf '1|Puertos|¿Qué puertos usa y por qué app y db no publican?\n'
      printf '2|Volúmenes|¿Qué pasa con los datos si se borra un contenedor?\n'
      printf '3|Redes|¿Por qué dos redes y cómo se comunican?\n'
      printf '4|Compose y restart|¿Por qué Compose y qué hace unless-stopped?\n'
      printf '5|Pruebas|¿Qué es una prueba de humo y la regresión?\n'
      printf '6|Defectos|¿Qué defectos encontraste y cómo los corregiste?\n'
      printf '7|Git y Pull Request|¿Cómo usaste Git y qué es el Pull Request?\n'
      printf '8|Seguridad|¿Qué medidas de seguridad aplicaste?\n'
      printf '9|Respaldo y restauración|¿Cómo respaldas y compruebas que se restaura?\n'
      printf '10|Alerta|¿Cómo funciona la alerta y qué le falta?\n'
      printf '11|n8n e IA|¿Qué automatizaste con n8n e IA?\n'
      printf '12|Monitoreo|¿Qué hace cada herramienta de monitoreo?\n'
      printf '0|Volver|Regresar al menú principal\n'
    } | tabla "" "N.°|Tema|Pregunta típica"
    echo
    printf '%s' "  Tema: "
    read -r op || return
    case "$op" in
      1) q_puertos ;; 2) q_volumenes ;; 3) q_redes ;; 4) q_compose ;;
      5) q_pruebas ;; 6) q_defectos ;; 7) q_git ;; 8) q_seguridad ;;
      9) q_respaldo ;; 10) q_alerta ;; 11) q_n8n ;; 12) q_monitoreo ;;
      0|"") return ;;
      *) echo "  Opción no válida"; sleep 1; continue ;;
    esac
    pausa
  done
}

# =============================================================================
#                          VERIFICACIÓN PREVIA
# =============================================================================
chk() {   # chk "Área" "Comprobación" ESTADO
  CHK+=("$1|$2|$3")
  case "$3" in AVISO|FALLA) AV=$(( AV + 1 )) ;; esac
}

verificar() {
  local tot san p v f pub falta
  limpiar; AV=0; CHK=()
  PCOL=$C panel "Verificación previa a la sustentación" \
    "Se comprueba que todo esté en orden antes de empezar: servicios, puertos, volúmenes, archivos, Git, pruebas, alerta, respaldos y n8n. Los avisos en amarillo o rojo indican qué corregir."
  echo
  echo "  Comprobando, un momento..."
  echo

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
  else chk "Respaldo" "La tabla prueba_respaldo no existe (la parte 7 la crea sola)" AVISO; fi
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qi n8n; then chk "n8n" "n8n en ejecución" OK; else chk "n8n" "n8n no está en ejecución" AVISO; fi

  printf '%s\n' "${CHK[@]}" | tabla "Resultado de la verificación" "Área|Comprobación|Estado"
  echo
  docker ps --format '{{.Names}}|{{.Ports}}' 2>/dev/null | grep -v '^compose-' | tabla "Otros contenedores en la VM (no son del proyecto)" "Contenedor|Puertos"
  echo
  if [ "$AV" -eq 0 ]; then
    PCOL=$G panel "Resultado" "Todo listo para la sustentación."
  else
    PCOL=$Y panel "Resultado" "Hay $AV aviso(s) o falla(s) por revisar antes de empezar."
  fi
}

# =============================================================================
#                       EJECUCIÓN DE LA PRESENTACIÓN
# =============================================================================
resumen_ensayo() {
  local i tot=0 u est
  echo
  {
    for i in 1 2 3 4 5 6 7 8 9 10; do
      u="${USADO[$i]:-0}"; tot=$(( tot + u ))
      est="En tiempo"
      [ "$u" -gt "${PRESUP[$i]}" ] && est="Excedida"
      [ "$u" -gt $(( PRESUP[i] * 13 / 10 )) ] && est="Muy excedida"
      printf '%s|%s|%s|%s|%s\n' "$i" "${NOMBRES[$i]}" "$(fmt "$u")" "$(fmt "${PRESUP[$i]}")" "$est"
    done
    est="En tiempo"; [ "$tot" -gt 900 ] && est="Muy excedida"
    printf 'Total||%s|15:00|%s\n' "$(fmt "$tot")" "$est"
  } | tabla "Resumen del ensayo" "N.°|Parte|Usado|Asignado|Resultado"
}

presentacion() {
  ENSAYO="$1"; T0=$(ahora); USADO=()
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    "parte$i"
    fin_seccion
    [ "$i" -lt 10 ] && pausa
  done
  [ "$ENSAYO" = 1 ] && resumen_ensayo
}

una_parte() {
  local n="$1"
  case "$n" in
    1|2|3|4|5|6|7|8|9|10) ENSAYO=0; T0=$(ahora); "parte$n"; fin_seccion ;;
    *) echo "Parte inválida (1 a 10)" ;;
  esac
}

menu() {
  local op n
  while true; do
    limpiar
    PCOL=$C panel "SUSTENTACIÓN FINAL · PROYECTO INTEGRADOR" \
      "$CURSO · $INSTITUCION" \
      "Presenta: $AUTORA"
    echo
    {
      printf '1|Presentación guiada|Recorre las 10 partes en 15 minutos, paso a paso\n'
      printf '2|Ensayo con cronómetro|Igual que la presentación, midiendo el tiempo de cada parte\n'
      printf '3|Preguntas del profesor|Respuesta sugerida y evidencia en vivo por tema\n'
      printf '4|Verificación previa|Comprueba que todo esté listo antes de empezar\n'
      printf '5|Ir a una parte|Ejecuta solo una de las 10 partes\n'
      printf '0|Salir|Cierra el programa\n'
    } | tabla "Menú principal" "Opción|Modo|Qué hace"
    echo
    printf '%s' "  Opción: "
    read -r op || exit 0
    case "$op" in
      1) presentacion 0; pausa ;;
      2) presentacion 1; pausa ;;
      3) menu_preguntas ;;
      4) verificar; pausa ;;
      5) printf '  Número de parte (1 a 10): '; read -r n; una_parte "$n"; pausa ;;
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
  presentacion) presentacion 0 ;;
  ensayo)       presentacion 1 ;;
  preguntas)    menu_preguntas ;;
  verificar)    verificar ;;
  parte)        una_parte "${2:-}" ;;
  menu)         menu ;;
  *) echo "Uso: bash exposicion.sh [presentacion|ensayo|preguntas|verificar|parte N]"; exit 1 ;;
esac
