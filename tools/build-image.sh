#!/usr/bin/env bash
# Baut das Produktions-Image (Backend + Core-Importer + Frontend-Bundle)
# reproduzierbar aus gepinnten Core- und Frontend-Revisions.
#
# Der Frontend-Build laeuft auf dem Runner (nvm/pnpm bzw. CI-Toolchain) und
# nur das fertige Bundle kommt in den Build-Kontext (das Frontend-.git ist
# ~450 MB). Das finale Image wird via docker buildx gebaut, damit CI
# Multi-Arch-Images pushen kann.
#
# Aufruf: tools/build-image.sh [tag]   (Standard: 7.1.1-ukf)
# Ueberschreibbar: CORE_REPO, CORE_REF, FRONTEND_REPO, FRONTEND_COMMIT,
#                  BRANCH_ENV, IMAGE, PLATFORMS, PUSH (1=push, 0=lade lokal)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_REPO="${CORE_REPO:-https://github.com/PM4Onco/cbioportal-core}"
CORE_REF="${CORE_REF:-v7.1.1-ukf}"
FRONTEND_REPO="${FRONTEND_REPO:-https://github.com/PM4Onco/cbioportal-frontend}"
CORE_BASE="d549d6ff4065e348eded87c5878ac5d1af570a6e"
# Branch-Name oder SHA; CI uebergibt branch-folgend den aufrufenden Branch.
FRONTEND_COMMIT="${FRONTEND_COMMIT:-7.1.1-ukf}"
BRANCH_ENV="${BRANCH_ENV:-master}"
IMAGE="${IMAGE:-ghcr.io/ukf-pauli/cbioportal-image}"
PUSH="${PUSH:-0}"
TAG="${1:-7.1.1-ukf}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
CTX="$WORK/ctx"
mkdir -p "$CTX/core" "$CTX/frontend"

# Core: sauberer Klon der gepinnten Ref (Branch oder SHA); lokale Aenderungen
# in einem Workspace fliegen damit nicht ins Image.
git clone -q "$CORE_REPO" "$WORK/src-core"
git -C "$WORK/src-core" checkout -q --detach "$CORE_REF"
CORE_COMMIT="$(git -C "$WORK/src-core" rev-parse HEAD)"
git -C "$WORK/src-core" merge-base --is-ancestor "$CORE_BASE" "$CORE_COMMIT" \
  || { echo "Core-Commit $CORE_COMMIT baut nicht auf $CORE_BASE auf" >&2; exit 1; }

# Core-Jar (Shade-Jar landet laut pom im Projektverzeichnis)
touch "$WORK/src-core/src/main/resources/application.properties"
docker run --rm -v "$WORK/src-core:/app" -w /app maven:3-eclipse-temurin-21 \
  mvn -q clean package -DskipTests
cp "$WORK/src-core"/core-*.jar "$CTX/core/core-IMPORTER.jar"
cp -R "$WORK/src-core/scripts" "$CTX/core/scripts"
cp "$WORK/src-core/requirements.txt" "$CTX/core/requirements.txt"

# Frontend: Build in einem sauberen Klon auf dem Runner. Der Frontend-Build
# ruft git rev-parse auf, daher ein echtes Repo (kein Archiv); env/custom.sh
# ist lokal und wird bewusst nicht verwendet.
git clone -q --no-checkout "$FRONTEND_REPO" "$WORK/src-fe"
# 'clone --no-checkout' laesst HEAD unbelegt; Git >= 2.54 erlaubt dann kein
# 'checkout --detach <Branch>', solange kein lokaler Branch existiert.
if git -C "$WORK/src-fe" show-ref --quiet "refs/remotes/origin/$FRONTEND_COMMIT"; then
  git -C "$WORK/src-fe" branch -f "$FRONTEND_COMMIT" "origin/$FRONTEND_COMMIT"
fi
git -C "$WORK/src-fe" checkout -q --detach "$FRONTEND_COMMIT"
# Node 22.23.4 + pnpm: lokal ueber nvm, in CI ueber die vorbereitete PATH.
if [ -f "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck disable=SC1090
  source "$HOME/.nvm/nvm.sh"
  nvm use 22.23.4 >/dev/null
fi
( cd "$WORK/src-fe" \
  && pnpm install --frozen-lockfile && pnpm run buildModules \
  && BRANCH_ENV="$BRANCH_ENV" pnpm run build )
cp -R "$WORK/src-fe/dist/reactapp" "$CTX/frontend/reactapp"

# Final-Image via buildx: PUSH=1 multi-Arch nach Registry, sonst
# Single-Arch in den lokalen Docker laden.
BUILDX=(buildx build -f "$ROOT/services/cbioportal/Dockerfile")
for pair in CORE_REPO CORE_REF CORE_COMMIT CORE_BASE FRONTEND_COMMIT BRANCH_ENV; do
  BUILDX+=(--build-arg "$pair=${!pair}")
done
BUILDX+=(-t "$IMAGE:$TAG" -t "$IMAGE:$TAG-core$CORE_COMMIT-fe$FRONTEND_COMMIT")
if [ "$PUSH" = "1" ]; then
  BUILDX+=(--platform "${PLATFORMS:-linux/amd64,linux/arm64}" --push)
  # Mit docker-container-Buildern hat BuildKit keinen Zugriff auf den
  # Host-Credential-Store; Registry-Auth kommt daher per Secret.
  if [ -n "${REG_AUTH:-}" ]; then
    BUILDX+=(--secret "id=regauth,src=$REG_AUTH")
  fi
else
  BUILDX+=(--load)
fi
docker "${BUILDX[@]}" "$CTX"
if [ "$PUSH" != "1" ]; then
  docker image inspect "$IMAGE:$TAG" --format 'Image-ID: {{.Id}}'
fi
