# Requerimientos de la plataforma

Plataforma web con proxy inverso, administrador de base de datos y base de datos relacional, desplegada con Docker Compose.

## Requerimientos funcionales (RF)

| ID | Requerimiento | Cómo se comprueba |
|----|---------------|-------------------|
| RF1 | El sistema publica una interfaz web de administración de base de datos (Adminer) accesible por el puerto 8080. | `curl -I http://localhost:8080` responde HTTP 200 |
| RF2 | Nginx actúa como proxy inverso y reenvía las peticiones a Adminer dentro de la red `red-app`. | `grep proxy_pass compose/nginx.conf` muestra `http://app:8080` |
| RF3 | PostgreSQL 16 almacena los datos y atiende las consultas hechas desde Adminer. | `docker compose ps` muestra el servicio `db` en estado Up |

## Requerimientos no funcionales (RNF)

| ID | Categoría | Requerimiento | Cómo se comprueba |
|----|-----------|---------------|-------------------|
| RNF1 | Seguridad | Solo la aplicacion web (Nginx, puerto 8080) y los paneles de monitoreo (Grafana 3000, Prometheus 9090, Uptime Kuma 3001, node-exporter 9100 y cAdvisor 8081) se publican al exterior; Adminer y PostgreSQL no publican puertos. | `docker compose ps` lista solo esos puertos publicados |
| RNF2 | Seguridad | Las credenciales no se guardan en el repositorio: el `.env` está ignorado y solo se versiona `.env.example`. | `git check-ignore -v compose/.env` responde `.gitignore:1:.env` |
| RNF3 | Persistencia | Los datos de PostgreSQL sobreviven a reinicios del contenedor gracias al volumen `datos-db`. | `docker volume ls` lista un volumen con `datos-db` |
| RNF4 | Disponibilidad | Se realiza un respaldo automático diario de la carpeta `documentos` a las 2:00 p. m. con `cron`, conservando una copia fechada por día. | `crontab -l` muestra `0 14 * * *` y `ls ~/respaldos` lista archivos `docs-AAAA-MM-DD.tar.gz` |
