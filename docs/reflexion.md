# Reflexión

## 1. ¿Qué componentes son imprescindibles?

- Nginx: es el único punto de entrada y el único servicio con puerto publicado (8080). Sin él no hay acceso controlado desde el exterior (RF2, RNF1).
- PostgreSQL 16 con el volumen `datos-db`: guarda los datos (RF3) y el volumen hace que sobrevivan a los reinicios del contenedor (RNF3).
- Red interna `red-app`: permite que Nginx, Adminer y PostgreSQL se comuniquen sin exponer puertos al exterior (RNF1).
- Archivo `.env` fuera de Git: protege las credenciales (RNF2).
- Script `respaldo.sh` con cron: garantiza la copia diaria de la información (RNF4).

Adminer cumple el RF1 (interfaz de administración), pero es el componente más prescindible: la plataforma seguiría guardando datos sin él, aunque sin una forma cómoda de consultarlos.

## 2. ¿Qué riesgo es el más probable y cómo lo mitigas?

El más probable es R1 de la matriz de riesgos (nivel 9): la VM está apagada a la hora del respaldo y el cron no corre. No es una hipótesis: ocurrió, porque el respaldo programado a las 2 a. m. no se ejecutó con la VM apagada.

Mitigación aplicada: se movió el cron a las 2:00 p. m., un horario en que la VM suele estar encendida. Además, el respaldo se revisa con `ls ~/respaldos` para confirmar que existe el archivo `docs-AAAA-MM-DD.tar.gz` del día. Mientras el sistema dependa de una VM que se apaga, el riesgo se reduce pero no desaparece.

## 3. ¿Cómo compruebas que el diseño cumple los RNF?

Cada RNF tiene una prueba con un comando y un resultado esperado:

| RNF | Prueba | Resultado esperado |
|-----|--------|--------------------|
| RNF1 Seguridad (un solo puerto) | `docker compose ps` | Solo `web` publica un puerto: 8080 |
| RNF2 Seguridad (credenciales) | `git check-ignore -v compose/.env` | Responde `.gitignore:1:.env` |
| RNF3 Persistencia | `docker volume ls` | Aparece el volumen `compose_datos-db` (prefijo del proyecto) |
| RNF4 Disponibilidad (respaldo diario) | `crontab -l` y `ls ~/respaldos` | El cron muestra `0 14 * * *` y existe un `docs-AAAA-MM-DD.tar.gz` |

RNF1, RNF2 y RNF3 se verificaron con la plataforma levantada. RNF4 se comprueba al día siguiente de la primera ejecución automática: se espera el archivo `docs-2026-10-22.tar.gz`.
