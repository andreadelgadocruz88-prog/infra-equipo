# infra-equipo

Infraestructura de laboratorio con Docker Compose:
Nginx, Adminer y PostgreSQL 16.

## Requisitos
- Ubuntu 22.04 con Docker y Docker Compose instalados
- Puerto 8080 libre
- Git configurado con SSH

## Como desplegar
1. Clonar el repositorio: git clone git@github.com:andreadelgadocruz88-prog/infra-equipo.git
2. Entrar a la carpeta: cd infra-equipo
3. Crear el archivo de variables: cp .env.example .env y editar la contraseña
4. Levantar los servicios: docker compose up -d
5. Verificar que estén activos: docker compose ps
6. Abrir en el navegador: http://IP-DEL-SERVIDOR:8080
