#!/usr/bin/env bash
# =============================================================================
#  exposicion.sh - Sustentacion final del proyecto integrador (Semana 16)
#  Curso: Administracion de Plataformas TI - IESTP Paijan
#
#  Un solo script que MUESTRA y EXPLICA toda la plataforma con datos reales:
#    presentacion : 10 partes guiadas (15 min), con comandos ejecutados en vivo
#    ensayo       : igual, pero con cronometro y tiempo asignado por parte
#    preguntas    : respuestas modelo + evidencia en vivo, por tema
#    verificar    : revision previa (avisa en amarillo si falta algo)
#    parte N      : ejecuta solo la parte N (1 a 10)
#
#  Uso:  bash exposicion.sh            (menu)
#        bash exposicion.sh ensayo
#  Nunca muestra el contenido de .env ni de kuma_password.
# =============================================================================

REPO="${REPO:-$HOME/infra-equipo}"
COMPOSE_DIR="$REPO/compose"
RESP="$HOME/respaldos"
PROY="compose"
DB="compose-db-1"
URL_PR="https://github.com/andreadelgadocruz88-prog/infra-equipo/pull/2"
ENSAYO=0
AV=0
T0=0
SEC=0
SEC_T0=0

declare -a PRESUP=(0 60 120 90 90 90 120 150 60 60 60)
declare -a USADO=()
declare -a NOMBRES=("" "Introduccion y estructura" "Arquitectura y servicios" \
  "Persistencia y reinicio" "Pruebas de humo" "Falla provocada y recuperacion" \
  "Alerta de monitoreo" "Respaldo y restauracion" "Seguridad" \
  "Defectos y control de versiones" "Cierre")

# ---------------------------------------------------------------- colores ----
if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; M=$'\e[35m'; C=$'\e[36m'
  W=$'\e[1m'; D=$'\e[2m'; N=$'\e[0m'
else
  R=''; G=''; Y=''; B=''; M=''; C=''; W=''; D=''; N=''
fi

# ---------------------------------------------------------------- ayudas -----
ahora()   { date +%s; }
fmt()     { printf '%02d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }
limpiar() { [ -t 1 ] && clear; }
dc()      { ( cd "$COMPOSE_DIR" && docker compose "$@" ); }

ok()    { echo "  ${G}[ OK ]${N} $*"; }
aviso() { AV=$(( AV + 1 )); echo "  ${Y}[AVISO]${N} $*"; }
falla() { AV=$(( AV + 1 )); echo "  ${R}[FALLA]${N} $*"; }
paso()  { echo; echo "${W}${C}> $*${N}"; }
dice()  { echo "${Y}  Decir:${N} $*"; }
nota()  { echo "${D}  $*${N}"; }

# cmd "texto visible" ["comando real"] : muestra el comando y lo ejecuta
cmd() {
  local visible="$1" real="${2:-$1}"
  echo; echo "${G}\$ ${visible}${N}"
  sleep 0.4
  eval "$real"
  return $?
}

pausa() {
  local extra=""
  [ "$ENSAYO" = 1 ] && extra=" | reloj $(fmt $(( $(ahora) - T0 )))"
  echo
  printf '%s' "${D}--- Enter para continuar${extra} ---${N} "
  read -r _ || true
}

confirmar() {
  local r
  printf '%s [S/n] ' "$1"
  read -r r || r=S
  case "$r" in n|N) return 1 ;; *) return 0 ;; esac
}

seccion() {
  SEC="$1"; SEC_T0=$(ahora)
  limpiar
  echo
  echo "${W}${B}============================================================${N}"
  echo "${W}${B}  PARTE $1 de 10 - ${NOMBRES[$1]}${N}"
  [ "$ENSAYO" = 1 ] && echo "${D}  Tiempo asignado: $(fmt "${PRESUP[$1]}")${N}"
  echo "${W}${B}============================================================${N}"
}

fin_seccion() {
  local t=$(( $(ahora) - SEC_T0 )) lim="${PRESUP[$SEC]}" col="$G"
  USADO[$SEC]=$t
  if [ "$ENSAYO" = 1 ]; then
    [ "$t" -gt "$lim" ] && col="$Y"
    [ "$t" -gt $(( lim * 13 / 10 )) ] && col="$R"
    echo
    echo "${col}  Parte $SEC: $(fmt "$t") usados de $(fmt "$lim") | total acumulado $(fmt $(( $(ahora) - T0 )))${N}"
  fi
}

# consulta SQL en el contenedor de la base (psql con las variables del contenedor)
sql()  { docker exec -i "$DB" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"' _ "$1"; }
sqlq() { docker exec "$DB" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "$1"' _ "$1" 2>/dev/null; }

esperar_http() {
  local url="$1" max="$2" i=0 c
  printf '  Esperando %s ' "$url"
  while [ "$i" -lt "$max" ]; do
    c=$(curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
    if [ "$c" = "200" ]; then echo " ${G}listo (${i}s)${N}"; return 0; fi
    printf '.'; sleep 2; i=$(( i + 2 ))
  done
  echo " ${Y}sin respuesta tras ${max}s${N}"; return 1
}

# ------------------------------------------------- datos reales de Docker -----
info_entorno() {
  echo "  Usuario : $(whoami)"
  echo "  Equipo  : $(hostname)   IP: $(hostname -I 2>/dev/null | awk '{print $1}')"
  echo "  Sistema : $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-desconocido}")"
  echo "  Docker  : $(docker --version 2>/dev/null)"
  echo "  Compose : $(docker compose version 2>/dev/null)"
  echo "  Fecha   : $(date '+%Y-%m-%d %H:%M')"
}

estructura() {
  ( cd "$REPO" && find compose scripts docs semana09 -type f \
      ! -name kuma_password ! -name '.env' 2>/dev/null | sort; echo README.md )
}

url_servicios() {
  local ip n p pub x
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  docker ps --filter "label=com.docker.compose.project=$PROY" \
      --format '{{.Names}}|{{.Ports}}' | sort | while IFS='|' read -r n p; do
    pub=$(echo "$p" | grep -oE '0\.0\.0\.0:[0-9]+' | cut -d: -f2 | sort -u | tr '\n' ' ')
    if [ -n "$pub" ]; then
      for x in $pub; do printf '  %-24s http://%s:%s\n' "$n" "$ip" "$x"; done
    else
      printf '  %-24s (sin puerto publicado: solo red interna)\n' "$n"
    fi
  done
}

redes_info() {
  local n
  for n in $(docker network ls --filter "label=com.docker.compose.project=$PROY" --format '{{.Name}}'); do
    printf '  %-22s ->' "$n"
    docker network inspect -f '{{range .Containers}} {{.Name}}{{end}}' "$n"
  done
}

volumenes_info() {
  local v
  for v in $(docker volume ls --filter "label=com.docker.compose.project=$PROY" --format '{{.Name}}'); do
    printf '  %-26s usado por: %s\n' "$v" \
      "$(docker ps -a --filter "volume=$v" --format '{{.Names}}' | tr '\n' ' ')"
    nota "    ubicacion en el host: $(docker volume inspect -f '{{.Mountpoint}}' "$v")"
  done
}

politicas_restart() {
  local c
  for c in $(dc ps -q); do
    docker inspect -f '  {{.Name}}  restart={{.HostConfig.RestartPolicy.Name}}  salud={{if .State.Health}}{{.State.Health.Status}}{{else}}sin-healthcheck{{end}}' "$c"
  done
}

reglas_prometheus() {
  curl -s localhost:9090/api/v1/rules | python3 -c '
import sys, json
d = json.load(sys.stdin)
for g in d["data"]["groups"]:
    for r in g["rules"]:
        print("  grupo=%s  regla=%s  estado=%s  duracion=%ss" % (g["name"], r["name"], r["state"], r.get("duration", 0)))
' 2>/dev/null || echo "  (Prometheus no responde)"
}

estado_alertas() {
  curl -s localhost:9090/api/v1/alerts | python3 -c '
import sys, json
a = json.load(sys.stdin)["data"]["alerts"]
if not a:
    print("  (sin alertas activas)")
for x in a:
    print("  %s  estado=%s  job=%s" % (x["labels"].get("alertname"), x["state"].upper(), x["labels"].get("job", "?")))
' 2>/dev/null || echo "  (Prometheus no responde)"
}

objetivos_prometheus() {
  curl -s localhost:9090/api/v1/targets | python3 -c '
import sys, json
for t in json.load(sys.stdin)["data"]["activeTargets"]:
    print("  %-16s %s" % (t["labels"]["job"], t["health"]))
' 2>/dev/null || echo "  (Prometheus no responde)"
}

preparar_tabla() {
  local n
  sql "CREATE TABLE IF NOT EXISTS prueba_respaldo (id serial PRIMARY KEY, valor int);" >/dev/null 2>&1
  n=$(sqlq "SELECT count(*) FROM prueba_respaldo;")
  if [ "${n:-0}" = "0" ]; then
    sql "INSERT INTO prueba_respaldo (valor) VALUES (10),(20),(30);" >/dev/null 2>&1
  fi
}

verificar_hashes() {
  local f
  ( cd "$RESP" && for f in $(ls -t ./*.sha256 2>/dev/null | head -2); do sha256sum -c "$f"; done )
}

restaurar_bd() {
  local f
  f=$(ls -t "$RESP"/bd-*.sql.gz 2>/dev/null | head -1)
  echo "  Archivo usado: $(basename "$f")"
  zcat "$f" | docker exec -i "$DB" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' 2>&1 \
    | grep -E 'CREATE TABLE|COPY|ERROR'
}

restaurar_docs() {
  local f
  f=$(ls -t "$RESP"/docs-*.tar.gz 2>/dev/null | head -1)
  echo "  Archivo usado: $(basename "$f")"
  rm -rf /tmp/restauracion; mkdir -p /tmp/restauracion
  tar -xzf "$f" -C /tmp/restauracion 2>/dev/null
  find /tmp/restauracion -type f
}

comprobar_secretos() {
  if git ls-files | grep -E 'kuma_password|(^|/)\.env$'; then
    falla "Hay secretos versionados"
  else
    ok "Ningun secreto (.env, kuma_password) esta versionado en Git"
  fi
}

estado_ufw() {
  sudo -n ufw status 2>/dev/null || nota "(ufw requiere sudo; ejecutar antes: sudo ufw status)"
}

# =============================================================================
#                            LAS 10 PARTES
# =============================================================================
parte1() {
  seccion 1
  dice "Soy Andrea, del IESTP Paijan, curso Administracion de Plataformas TI. Mi proyecto integrador es una plataforma TI completa: 8 servicios en contenedores con Docker Compose, con monitoreo, pruebas automaticas, respaldo y documentacion en Git."
  paso "Agenda de la demostracion"
  local i
  for i in 2 3 4 5 6 7 8 9 10; do
    printf '  %2d. %-38s (%s)\n' "$i" "${NOMBRES[$i]}" "$(fmt "${PRESUP[$i]}")"
  done
  paso "Entorno donde corre todo"
  dice "Una maquina virtual Ubuntu en VirtualBox, accedida por SSH. Docker y Compose son la unica dependencia."
  cmd "info_entorno"
  paso "Estructura del repositorio"
  dice "Todo esta ordenado por funcion: compose/ la infraestructura, scripts/ las pruebas y el respaldo, docs/ la documentacion, semana09/ la automatizacion inicial."
  cmd "find compose scripts docs semana09 -type f | sort" "estructura"
  nota "Los archivos .env y kuma_password existen en la VM, pero no se listan ni se suben a Git."
}

parte2() {
  seccion 2
  dice "Docker Compose describe toda la plataforma en un solo archivo y la levanta con un comando. Son 8 servicios: web, app, db, prometheus, grafana, node-exporter, uptime-kuma y cadvisor."
  paso "Estado real de los servicios"
  cmd "docker compose ps" "dc ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'"
  dice "Todos Up y healthy: cada uno tiene un healthcheck, no basta con que el proceso este vivo."
  paso "Puertos publicados (leidos de Docker, no escritos a mano)"
  cmd "docker ps (puertos del proyecto)" "url_servicios"
  dice "app y db NO publican puerto: solo se alcanzan desde la red interna. Es una decision de seguridad (menor superficie de ataque)."
  paso "Redes y quien esta en cada una"
  cmd "docker network inspect (redes del proyecto)" "redes_info"
  dice "Dos redes separadas: red-app para la aplicacion y red-monitoreo para observabilidad. Los contenedores se encuentran por nombre de servicio."
  nota "Abrir en el navegador: Grafana (3000), Prometheus (9090), Uptime Kuma (3001)."
}

parte3() {
  seccion 3
  dice "Un contenedor es descartable; los datos no. Por eso uso volumenes con nombre y una politica de reinicio."
  paso "Volumenes del proyecto"
  cmd "docker volume ls (proyecto compose)" "volumenes_info"
  dice "Base de datos, Grafana, Uptime Kuma y Prometheus guardan sus datos en volumenes. Si borro un contenedor, los datos siguen. Nunca uso 'down -v'."
  paso "Politica de reinicio y salud"
  cmd "docker inspect (restart y salud)" "politicas_restart"
  dice "restart: unless-stopped en los 8. Antes algunos tenian 'no' y no volvian tras reiniciar la VM: ese fue el defecto D-01."
  paso "Prueba real: la VM se reinicio y todo volvio solo"
  cmd "uptime -s; uptime -p" "uptime -s; uptime -p"
  cmd "grep -i 'prueba de reinicio' docs/defectos.md"
  nota "Ese registro esta en docs/defectos.md, con la fecha de la prueba."
}

parte4() {
  seccion 4
  dice "Una prueba de humo comprueba lo esencial de cada servicio: que responda. Ver el contenedor 'Up' no alcanza."
  paso "El script de pruebas"
  cmd "bash -n scripts/pruebas.sh && echo 'Sintaxis correcta'"
  cmd "wc -l scripts/pruebas.sh"
  nota "Pruebas: Nginx 200 | Adminer healthy | PostgreSQL pg_isready | Prometheus 200 | objetivos 4/4 | Grafana 200 | node-exporter 200 | Kuma 302 | cAdvisor 307."
  paso "Ejecucion en vivo"
  cmd "./scripts/pruebas.sh" './scripts/pruebas.sh; echo "codigo de salida: $?"'
  dice "9 de 9 y codigo de salida 0. Si una falla, el script termina con codigo 1: sirve para automatizar y detectar errores temprano."
}

parte5() {
  seccion 5
  dice "Ahora demuestro que las pruebas detectan fallas de verdad: apago Grafana a proposito."
  if ! confirmar "Apagar Grafana para provocar la falla?"; then
    aviso "Parte omitida por el presentador"; fin_seccion; return
  fi
  trap 'echo; echo "Interrumpido: restaurando Grafana..."; dc start grafana >/dev/null 2>&1; exit 130' INT
  cmd "docker compose stop grafana" "dc stop grafana"
  cmd "./scripts/pruebas.sh" './scripts/pruebas.sh; echo "codigo de salida: $?"'
  dice "Resultado: 1 de 9 fallo, Grafana 'esperaba 200, obtuve 000', y codigo de salida 1. Las otras 8 siguen en verde: el fallo queda aislado."
  pausa
  paso "Recuperacion"
  cmd "docker compose start grafana" "dc start grafana"
  esperar_http "http://localhost:3000/login" 120
  cmd "./scripts/pruebas.sh" './scripts/pruebas.sh; echo "codigo de salida: $?"'
  dice "De vuelta a 9 de 9 y codigo 0. Los dashboards siguen ahi porque Grafana usa volumen (defecto D-03 corregido)."
  trap - INT
}

parte6() {
  seccion 6
  dice "El monitoreo no sirve si nadie se entera de una caida. Defini una regla de alerta en Prometheus."
  paso "La regla de alerta"
  cmd "cat compose/monitoring/alertas.yml"
  dice "ServicioCaido: se dispara cuando la metrica 'up' vale 0 durante 1 minuto, con severidad critical. El nombre del servicio caido sale en el resumen."
  paso "Reglas cargadas en Prometheus"
  cmd "curl localhost:9090/api/v1/rules" "reglas_prometheus"
  paso "Estado de los objetivos monitoreados"
  cmd "curl localhost:9090/api/v1/targets" "objetivos_prometheus"
  nota "Limitacion que debo declarar: no hay Alertmanager; la alerta se ve en Prometheus (Estado > Alertas) pero no envia aviso. Mejora: Alertmanager + correo o n8n."
  pausa
  if ! confirmar "Provocar la alerta apagando node-exporter (tarda ~1.5 min)?"; then
    nota "Demostracion en vivo omitida."; return
  fi
  trap 'echo; echo "Interrumpido: restaurando node-exporter..."; dc start node-exporter >/dev/null 2>&1; exit 130' INT
  cmd "docker compose stop node-exporter" "dc stop node-exporter"
  dice "Mientras espera: Prometheus consulta cada 15 s; al fallar pasa a PENDING y, tras 1 minuto, a FIRING. Mostrar http://IP:9090/alerts en el navegador."
  local t=0 out
  while [ "$t" -le 150 ]; do
    out=$(estado_alertas)
    echo "  [${t}s]"; echo "$out"
    if echo "$out" | grep -q FIRING; then
      echo "  ${R}ALERTA DISPARADA (FIRING)${N}"; break
    fi
    sleep 10; t=$(( t + 10 ))
  done
  paso "Recuperacion del servicio"
  cmd "docker compose start node-exporter" "dc start node-exporter"
  sleep 25
  cmd "curl localhost:9090/api/v1/alerts" "estado_alertas"
  trap - INT
}

parte7() {
  seccion 7
  dice "Un respaldo que nunca se restauro no es un respaldo. Mi script crea tres cosas y yo demuestro la restauracion completa."
  paso "El script"
  cmd "sed -n '1,30p' scripts/respaldo.sh"
  dice "Respalda ~/documentos (tar.gz), hace pg_dump de la base (sql.gz) y genera un hash sha256 de cada archivo para comprobar integridad."
  preparar_tabla
  paso "1) Estado inicial de la base (tabla de demostracion)"
  cmd 'sql "SELECT * FROM prueba_respaldo;"'
  pausa
  paso "2) Crear el respaldo"
  cmd "bash scripts/respaldo.sh"
  cmd "ls -lh ~/respaldos | tail -n 6" 'ls -lh "$RESP" | tail -n 6'
  paso "3) Verificar integridad con sha256"
  cmd "sha256sum -c *.sha256 (los dos mas recientes)" "verificar_hashes"
  pausa
  paso "4) Desastre: borro la tabla"
  cmd 'sql "DROP TABLE prueba_respaldo;"'
  cmd 'sql "SELECT * FROM prueba_respaldo;"'
  dice "Error: la tabla no existe. Los datos se perdieron."
  paso "5) Restauracion desde el .sql.gz"
  cmd "zcat bd-FECHA.sql.gz | psql" "restaurar_bd"
  paso "6) Comprobacion: los datos volvieron"
  cmd 'sql "SELECT * FROM prueba_respaldo;"'
  dice "Los 3 registros recuperados. El ciclo completo: datos, respaldo, perdida, restauracion y comprobacion."
  pausa
  paso "7) Restauracion de documentos"
  cmd "tar -xzf docs-FECHA.tar.gz -C /tmp/restauracion" "restaurar_docs"
  nota "Existe ademas un cron diario (0 14 * * *) del script de la semana 9."
}

parte8() {
  seccion 8
  dice "La seguridad se aplico en cuatro frentes: secretos, permisos, puertos y firewall."
  paso "1) Secretos fuera de Git"
  cmd "git ls-files | grep -E 'kuma_password|.env'" "comprobar_secretos"
  cmd "git check-ignore -v compose/monitoring/kuma_password compose/.env"
  paso "2) La clave de Uptime Kuma ya no esta en texto plano"
  cmd "grep -n 'password_file' compose/monitoring/prometheus.yml"
  dice "Defecto D-02: la clave estaba escrita en prometheus.yml. Ahora Prometheus la lee de un archivo (password_file) que no se versiona. Ademas la rote: genere una clave nueva y borre la anterior."
  cmd "ls -l compose/monitoring/kuma_password" 'ls -l compose/monitoring/kuma_password | awk "{print \$1, \$3, \$5\" bytes\", \$9}"'
  nota "Permisos 644 a proposito: Prometheus corre con otro usuario dentro del contenedor; con 600 no puede leerla. El archivo esta fuera de Git."
  paso "3) Superficie de red minima"
  if docker port "$DB" 2>/dev/null | grep -q .; then
    aviso "La base de datos tiene un puerto publicado"
  else
    ok "PostgreSQL no publica puertos: solo accesible dentro de la red de Docker"
  fi
  paso "4) Firewall y el defecto D-04"
  cmd "sudo ufw status" "estado_ufw"
  dice "D-04: Docker publica puertos modificando iptables y puede saltarse las reglas de UFW. Lo documente: lo que publica Docker no lo controla UFW."
  cmd "grep -n 'D-04' docs/defectos.md | head -n 3"
}

parte9() {
  seccion 9
  dice "Cada problema encontrado se registro, se corrigio con un commit y se verifico."
  paso "Registro de defectos"
  cmd "grep -n '^## D-' docs/defectos.md"
  dice "D-01 contenedores no volvian tras reiniciar; D-02 clave en texto plano; D-03 Grafana sin volumen; D-04 puertos de Docker fuera de UFW."
  paso "Control de versiones"
  cmd "git branch --show-current"
  cmd "git log --oneline -n 14"
  dice "Commits pequenos con prefijo: feat, fix, test y docs. Cada commit hace una sola cosa."
  cmd "git status --short   (vacio = todo guardado)" 'git status --short; echo "(fin del estado)"'
  cmd "git remote -v | head -n 1" "git remote -v | head -n 1"
  paso "Flujo de trabajo"
  dice "Rama feature, commits, push, Pull Request #2 y revision antes de fusionar a main. Revise 'Files changed' para confirmar que no se subieron secretos."
  nota "Pull Request: $URL_PR"
  cmd "git diff --stat main...HEAD | tail -n 14" "git diff --stat main...HEAD 2>/dev/null | tail -n 14"
}

parte10() {
  seccion 10
  paso "Resumen con datos reales"
  local tot san
  tot=$(docker ps --filter "label=com.docker.compose.project=$PROY" -q | wc -l)
  san=$(docker ps --filter "label=com.docker.compose.project=$PROY" --filter health=healthy -q | wc -l)
  [ "$san" -eq 8 ] && ok "Servicios healthy: $san de 8" || aviso "Servicios healthy: $san de 8 (en ejecucion: $tot)"
  if ./scripts/pruebas.sh >/dev/null 2>&1; then ok "Pruebas de humo: 9 de 9 aprobadas"; else falla "Pruebas de humo con fallas"; fi
  ok "Commits de la rama: $(git rev-list --count main..HEAD 2>/dev/null || echo '?')"
  local u; u=$(ls -t "$RESP"/bd-*.sql.gz 2>/dev/null | head -1)
  [ -n "$u" ] && ok "Ultimo respaldo de la base: $(basename "$u")" || aviso "No hay respaldos de la base"
  reglas_prometheus | grep -q ServicioCaido && ok "Alerta ServicioCaido cargada" || aviso "Alerta ServicioCaido no encontrada"
  paso "Lo aprendido"
  dice "Probar de verdad (reiniciar la VM, apagar servicios, restaurar) revela defectos que no se ven al construir."
  paso "Mejoras que haria con mas tiempo"
  echo "  - Alertmanager con aviso por correo o n8n (hoy la alerta solo se ve en Prometheus)."
  echo "  - Proxy inverso con TLS y cierre de puertos que Docker deja abiertos (D-04)."
  echo "  - Copia de los respaldos fuera de la VM."
  echo "  - Ejecutar pruebas.sh automaticamente en cada push (integracion continua)."
  echo
  echo "${W}${G}  Gracias. Quedo atenta a las preguntas.${N}"
}

# =============================================================================
#                         PREGUNTAS DEL PROFESOR
# =============================================================================
preg() { limpiar; echo; echo "${W}${M}PREGUNTA:${N} ${W}$*${N}"; }
resp() { echo; echo "${Y}Respuesta sugerida:${N}"; printf '  %s\n' "$@"; echo; echo "${Y}Evidencia en vivo:${N}"; }

q_puertos() {
  preg "Que puertos usa tu plataforma y por que app y db no publican puerto?"
  resp "web 8080, Prometheus 9090, Grafana 3000, Uptime Kuma 3001, cAdvisor 8081, node-exporter 9100." \
       "app (Adminer) y db (PostgreSQL) no se publican: solo se alcanzan por la red interna de Docker." \
       "Asi se reduce la superficie de ataque; el puerto 5432 nunca queda expuesto."
  cmd "docker ps (puertos)" "url_servicios"
}
q_volumenes() {
  preg "Que pasa con los datos si borras un contenedor? Donde se guardan?"
  resp "Se guardan en volumenes con nombre, fuera del contenedor: base, Grafana, Kuma y Prometheus." \
       "'docker compose down' conserva los volumenes; 'down -v' los borra, por eso no lo uso." \
       "Grafana no tenia volumen (D-03) y lo corregi migrando dashboards."
  cmd "docker volume ls" "volumenes_info"
}
q_redes() {
  preg "Por que dos redes y como se comunican los contenedores?"
  resp "red-app (aplicacion) y red-monitoreo (observabilidad): separar reduce el alcance de cada servicio." \
       "Docker da DNS interno: un contenedor llama a otro por el nombre del servicio (por ejemplo prometheus consulta a node-exporter)."
  cmd "docker network inspect" "redes_info"
}
q_compose() {
  preg "Por que Docker Compose y que hace restart: unless-stopped?"
  resp "Compose describe toda la plataforma en un archivo versionable y la levanta con un comando (reproducible)." \
       "unless-stopped reinicia el contenedor si cae o si se reinicia la VM, salvo que yo lo detenga manualmente." \
       "Antes usaba 'no': tras reiniciar quedaban Exited (255). Era el defecto D-01."
  cmd "docker compose config --services" "dc config --services"
  cmd "restart y salud" "politicas_restart"
}
q_pruebas() {
  preg "Que es una prueba de humo y como compruebas que una correccion no rompio otra cosa?"
  resp "Prueba de humo: verificacion rapida de lo esencial (el servicio responde). Una por servicio, 9 en total." \
       "Regresion: tras cada cambio repito todas las pruebas (9 de 9, codigo 0), reviso git diff y hago un commit por correccion." \
       "El codigo de salida 1 ante una falla permite automatizarlo."
  cmd "bash -n scripts/pruebas.sh && echo 'Sintaxis correcta'"
  cmd "./scripts/pruebas.sh | tail -n 3"
}
q_defectos() {
  preg "Que defectos encontraste y como los corregiste?"
  resp "D-01: contenedores no volvian tras reiniciar -> restart: unless-stopped." \
       "D-02: clave de Kuma en texto plano en prometheus.yml -> password_file, y rote la clave." \
       "D-03: Grafana sin volumen -> volumen y migracion de dashboards." \
       "D-04: puertos de Docker fuera de las reglas de UFW -> documentado."
  cmd "grep -n '^## D-' docs/defectos.md"
}
q_git() {
  preg "Como usaste Git? Que es el Pull Request?"
  resp "Rama feature/semana15-pruebas, commits pequenos con prefijos (feat, fix, test, docs) y push a GitHub." \
       "El Pull Request #2 propone fusionar la rama a main para revisarla antes; revise que no incluyera secretos." \
       "El .gitignore excluye .env y kuma_password."
  cmd "git log --oneline --graph -n 12"
  nota "PR: $URL_PR"
}
q_seguridad() {
  preg "Que medidas de seguridad aplicaste?"
  resp "Secretos fuera de Git (.gitignore), clave de Kuma via password_file y rotada, puertos de app y db sin publicar," \
       "y documente que Docker puede saltarse UFW (D-04)." \
       "Permisos 644 en kuma_password porque Prometheus corre con otro usuario; el archivo no se versiona."
  cmd "comprobar secretos" "comprobar_secretos"
  cmd "git check-ignore -v compose/monitoring/kuma_password compose/.env"
}
q_respaldo() {
  preg "Como respaldas y como compruebas que se puede restaurar?"
  resp "respaldo.sh: tar.gz de documentos, pg_dump de PostgreSQL y sha256 de cada archivo." \
       "Restauracion demostrada: tabla con datos, respaldo, DROP, restauracion con zcat | psql y SELECT con los datos de vuelta." \
       "Limitacion: los respaldos estan en la misma VM; lo ideal es copiarlos a otro equipo."
  cmd "ls -lh ~/respaldos | tail -n 6" 'ls -lh "$RESP" | tail -n 6'
  cmd "crontab -l (tareas programadas)" "crontab -l 2>/dev/null | grep -v '^#' || echo '(sin cron)'"
}
q_alerta() {
  preg "Como funciona tu alerta y que le falta?"
  resp "ServicioCaido: up == 0 durante 1 minuto, severidad critical. Prometheus evalua cada 15 s: PENDING y luego FIRING." \
       "Falta Alertmanager: hoy la alerta se ve en Prometheus pero no envia correo. Mejora: Alertmanager o un flujo de n8n." \
       "Ademas Uptime Kuma vigila la disponibilidad desde otro punto de vista."
  cmd "reglas" "reglas_prometheus"
  cmd "alertas activas" "estado_alertas"
}
q_n8n() {
  preg "Que automatizaste con n8n e IA?"
  resp "Flujo: Disparador de programacion -> Editar campos -> Agente de IA (modelo Groq) -> Enviar correo." \
       "El prompt define rol, contexto, tarea, formato y restriccion; los datos se anonimizaron antes de enviarlos a la IA." \
       "n8n corre en Docker (puerto 5678), fuera del compose del proyecto."
  cmd "docker ps (n8n)" "docker ps --filter name=n8n --format '  {{.Names}}  {{.Status}}  {{.Ports}}' | grep . || echo '  AVISO: n8n no esta en ejecucion'"
}
q_monitoreo() {
  preg "Que hace cada herramienta de monitoreo?"
  resp "node-exporter: metricas del servidor (CPU, memoria, disco). cAdvisor: metricas de cada contenedor." \
       "Prometheus: recolecta (modelo pull cada 15 s) y evalua alertas. Grafana: dashboards." \
       "Uptime Kuma: comprueba disponibilidad y expone metricas a Prometheus con clave."
  cmd "objetivos de Prometheus" "objetivos_prometheus"
  cmd "curl -s localhost:9100/metrics | head -n 3"
}

menu_preguntas() {
  local op
  while true; do
    limpiar
    echo "${W}${M}=== PREGUNTAS DEL PROFESOR (por tema) ===${N}"
    echo "   1) Puertos            7) Git y Pull Request"
    echo "   2) Volumenes          8) Seguridad"
    echo "   3) Redes              9) Respaldo y restauracion"
    echo "   4) Compose y restart 10) Alerta"
    echo "   5) Pruebas           11) n8n e IA"
    echo "   6) Defectos          12) Monitoreo"
    echo "   0) Volver"
    printf '%s' "Tema: "
    read -r op || return
    case "$op" in
      1) q_puertos ;; 2) q_volumenes ;; 3) q_redes ;; 4) q_compose ;;
      5) q_pruebas ;; 6) q_defectos ;; 7) q_git ;; 8) q_seguridad ;;
      9) q_respaldo ;; 10) q_alerta ;; 11) q_n8n ;; 12) q_monitoreo ;;
      0|"") return ;;
      *) echo "Opcion no valida"; sleep 1; continue ;;
    esac
    pausa
  done
}

# =============================================================================
#                          VERIFICACION PREVIA
# =============================================================================
verificar() {
  limpiar; AV=0
  echo "${W}${B}=== VERIFICACION PREVIA A LA SUSTENTACION ===${N}"
  paso "Docker y servicios"
  if ! command -v docker >/dev/null 2>&1; then falla "Docker no esta instalado"; return; fi
  if ! docker info >/dev/null 2>&1; then aviso "Docker no responde (permisos o servicio detenido)"; return; fi
  ok "Docker responde"
  local tot san p v f
  tot=$(docker ps --filter "label=com.docker.compose.project=$PROY" -q | wc -l)
  san=$(docker ps --filter "label=com.docker.compose.project=$PROY" --filter health=healthy -q | wc -l)
  [ "$tot" -eq 8 ] && ok "8 contenedores del proyecto en ejecucion" || aviso "Solo $tot de 8 contenedores en ejecucion"
  [ "$san" -eq 8 ] && ok "8 contenedores healthy" || aviso "Healthy: $san de 8"

  paso "Puertos esperados (leidos de Docker)"
  local pub
  pub=$(docker ps --filter "label=com.docker.compose.project=$PROY" --format '{{.Ports}}' \
        | grep -oE '0\.0\.0\.0:[0-9]+' | cut -d: -f2 | sort -u)
  for p in 8080 9090 3000 3001 8081 9100; do
    echo "$pub" | grep -qx "$p" && ok "Puerto $p publicado" || aviso "Puerto $p NO esta publicado"
  done
  echo "$pub" | grep -qx 5432 && falla "PostgreSQL publica 5432 (no deberia)" || ok "PostgreSQL no publica puertos"

  paso "Volumenes esperados"
  for v in compose_datos-db compose_grafana-datos compose_kuma-datos compose_prometheus-datos; do
    docker volume ls -q | grep -qx "$v" && ok "Volumen $v" || aviso "Falta el volumen $v"
  done

  paso "Archivos del repositorio"
  for f in README.md scripts/pruebas.sh scripts/respaldo.sh docs/defectos.md docs/reflexion-semana15.md \
           compose/docker-compose.yml compose/monitoring/alertas.yml compose/monitoring/prometheus.yml \
           compose/monitoring/dashboard-monitoreo.json; do
    [ -f "$REPO/$f" ] && ok "$f" || aviso "Falta $f"
  done
  [ -s "$REPO/compose/monitoring/kuma_password" ] && ok "kuma_password existe (contenido no mostrado)" || aviso "kuma_password falta o esta vacio"

  paso "Git"
  comprobar_secretos
  [ -z "$(git -C "$REPO" status --short)" ] && ok "Arbol de trabajo limpio" || aviso "Hay cambios sin commit"
  ok "Rama actual: $(git -C "$REPO" branch --show-current)"

  paso "Pruebas, alerta, respaldo y n8n"
  if ./scripts/pruebas.sh >/dev/null 2>&1; then ok "pruebas.sh: 9 de 9"; else falla "pruebas.sh reporta fallas"; fi
  reglas_prometheus | grep -q ServicioCaido && ok "Regla ServicioCaido cargada" || aviso "Regla ServicioCaido no encontrada"
  ls "$RESP"/bd-*.sql.gz >/dev/null 2>&1 && ok "Hay respaldos de la base en $RESP" || aviso "No hay respaldos de la base"
  [ -n "$(sqlq "SELECT to_regclass('prueba_respaldo');")" ] && ok "Tabla de demostracion prueba_respaldo existe" \
    || aviso "La tabla prueba_respaldo no existe (la parte 7 la crea sola)"
  docker ps --format '{{.Names}}' | grep -qi n8n && ok "n8n en ejecucion" || aviso "n8n no esta en ejecucion"

  paso "Otros contenedores en la VM (no son del proyecto)"
  docker ps --format '  {{.Names}}  {{.Ports}}' | grep -v '^  compose-' || echo "  (ninguno)"

  echo
  if [ "$AV" -eq 0 ]; then
    echo "${W}${G}Todo listo para la sustentacion.${N}"
  else
    echo "${W}${Y}Hay $AV aviso(s) o falla(s) por revisar antes de empezar.${N}"
  fi
}

# =============================================================================
#                       EJECUCION DE LA PRESENTACION
# =============================================================================
resumen_ensayo() {
  local i tot=0 u col
  echo; echo "${W}${B}=== RESUMEN DEL ENSAYO ===${N}"
  printf '  %-3s %-34s %-8s %-8s\n' "N" "Parte" "Usado" "Asignado"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    u="${USADO[$i]:-0}"; tot=$(( tot + u ))
    col="$G"; [ "$u" -gt "${PRESUP[$i]}" ] && col="$Y"
    printf '  %-3s %-34s %s%-8s%s %-8s\n' "$i" "${NOMBRES[$i]}" "$col" "$(fmt "$u")" "$N" "$(fmt "${PRESUP[$i]}")"
  done
  col="$G"; [ "$tot" -gt 900 ] && col="$R"
  echo "  ${W}Total: ${col}$(fmt "$tot")${N}${W} de 15:00${N}"
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
    1|2|3|4|5|6|7|8|9|10) ENSAYO=0; "parte$n"; fin_seccion ;;
    *) echo "Parte invalida (1 a 10)" ;;
  esac
}

banner() {
  limpiar
  echo "${W}${B}============================================================${N}"
  echo "${W}${B}  SUSTENTACION FINAL - PROYECTO INTEGRADOR${N}"
  echo "${B}  Administracion de Plataformas TI - IESTP Paijan${N}"
  echo "${W}${B}============================================================${N}"
}

menu() {
  local op n
  while true; do
    banner
    echo "   1) Presentacion guiada (15 min, parte por parte)"
    echo "   2) Ensayo con cronometro"
    echo "   3) Preguntas del profesor (por tema)"
    echo "   4) Verificacion previa"
    echo "   5) Ir a una parte concreta (1 a 10)"
    echo "   0) Salir"
    printf '%s' "Opcion: "
    read -r op || exit 0
    case "$op" in
      1) presentacion 0; pausa ;;
      2) presentacion 1; pausa ;;
      3) menu_preguntas ;;
      4) verificar; pausa ;;
      5) printf 'Numero de parte: '; read -r n; una_parte "$n"; pausa ;;
      0) exit 0 ;;
      *) echo "Opcion no valida"; sleep 1 ;;
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
