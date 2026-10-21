# Arquitectura de la plataforma

## Diagrama por capas

```mermaid
flowchart TB
  subgraph U["Capa de usuarios"]
    N["Navegador web"]
  end
  subgraph S["Capa de seguridad"]
    P["Unico puerto publicado: 8080"]
    E[".env fuera de Git (.gitignore)"]
  end
  subgraph V["Capa de servicios (Docker Compose, red-app)"]
    NG["Nginx proxy inverso :80"]
    AD["Adminer :8080 interno"]
    PG[("PostgreSQL 16 :5432 interno")]
  end
  subgraph D["Capa de datos"]
    VOL[("Volumen datos-db")]
  end
  subgraph O["Capa de operacion (VM Ubuntu)"]
    CR["cron 0 14 * * *"]
    SH["respaldo.sh"]
    BK[("~/respaldos/docs-AAAA-MM-DD.tar.gz")]
  end
  N -->|"HTTP 8080"| P
  P --> NG
  NG -->|"proxy_pass app:8080"| AD
  AD -->|"SQL 5432"| PG
  PG --- VOL
  CR --> SH
  SH -->|"tar -czf de ~/documentos"| BK
```

## Decisiones de diseño y alternativas

| Decisión | Alternativa descartada | Justificación |
|----------|------------------------|---------------|
| Nginx como proxy inverso | Exponer Adminer directamente | Un solo punto de entrada; permite agregar HTTPS y límites después |
| Adminer y PostgreSQL sin puertos publicados | Publicar el 5432 | Reduce la superficie de ataque: solo se accede por Nginx |
| Docker Compose | Instalar cada servicio a mano en la VM | Despliegue reproducible con un solo archivo |
| Volumen nombrado `datos-db` | Datos dentro del contenedor | Los datos sobreviven a reinicios y recreaciones |
| Respaldo con cron y script Bash | Respaldo manual | Se ejecuta de forma automática y deja copias fechadas |

![Diagrama de arquitectura](img/arquitectura.png)
