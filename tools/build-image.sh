#!/usr/bin/env bash
# Baut pm4onco/cbioportal:<tag> reproduzierbar aus Core-Fork- und Frontend-Commits.
# Aufruf: tools/build-image.sh [tag]   (Standard: 7.1.1-ukf)
# Ueberschreibbar: CORE_DIR, FRONTEND_DIR, CORE_COMMIT, FRONTEND_COMMIT
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_DIR="${CORE_DIR:-$ROOT/../core-v7}"
FRONTEND_DIR="${FRONTEND_DIR:-$ROOT/../cbioportal-frontend}"
CORE_COMMIT="${CORE_COMMIT:-7fd8d81}"
CORE_BASE="d549d6ff4065e348eded87c5878ac5d1af570a6e"
FRONTEND_COMMIT="${FRONTEND_COMMIT:-e89b644b6}"
TAG="${1:-7.1.1-ukf}"
# Deployment-Pull-Name (privates GHCR-Package); nach dem Build fuer einen lokalen
# Test ohne Registry auch als "pm4onco/cbioportal:$TAG" retaggen.
IMAGE="ghcr.io/ukf-pauli/cbioportal-image"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src-core" "$WORK/ctx/core" "$WORK/ctx/frontend"

# Saubere Exporte der gepinnten Commits (lokale uncommittete Aenderungen fliessen nicht ein)
git -C "$CORE_DIR" merge-base --is-ancestor "$CORE_BASE" "$CORE_COMMIT" \
  || { echo "Core-Commit $CORE_COMMIT baut nicht auf $CORE_BASE auf" >&2; exit 1; }
git -C "$CORE_DIR" archive "$CORE_COMMIT" | tar -x -C "$WORK/src-core"
# Der Frontend-Build ruft git rev-parse auf, daher ein Klon statt eines Archivs
git clone -q --shared --no-checkout "$FRONTEND_DIR" "$WORK/src-fe"
git -C "$WORK/src-fe" checkout -q --detach "$FRONTEND_COMMIT"

# Core-Jar (Shade-Jar landet laut pom im Projektverzeichnis)
touch "$WORK/src-core/src/main/resources/application.properties"
docker run --rm -v "$WORK/src-core:/app" -w /app maven:3-eclipse-temurin-21 \
  mvn -q clean package -DskipTests
cp "$WORK/src-core"/core-*.jar "$WORK/ctx/core/core-IMPORTER.jar"
cp -R "$WORK/src-core/scripts" "$WORK/ctx/core/scripts"
cp "$WORK/src-core/requirements.txt" "$WORK/ctx/core/requirements.txt"

# Frontend-Build (Node 22.18, siehe cbioportal-frontend/.AGENTS)
# env/custom.sh ist lokal und nicht Teil des Commits; es wird bewusst nicht verwendet.
# shellcheck disable=SC1090
source "$HOME/.nvm/nvm.sh"
( cd "$WORK/src-fe" && nvm use 22.18.0 >/dev/null \
  && pnpm install --frozen-lockfile && pnpm run buildModules \
  && BRANCH_ENV=master pnpm run build )
cp -R "$WORK/src-fe/dist/reactapp" "$WORK/ctx/frontend/reactapp"

cp "$ROOT/image/Dockerfile" "$WORK/ctx/Dockerfile"
docker build \
  --build-arg CORE_COMMIT="$CORE_COMMIT" --build-arg CORE_BASE="$CORE_BASE" \
  --build-arg FRONTEND_COMMIT="$FRONTEND_COMMIT" \
  -t "$IMAGE:$TAG" -t "$IMAGE:$TAG-core$CORE_COMMIT-fe$FRONTEND_COMMIT" "$WORK/ctx"
docker image inspect "$IMAGE:$TAG" --format 'Image-ID: {{.Id}}'
