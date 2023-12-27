docker build --no-cache -f docker/images/Dockerfile.backend -t taigaio/backend:alpha --memory='2g' .
docker build --no-cache -f docker/images/Dockerfile.frontend -t taigaio/frontend:alpha --memory='2g' .
docker compose -f docker/docker-compose.yml up