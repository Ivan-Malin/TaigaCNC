docker build --no-cache -f docker/images/Dockerfile.backend -t taigaio/backend:alpha .
docker build --no-cache -f docker/images/Dockerfile.frontend -t taigaio/frontend:alpha .
docker compose -f docker/docker-compose.yml up