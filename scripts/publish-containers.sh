#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# publish-containers.sh — one-command multi-arch publish for xdaco-ultimate
#
# For each image it builds every target platform into a single manifest list
# and pushes it as :latest + an immutable :YYYY-MM-DD tag. `manifest push --all`
# uploads the per-arch images AND the manifest list, so :latest is never a
# single-arch image.
#
# base is built first and tagged locally as :latest, so the cpp/php images
# (which are FROM base:latest) resolve to the freshly built base.
#
# Usage:
#   scripts/publish-containers.sh [options] [image ...]
#
# Images (default: all, in order):  base cpp php
#
# Options:
#   -r, --registry REG    Registry        (default: docker.io,    env REGISTRY)
#   -n, --namespace NS    Namespace       (default: 1xdaco,       env NAMESPACE)
#   -p, --platforms LIST  Platform list   (default: linux/amd64,linux/arm64, env PLATFORMS)
#   -t, --tag TAG         Immutable tag   (default: UTC YYYY-MM-DD, env DATE_TAG)
#       --no-latest       Do not also push/update the :latest tag
#       --no-push         Build the manifest locally but do not push
#   -h, --help            Show this help
#
# Examples:
#   scripts/publish-containers.sh                 # build+push all, both arches
#   scripts/publish-containers.sh base cpp        # only base and cpp
#   scripts/publish-containers.sh --no-push base  # local multi-arch build only
#   PLATFORMS=linux/arm64 scripts/publish-containers.sh --no-latest base
#
# Note: building a non-native arch (e.g. amd64 on an Apple Silicon Mac) requires
# QEMU emulation inside the podman machine and is slow for source-compiled layers.
# -----------------------------------------------------------------------------
set -euo pipefail

REGISTRY="${REGISTRY:-docker.io}"
NAMESPACE="${NAMESPACE:-1xdaco}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
DATE_TAG="${DATE_TAG:-$(date -u +%Y-%m-%d)}"
PUSH=1
PUSH_LATEST=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTAINERS_DIR="$REPO_ROOT/containers"

usage() { sed -n '2,/^# ---* *$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

# Map an image short name to its build context (portable: no associative arrays).
context_for() {
  case "$1" in
    base) printf '%s\n' "$CONTAINERS_DIR/xdaco-ultimate-base" ;;
    cpp)  printf '%s\n' "$CONTAINERS_DIR/xdaco-ultimate-cpp" ;;
    php)  printf '%s\n' "$CONTAINERS_DIR/xdaco-ultimate-php" ;;
    *)    return 1 ;;
  esac
}

IMAGES=()
while [ $# -gt 0 ]; do
  case "$1" in
    -r|--registry)  REGISTRY="$2"; shift 2 ;;
    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
    -p|--platforms) PLATFORMS="$2"; shift 2 ;;
    -t|--tag)       DATE_TAG="$2"; shift 2 ;;
    --no-latest)    PUSH_LATEST=0; shift ;;
    --no-push)      PUSH=0; shift ;;
    -h|--help)      usage; exit 0 ;;
    base|cpp|php)   IMAGES+=("$1"); shift ;;
    *) echo "error: unknown argument: $1" >&2; echo "run with --help" >&2; exit 1 ;;
  esac
done
[ ${#IMAGES[@]} -eq 0 ] && IMAGES=(base cpp php)

command -v podman >/dev/null 2>&1 || { echo "error: podman not found in PATH" >&2; exit 1; }

if [ "$PUSH" -eq 1 ] && ! podman login --get-login "$REGISTRY" >/dev/null 2>&1; then
  echo "error: not logged in to $REGISTRY — run: podman login $REGISTRY" >&2
  exit 1
fi

build_one() {
  short="$1"
  ctx="$(context_for "$short")" || { echo "error: unknown image: $short" >&2; exit 1; }
  repo="$REGISTRY/$NAMESPACE/xdaco-ultimate-$short"
  dated="$repo:$DATE_TAG"
  latest="$repo:latest"

  echo "==> [$short] build $dated  [$PLATFORMS]"
  podman manifest exists "$dated" >/dev/null 2>&1 && podman manifest rm "$dated" >/dev/null
  podman build --platform "$PLATFORMS" --manifest "$dated" "$ctx"

  # Refresh local :latest so a downstream image's FROM uses this fresh build.
  podman manifest exists "$latest" >/dev/null 2>&1 && podman manifest rm "$latest" >/dev/null
  podman tag "$dated" "$latest"

  if [ "$PUSH" -eq 1 ]; then
    echo "==> [$short] push $dated"
    podman manifest push --all "$dated" "docker://$dated"
    if [ "$PUSH_LATEST" -eq 1 ]; then
      echo "==> [$short] push $latest"
      podman manifest push --all "$latest" "docker://$latest"
    fi
  fi
}

for img in "${IMAGES[@]}"; do
  build_one "$img"
done

echo "Done. images=[${IMAGES[*]}] tag=$DATE_TAG platforms=$PLATFORMS push=$PUSH latest=$PUSH_LATEST"
