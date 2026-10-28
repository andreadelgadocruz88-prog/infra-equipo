# Registro de defectos - Semana 15

Defectos encontrados durante la integración y las pruebas del proyecto, con su causa, corrección y commit.

| ID | Defecto | Severidad | Estado | Commit |
|---|---|---|---|---|
| D-01 | Contenedores de monitoreo caídos tras reiniciar la VM | Alta | Corregido | d649a7e |
| D-02 | Clave de Uptime Kuma en texto plano en prometheus.yml | Alta | Corregido | 05032e9 |
| D-03 | Grafana sin volumen: dashboards y contraseña se perderían al recrear el contenedor | Media | Corregido | 05032e9 |
| D-04 | Los puertos publicados por Docker no pasan por las reglas de UFW | Media | Abierto (riesgo aceptado) | - |

## D-01. Contenedores de monitoreo caídos tras reiniciar la VM

- **Fecha:** 2026-10-27
- **Cómo se detectó:** al encender la VM, `docker ps -a` mostró Grafana, Prometheus, node-exporter y Uptime Kuma en estado `Exited (255)`. Portainer, n8n, cAdvisor y la base de datos sí volvieron a `Up`.
- **Causa:** los cuatro contenedores tenían la política de reinicio en `no`. Solo cAdvisor y Portainer tenían `unless-stopped`.
- **Impacto:** tras cualquier apagado o reinicio, el monitoreo quedaba caído sin aviso.
- **Corrección en caliente:** `docker update --restart unless-stopped` sobre los cuatro contenedores, comprobado con `docker inspect`.
- **Corrección en el repositorio:** se agregó `restart: unless-stopped` a los 8 servicios de `compose/docker-compose.yml` (commit `d649a7e`).
- **Verificación:** `docker compose ps` con los 8 servicios en `Up` y `healthy`, y `pruebas.sh` con 9 de 9 pruebas aprobadas.
- **Prueba de reinicio (2026-10-28):** tras reiniciar la VM, los 8 servicios volvieron solos en `Up` y `healthy`, sin ejecutar `docker compose up`, y `pruebas.sh` dio 9 de 9 pruebas aprobadas.

## D-02. Clave de Uptime Kuma en texto plano

- **Fecha:** 2026-10-27
- **Cómo se detectó:** al revisar `prometheus.yml` antes de copiarlo al repositorio, apareció la clave de Uptime Kuma escrita en `basic_auth`.
- **Causa:** el archivo de la semana 11 guardaba la clave directamente en la configuración.
- **Impacto:** al hacer push, la clave habría quedado publicada en GitHub.
- **Corrección:** la clave se movió a `compose/monitoring/kuma_password`, que Git ignora, y `prometheus.yml` usa `password_file`. Se hizo antes de subir nada, dentro del commit `05032e9`.
- **Verificación:** `git check-ignore -v` confirma que el archivo está ignorado y `grep -rl` encontró la clave solo en ese archivo. Los 4 objetivos de Prometheus siguen en `up`.
- **Pendiente:** generar una clave nueva en Uptime Kuma, porque la anterior se mostró en pantalla.

## D-03. Grafana sin volumen

- **Fecha:** 2026-10-27
- **Cómo se detectó:** al leer el compose de `~/monitoreo`, el servicio de Grafana no tenía volumen.
- **Causa:** los datos de Grafana (dashboards y contraseña) vivían dentro del contenedor.
- **Impacto:** si Docker recreaba el contenedor, se perdían los dashboards y la contraseña.
- **Corrección:** se respaldó `/var/lib/grafana` con `docker cp`, se agregó el volumen `grafana-datos` al compose y se restauró el respaldo en ese volumen (commit `05032e9`).
- **Verificación:** los 4 dashboards, incluido Monitoreo plataforma, siguen en Grafana tras recrear el contenedor.

## D-04. Los puertos publicados por Docker no pasan por UFW

- **Fecha:** 2026-10-28
- **Cómo se detectó:** `sudo ufw status verbose` no muestra reglas para los puertos 8080, 3000, 9090, 9100, 3001 y 8081, y aun así los servicios responden desde otro equipo de la red.
- **Causa:** Docker publica los puertos con sus propias reglas de iptables, que se evalúan antes que las de UFW. UFW no restringe esos puertos.
- **Impacto:** cualquier equipo de la red puede llegar a Prometheus, node-exporter y cAdvisor, que no piden autenticación. Grafana y Uptime Kuma sí piden usuario y contraseña.
- **Mitigación posible:** publicar los puertos solo en localhost (por ejemplo `127.0.0.1:9090:9090`) o poner reglas en la cadena `DOCKER-USER`.
- **Decisión:** riesgo aceptado en el laboratorio, que está en una red privada. No se modificó para no alterar la demostración. Queda como mejora futura.
