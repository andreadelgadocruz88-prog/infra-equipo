# Matriz de riesgos

Escala: Probabilidad e Impacto de 1 (bajo) a 3 (alto). Nivel = P x I.

| # | Riesgo | Prob. | Impacto | Nivel | Mitigación | Cómo se detecta |
|---|--------|:-----:|:-------:|:-----:|------------|-----------------|
| R1 | La VM está apagada a la hora del respaldo y el cron no corre | 3 | 3 | 9 | Programar el cron en horario en que la VM suele estar encendida (2 p. m.) y revisar el último respaldo cada semana | Falta el archivo `docs-AAAA-MM-DD.tar.gz` del día |
| R2 | Conflicto de puertos con otros contenedores (p. ej. 8080) | 3 | 2 | 6 | Documentar los puertos usados en `docs/arquitectura.md` y detener servicios ajenos antes de levantar el compose | `docker compose up` falla con "port is already allocated" |
| R3 | Vence la prueba gratuita de n8n Cloud y el flujo deja de ejecutarse | 3 | 2 | 6 | Exportar el flujo (Download) y tener n8n local en Docker como respaldo | La ejecución programada deja de aparecer en Executions |
| R4 | Credenciales (Groq, correo, token de GitHub) caducan o se filtran | 2 | 3 | 6 | Guardarlas en `.env`, ignorado por Git; rotarlas si se exponen | Error de autenticación en n8n; `git status` mostrando `.env` |
| R5 | Disco lleno por acumulación de respaldos | 2 | 2 | 4 | Rotación: conservar solo los últimos N respaldos | `df -h` sobre el 80 % |
| R6 | Un contenedor se cae y nadie se entera | 2 | 3 | 6 | Uptime Kuma con alerta por correo vía n8n; `restart: unless-stopped` en el compose | Alerta de Uptime Kuma; `docker ps` |
| R7 | Respaldo corrupto o imposible de restaurar | 1 | 3 | 3 | Verificar con `sha256sum` y probar la restauración periódicamente | La suma de verificación no coincide |
| R8 | Trabajo en equipo concentrado en una sola persona | 3 | 2 | 6 | Plan por etapas con responsable y fechas; documentación en el repositorio | Etapas sin avance en las fechas del plan |

## Riesgo más probable

R1 (nivel 9). Ya ocurrió: el respaldo de las 2 a. m. no corrió porque la VM estaba apagada. Se mitigó moviendo el cron a las 2 p. m.
