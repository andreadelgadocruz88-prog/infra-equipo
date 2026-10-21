# Plan de implementación por etapas

Responsable de todas las etapas: Andrea.

| Etapa | Actividad | Responsable | Fecha | Estado | Evidencia |
|-------|-----------|-------------|-------|--------|-----------|
| 1 | Definir requerimientos funcionales y no funcionales | Andrea | 21/10/2026 | Hecho | docs/requerimientos.md |
| 2 | Organizar el repositorio (compose, docs, scripts, backups) | Andrea | 21/10/2026 | Hecho | Estructura de carpetas y commits en la rama feature/semana14-arquitectura |
| 3 | Diseñar el diagrama de arquitectura por capas | Andrea | 21/10/2026 | Hecho | docs/arquitectura.md y docs/img/arquitectura.png |
| 4 | Desplegar la plataforma con Docker Compose y probar RF1, RF2, RF3 | Andrea | 21/10/2026 | Hecho | Captura de `docker compose ps` y de Adminer en el navegador |
| 5 | Verificar el respaldo automático con cron (RNF4) | Andrea | 22/10/2026 | Pendiente | Archivo docs-2026-10-22.tar.gz en ~/respaldos |
| 6 | Mejorar el respaldo: agregar copia de PostgreSQL con pg_dump | Andrea | 26/10/2026 | Pendiente | Script actualizado en scripts/ y archivo .sql generado |
| 7 | Fusionar la rama en main y subir a GitHub | Andrea | 21/10/2026 | Hecho | Captura del repositorio en GitHub |

## Criterio de cierre de cada etapa

Una etapa se considera terminada cuando existe su evidencia (archivo o captura) y su cambio está guardado en un commit.
