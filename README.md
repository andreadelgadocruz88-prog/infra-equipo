# infra-equipo

Plataforma de laboratorio con Docker Compose: aplicación web (Nginx, Adminer y PostgreSQL 16) y monitoreo (Prometheus, Grafana, node-exporter, Uptime Kuma y cAdvisor).
Incluye el diseño de la arquitectura (semana 14) y su implementación y pruebas (semana 15).

## Requisitos
- Ubuntu 22.04 con Docker y Docker Compose instalados
- Puertos libres: 8080, 3000, 9090, 9100, 3001 y 8081
- Git configurado con SSH

## Estructura del repositorio
- compose/: docker-compose.yml, nginx.conf, .env.example y monitoring/ (prometheus.yml y alertas.yml)
- docs/: requerimientos, arquitectura, plan por etapas, matriz de riesgos, reflexión y registro de defectos
- scripts/: respaldo.sh (respaldo con cron) y pruebas.sh (pruebas de humo)
- backups/: carpeta reservada; los respaldos se guardan fuera del repositorio, en ~/respaldos
- semana09/: trabajo de la semana 9 (estado.py, reporte.txt y respaldo.sh)

## Documentación
- [Requerimientos](docs/requerimientos.md)
- [Arquitectura y decisiones de diseño](docs/arquitectura.md)
- [Plan por etapas](docs/plan-etapas.md)
- [Matriz de riesgos](docs/matriz-riesgos.md)
- [Reflexión](docs/reflexion.md)
- [Registro de defectos](docs/defectos.md)

## Diagrama de arquitectura
![Arquitectura](docs/img/arquitectura.png)

## Servicios y puertos
| Servicio | Puerto | Volumen |
|---|---|---|
| web (Nginx) | 8080 | - |
| app (Adminer) | solo red interna | - |
| db (PostgreSQL 16) | solo red interna | datos-db |
| prometheus | 9090 | prometheus-datos |
| grafana | 3000 | grafana-datos |
| node-exporter | 9100 | - |
| uptime-kuma | 3001 | kuma-datos |
| cadvisor | 8081 | - |

Todos los servicios usan restart: unless-stopped y los que lo permiten tienen healthcheck.

## Cómo desplegar
1. Clonar el repositorio: git clone git@github.com:andreadelgadocruz88-prog/infra-equipo.git
2. Entrar a la carpeta de compose: cd infra-equipo/compose
3. Crear el archivo de variables: cp .env.example .env y editar la contraseña
4. Crear la clave de Uptime Kuma (no se versiona): echo -n "CLAVE" > monitoring/kuma_password
5. Levantar los servicios: docker compose up -d
6. Verificar que estén activos: docker compose ps
7. Abrir en el navegador: http://IP-DEL-SERVIDOR:8080 (web), :3000 (Grafana), :9090 (Prometheus) y :3001 (Uptime Kuma)

Nota: la clave real de Uptime Kuma se genera en Ajustes > Claves API. Con otra clave, el objetivo uptime-kuma de Prometheus aparece caído.

## Pruebas
Las pruebas de humo se ejecutan con los servicios levantados desde compose/ (los nombres de contenedor, como compose-db-1, dependen de ese directorio):

./scripts/pruebas.sh

| Servicio | Prueba | Resultado esperado |
|---|---|---|
| Nginx | HTTP a localhost:8080 | 200 |
| Adminer | healthcheck del contenedor | healthy |
| PostgreSQL | pg_isready | accepting connections |
| Prometheus | HTTP a /-/healthy | 200 |
| Prometheus | objetivos en estado up | 4 de 4 |
| Grafana | HTTP a /login | 200 |
| node-exporter | HTTP a /metrics | 200 |
| Uptime Kuma | HTTP a localhost:3001 | 302 |
| cAdvisor | HTTP a localhost:8081 | 307 |

El script termina con código 0 si todas pasan y con código 1 si alguna falla. Para provocar una falla: docker compose stop grafana, ejecutar el script y volver a levantarlo con docker compose start grafana.

Cobertura: las pruebas comprueban que cada servicio esté disponible. No miden rendimiento, seguridad ni el contenido de los dashboards.

## Respaldo
scripts/respaldo.sh crea tres tipos de archivo en ~/respaldos (fuera del repositorio, porque los respaldos no se suben a GitHub):
- docs-AAAA-MM-DD.tar.gz: copia de ~/documentos
- bd-AAAA-MM-DD.sql.gz: volcado de la base PostgreSQL (pg_dump del contenedor compose-db-1)
- un archivo .sha256 por cada respaldo, para comprobar su integridad

Crear el respaldo: bash scripts/respaldo.sh
Verificar la integridad: cd ~/respaldos && sha256sum -c bd-AAAA-MM-DD.sha256
Restaurar la base de datos: zcat bd-AAAA-MM-DD.sql.gz | docker exec -i compose-db-1 sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
Restaurar documentos: mkdir -p /tmp/restauracion && tar -xzf docs-AAAA-MM-DD.tar.gz -C /tmp/restauracion

Respaldo automático con cron (ejemplo, todos los días a las 2:00 p. m.): 0 14 * * * /home/USUARIO/infra-equipo/scripts/respaldo.sh

Nota: restaurar sobre tablas que ya existen genera errores o filas duplicadas; en una prueba, borrar antes la tabla afectada.

## Índice por semanas
| Semana | Tema | Dónde está |
|---|---|---|
| 9 | Automatización con scripts | semana09/ |
| 11 | Monitoreo y observabilidad | compose/monitoring/ y los servicios de monitoreo del compose |
| 12 | Seguridad, hardening y respaldo | scripts/respaldo.sh |
| 14 | Diseño de la arquitectura | docs/ y docs/img/ |
| 15 | Implementación y pruebas | compose/, scripts/pruebas.sh y docs/defectos.md |
