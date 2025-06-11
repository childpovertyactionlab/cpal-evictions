#!/usr/bin/env bash
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

source images.shconf

TUMBLR_PATH_default='../tumblR'
TUMBLR_PATH=${TUMBLR_PATH:-${TUMBLR_PATH_default}}

usage() {
  echo "Build images for each of the project's subsystems. Resulting images"
  echo "will be tagged with 'lastbuilt' and the short git commit correspinding"
  echo "to HEAD."
  echo
  echo "Usage: $(basename $0) [subsystem]"
  echo
  echo "Arguments:"
  echo "  subsystem: [${image_subsystems// /|}] Leave blank to build all."
  echo
  echo "Environment (required):"
  echo "  GITHUB_PAT_CPAL_READ: A GitHub access token that lifts rate limits, and that "
  echo "    can read all necessary private repositories."
  echo
  echo "Environment (optional):"
  echo "  TUMBLR_PATH: [${TUMBLR_PATH_default}] Path to tumblR project."
  echo
  usage_images_conf
}

while [ $# -gt 0 ]; do
  case "$1" in
  -h|--help )
    usage
    exit
    ;;
  *)
    if [ -z "${subsystem}" ]; then
      if image_subsystem_valid "$1"; then
        subsystem="$1"
      else
        echo "ERR: Invalid subsystem specified."
        exit 2
      fi
    fi
    ;;
  esac
  shift
done

printf "Resolving VCS tag..."
vcs_tag=$(git describe --tags --always 2> /dev/null)
if [ $? -ne 0 ]; then
  vcs_tag="source"
fi
echo "${vcs_tag}"

for subsys in ${subsystem:-${image_subsystems}}; do
  app_name="${app_image_prefix}/${subsys}"
  image_path="${IMAGE_REPO}/${app_name}"
  fq_image="${image_path}:${vcs_tag}"
  fq_image_last="${image_path}:lastbuilt"

  echo "# Building ${subsys} as ${fq_image}..."

  case ${subsys} in
    analysis)
      IMAGE_REPO="${IMAGE_REPO}" \
        IMAGE_APP_NAME="${app_name}" \
        "${TUMBLR_PATH}/build-image.sh" "${SCRIPT_DIR}"
      ;;
    *)
      context="${subsys}"
      ${DOCKER_CMD} build -f "${SCRIPT_DIR}/${subsys}/Dockerfile" \
        --progress plain \
        --platform "${CONTAINER_ARCH}" \
        -t "${fq_image}" \
        -t "${fq_image_last}" \
        "${context}"
      ;;
  esac

done
