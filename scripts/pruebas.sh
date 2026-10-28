#!/bin/bash
# pruebas.sh - Pruebas de humo del proyecto integrador (una por servicio)
VERDE='\033[0;32m'; ROJO='\033[0;31m'; AMARILLO='\033[1;33m'; CIAN='\033[0;36m'; NC='\033[0m'
TOTAL=0; FALLAS=0

resultado() {   # $1 nombre, $2 estado (0 = ok), $3 detalle
  TOTAL=$((TOTAL+1))
  if [ "$2" -eq 0 ]; then
    echo -e "${VERDE}[ OK    ]${NC} $1 ${CIAN}($3)${NC}"
  else
    echo -e "${ROJO}[ FALLA ]${NC} $1 ${AMARILLO}($3)${NC}"
    FALLAS=$((FALLAS+1))
  fi
}

http() {   # $1 nombre, $2 url, $3 codigo esperado
  codigo=$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' "$2")
  if [ "$codigo" = "$3" ]; then resultado "$1" 0 "HTTP $codigo"
  else resultado "$1" 1 "esperaba $3, obtuve $codigo"; fi
}

salud() {  # $1 nombre, $2 contenedor
  estado=$(docker inspect -f '{{.State.Health.Status}}' "$2" 2>/dev/null)
  if [ "$estado" = "healthy" ]; then resultado "$1" 0 "healthcheck: $estado"
  else resultado "$1" 1 "healthcheck: ${estado:-no existe}"; fi
}

echo -e "${CIAN}=== Pruebas de humo - proyecto integrador - $(date '+%Y-%m-%d %H:%M:%S') ===${NC}"

http  "Nginx (web)"          http://localhost:8080 200
salud "Adminer (app)"        compose-app-1
if docker exec compose-db-1 pg_isready -q > /dev/null 2>&1; then
  resultado "PostgreSQL (db)" 0 "pg_isready: accepting connections"
else
  resultado "PostgreSQL (db)" 1 "pg_isready fallo"
fi
http  "Prometheus"           http://localhost:9090/-/healthy 200
arriba=$(curl -s --max-time 5 http://localhost:9090/api/v1/targets | grep -o '"health":"up"' | wc -l)
if [ "$arriba" -eq 4 ]; then resultado "Prometheus: objetivos" 0 "$arriba de 4 en up"
else resultado "Prometheus: objetivos" 1 "$arriba de 4 en up"; fi
http  "Grafana"              http://localhost:3000/login 200
http  "node-exporter"        http://localhost:9100/metrics 200
http  "Uptime Kuma"          http://localhost:3001 302
http  "cAdvisor"             http://localhost:8081 307

echo
if [ "$FALLAS" -eq 0 ]; then
  echo -e "${VERDE}RESULTADO: $TOTAL de $TOTAL pruebas aprobadas${NC}"
  exit 0
else
  echo -e "${ROJO}RESULTADO: $FALLAS de $TOTAL pruebas fallaron${NC}"
  exit 1
fi
