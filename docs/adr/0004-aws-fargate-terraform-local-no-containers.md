# ADR-0004: AWS + ECS Fargate + Terraform; desarrollo local sin contenedores en la app

- Estado: Aceptada
- Fecha: 2026-09-15

## Contexto
El equipo (1-3 personas) quiere nube pública sin restricciones previas de
stack, y un flujo de desarrollo local simple: la app debe poder correr sin
necesidad de contenerizar, pero el sistema debe quedar listo para
contenerizar y desplegar en AWS sin rediseño.

## Decisión
- Nube: **AWS**.
- Cómputo: **ECS Fargate** (no EKS/Kubernetes).
- IaC: **Terraform** (no CDK), para mantener el ciclo de vida de
  infraestructura desacoplado del lenguaje de la app (Go/Dart).
- Local: el backend corre como binario nativo (`go run`) y los apps
  Flutter corren nativos (`flutter run`) — **solo Postgres se
  conteneriza localmente** (`backend/docker-compose.yml`), con scripts de
  inicialización (`backend/migrations/`, `backend/scripts/init-db/`) para
  levantar datos de prueba automáticamente.
- Ya existen `Dockerfile`s (`backend/deploy/docker/`) para el despliegue en
  AWS, pero no se usan en desarrollo local.

## Consecuencias
- Sin la carga operativa de administrar un cluster Kubernetes para un
  equipo de este tamaño.
- El loop de desarrollo local es rápido (sin build de imágenes para
  iterar).
- Contenerizar para AWS es un paso aditivo (activar Dockerfiles ya
  existentes), no una reescritura, cuando llegue el momento de desplegar.

## Alternativas consideradas
- **EKS/Kubernetes**: descartado — sobre-ingeniería operativa para 1-3
  personas.
- **AWS CDK**: descartado a favor de Terraform, por ser estándar de facto
  independiente del lenguaje de la app.
- **Desarrollo local totalmente contenerizado (app incluida)**: descartado
  por requisito explícito del usuario.
