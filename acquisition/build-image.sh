#!/bin/sh
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

DOCKER_CMD="docker"
CONTAINER_ARCH="linux/amd64"

IMAGE_REPO_default="cpal.io"
IMAGE_REPO="${IMAGE_REPO:-${IMAGE_REPO_default}}"

app_name="cpal-evictions-dcad-sync"

usage() {
  echo "Usage: $(basename $0)"
  echo
  echo "Environment (optional):"
  echo "  IMAGE_REPO:       [${IMAGE_REPO_default}] alternate container image repository"
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  exit
fi

printf "Resolving VCS tag..."
vcs_tag=$(git describe --tags --always 2> /dev/null)
if [ $? -ne 0 ]; then
  vcs_tag="source"
fi
echo "${vcs_tag}"

image_path="${IMAGE_REPO}/${app_name}"
fq_image="${image_path}:${vcs_tag}"

${DOCKER_CMD} build -f "${SCRIPT_DIR}/Dockerfile" \
  --progress plain \
  --platform "${CONTAINER_ARCH}" \
  -t "${fq_image}" \
  "${SCRIPT_DIR}"
