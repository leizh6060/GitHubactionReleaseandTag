#!/usr/bin/env bash
# ------------------------------------------------------------------
# next-version.sh
#   Decides the next semver based on Conventional Commits since the
#   last tag. Outputs (in GITHUB_OUTPUT):
#     new_version   - next semver (e.g. 1.4.2)
#     bump          - major | minor | patch | none
#     reason        - human-readable reason for the bump
#   Honors workflow_dispatch "release_type" input (forces the bump).
# ------------------------------------------------------------------
set -euo pipefail

EVENT_NAME="${EVENT_NAME:-push}"
FORCE_TYPE="${FORCE_TYPE:-}"
PREV_TAG="${PREV_TAG:-}"

# ---- 1. Read previous version (from tag, fallback to package.json, fallback to 0.0.0)
if [ -n "${PREV_TAG}" ]; then
  CUR_VERSION="${PREV_TAG#v}"
else
  if [ -f package.json ]; then
    CUR_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0")
  else
    CUR_VERSION="0.0.0"
  fi
fi

# ---- 2. Collect commit subjects since the last tag
if [ -n "${PREV_TAG}" ]; then
  RANGE="${PREV_TAG}..HEAD"
else
  RANGE="HEAD"
fi
mapfile -t SUBJECTS < <(git log --no-merges --pretty=format:"%s" "${RANGE}" 2>/dev/null || true)

if [ "${#SUBJECTS[@]}" -eq 0 ]; then
  echo "new_version=${CUR_VERSION}"  >> "$GITHUB_OUTPUT"
  echo "bump=none"                    >> "$GITHUB_OUTPUT"
  echo "reason=No commits to release" >> "$GITHUB_OUTPUT"
  echo "No commits since last tag; nothing to release."
  exit 0
fi

# ---- 3. Classify commits
has_breaking=0
has_feat=0
has_fix=0
has_other=0
chore_only=1
for s in "${SUBJECTS[@]}"; do
  case "$s" in
    "!"*)                  has_breaking=1; chore_only=0 ;;
    *"!"*)                 has_breaking=1; chore_only=0 ;;
    feat*"!"*|feat*":"* )  has_feat=1; chore_only=0 ;;
    fix*"!"*|fix*":"* )    has_fix=1; chore_only=0 ;;
    feat*)                 has_feat=1; chore_only=0 ;;
    fix*)                  has_fix=1; chore_only=0 ;;
    *)                     has_other=1 ;;
  esac
done

# ---- 4. Decide bump type
BUMP="none"
REASON=""
if [ "${EVENT_NAME}" = "workflow_dispatch" ] && [ -n "${FORCE_TYPE}" ]; then
  BUMP="${FORCE_TYPE}"
  REASON="Forced by manual dispatch (${FORCE_TYPE})"
elif [ "${has_breaking}" -eq 1 ]; then
  BUMP="major"; REASON="Breaking change detected"
elif [ "${has_feat}" -eq 1 ]; then
  BUMP="minor"; REASON="New feature detected"
elif [ "${has_fix}" -eq 1 ]; then
  BUMP="patch"; REASON="Bug fix detected"
elif [ "${chore_only}" -eq 0 ]; then
  BUMP="patch"; REASON="Other change detected (perf/refactor/test/build/ci/docs)"
else
  BUMP="none"
  REASON="Only docs/chore/style/ci commits since last tag"
fi

# ---- 5. Compute the new semver
IFS='.' read -r MAJOR MINOR PATCH <<<"${CUR_VERSION}"
MAJOR=${MAJOR:-0}; MINOR=${MINOR:-0}; PATCH=${PATCH:-0}
case "${BUMP}" in
  major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR+1)); PATCH=0 ;;
  patch) PATCH=$((PATCH+1)) ;;
  none)  NEW_VERSION="${CUR_VERSION}" ;;
  *) echo "Unknown bump type: ${BUMP}" >&2; exit 1 ;;
esac
NEW_VERSION="${NEW_VERSION:-${MAJOR}.${MINOR}.${PATCH}}"

echo "new_version=${NEW_VERSION}"      >> "$GITHUB_OUTPUT"
echo "bump=${BUMP}"                    >> "$GITHUB_OUTPUT"
echo "reason=${REASON}"                >> "$GITHUB_OUTPUT"
echo "previous=${CUR_VERSION}"
echo "subjects=${#SUBJECTS[@]}"
echo "breaking=${has_breaking} feat=${has_feat} fix=${has_fix}"
echo "bump=${BUMP} -> ${NEW_VERSION} (${REASON})"
