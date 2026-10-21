# infra-equipo

Infraestructura de laboratorio con Docker Compose: Nginx, Adminer y PostgreSQL 16.
Incluye el diseño de arquitectura del proyecto integrador (semana 14).

## Requisitos
- Ubuntu 22.04 con Docker y Docker Compose instalados
- Puerto 8080 libre
- Git configurado con SSH

## Estructura del repositorio
- compose/: docker-compose.yml, nginx.conf y .env.example
- docs/: requerimientos, arquitectura, plan por etapas y matriz de riesgos
- scripts/: respaldo.sh (respaldo automático con cron)
- backups/: destino de los respaldos

## Documentación
- [Requerimientos](docs/requerimientos.md)
- [Arquitectura y decisiones de diseño](docs/arquitectura.md)
- [Plan por etapas](docs/plan-etapas.md)
- [Matriz de riesgos](docs/matriz-riesgos.md)

## Diagrama de arquitectura
![Arquitectura](docs/img/arquitectura.png)

## Cómo desplegar
1. Clonar el repositorio: git clone git@github.com:andreadelgadocruz88-prog/infra-equipo.git
2. Entrar a la carpeta de compose: cd infra-equipo/compose
3. Crear el archivo de variables: cp .env.example .env y editar la contraseña
4. Levantar los servicios: docker compose up -d
5. Verificar que estén activos: docker compose ps
6. Abrir en el navegador: http://IP-DEL-SERVIDOR:8080
