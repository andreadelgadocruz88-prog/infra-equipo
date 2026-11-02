# Reflexión - Semana 15

Respuestas a las preguntas de reflexión de la actividad Implementación y Pruebas del Proyecto Integrador.

## 1. ¿Qué prueba de humo aplicarías a cada servicio de tu proyecto?

No basta con ver que el contenedor está Up, porque eso solo dice que el proceso arrancó. La prueba de humo debe comprobar que el servicio responde: uso curl con -w para obtener el código HTTP (200 responde, 000 no hubo conexión) y exit 1 para marcar la falla. Mis pruebas están en scripts/pruebas.sh:

| Servicio | Prueba | Resultado esperado |
|---|---|---|
| Nginx | HTTP a localhost:8080 | 200 |
| Adminer | healthcheck del contenedor | healthy |
| PostgreSQL | pg_isready | accepting connections |
| Prometheus | HTTP a /-/healthy | 200 |
| Prometheus | objetivos en estado up | 4 de 4 |
| Grafana | HTTP a /login | 200 |
| node-exporter | HTTP a /metrics | 200 |
| Uptime Kuma | HTTP a localhost:3001 | 302 (redirige al login) |
| cAdvisor | HTTP a localhost:8081 | 307 (redirige a su panel) |

Todas se ejecutan juntas con ./scripts/pruebas.sh, que termina con código 1 si alguna falla. Así detecto el problema durante la integración y no al final.

## 2. ¿Cómo comprobarías que una corrección no rompió otra parte?

Una corrección puede arreglar un problema y romper otro, por eso después de cada cambio repito todas las pruebas y no solo la del servicio que toqué (prueba de regresión). Mi procedimiento:

1. Ejecutar ./scripts/pruebas.sh y exigir 9 de 9 aprobadas con código de salida 0.
2. Ejecutar docker compose ps y confirmar que los 8 servicios siguen Up y healthy.
3. Revisar con git diff qué archivos cambié, para saber qué más pudo verse afectado.
4. Hacer un commit por corrección y solo si todo está verde, para poder volver atrás con Git si algo falla.

Ejemplo real: en D-02 moví la clave de Uptime Kuma a password_file. Después comprobé que Prometheus seguía con 4 de 4 objetivos arriba y que las demás pruebas seguían en verde.

## 3. ¿Qué incluirías en el README para que otra persona despliegue tu proyecto?

El README debe permitir que alguien que no conoce el proyecto lo levante sin preguntarme nada. Incluí:

- Requisitos: Ubuntu con Docker y Docker Compose instalados.
- Estructura del repositorio y diagrama de arquitectura.
- Tabla de servicios y puertos (web 8080, Prometheus 9090, Grafana 3000, Uptime Kuma 3001, cAdvisor 8081, node-exporter 9100).
- Cómo desplegar: crear el archivo .env y el archivo de clave de Uptime Kuma (que no están en el repositorio por seguridad) y ejecutar docker compose up -d.
- Cómo probar: ./scripts/pruebas.sh y el resultado esperado de 9 de 9.
- Cómo respaldar y restaurar con scripts/respaldo.sh, y cómo verificar los hashes.
- Un índice por semanas, para ubicar cada entregable.

Mi criterio es que, si una persona sigue el README de arriba hacia abajo, al final tiene los 8 servicios arriba y las pruebas en verde.
