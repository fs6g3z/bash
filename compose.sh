#!/bin/bash
set -e

echo "Deployment script started on server."
echo "Branch: $GIT_BRANCH_NAME"
echo "Work directory: $WORK_DIR_SERVER"
echo "Compose file name: $COMPOSE_FILE_NAME"
echo "Application image: $APP_IMAGE_WITH_TAG"

echo "Logging into Docker Registry $DOCKER_REGISTRY_HOST..."
echo "$DOCKER_REGISTRY_TOKEN_SERVER" | docker login "$DOCKER_REGISTRY_HOST" -u "$DOCKER_REGISTRY_USER_SERVER" --password-stdin

echo "Changing directory to $WORK_DIR_SERVER"
cd "$WORK_DIR_SERVER" || { echo "Failed to change directory to $WORK_DIR_SERVER"; exit 1; }

COMPOSE_FILE_PATH="$WORK_DIR_SERVER/$COMPOSE_FILE_NAME"
if [ ! -f "$COMPOSE_FILE_PATH" ]; then
  echo "Compose file $COMPOSE_FILE_PATH not found in $WORK_DIR_SERVER"; exit 1;
fi

echo "Pulling latest application image: $APP_IMAGE_WITH_TAG"
docker pull "$APP_IMAGE_WITH_TAG" || { echo "Failed to pull image $APP_IMAGE_WITH_TAG"; exit 1; }

echo "Bringing up services with Docker Compose using image $APP_IMAGE_WITH_TAG ..."

APP_IMAGE_FOR_COMPOSE="$APP_IMAGE_WITH_TAG" docker compose -f "$COMPOSE_FILE_PATH" up -d --force-recreate --remove-orphans || { echo "Docker Compose failed"; exit 1; }

echo "Cleaning up old Docker images..."
docker image prune -f

echo "Deployment finished successfully."
