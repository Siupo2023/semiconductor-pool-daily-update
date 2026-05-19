#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="semiconductor-pool-daily-update"
DEFAULT_TARGET_ROOT="${HOME}/.openclaw/skills"
TARGET_ROOT="${TARGET_ROOT:-$DEFAULT_TARGET_ROOT}"
TARGET_DIR="${TARGET_DIR:-${TARGET_ROOT}/${SKILL_NAME}}"

usage() {
  cat <<EOF
Install ${SKILL_NAME} into a local CLI skills directory.

Usage:
  bash install.sh
  bash install.sh --target-root "\$HOME/.openclaw/skills"
  bash install.sh --target-dir "/custom/path/${SKILL_NAME}"

Options:
  --target-root PATH   Parent skills directory. Default: ${DEFAULT_TARGET_ROOT}
  --target-dir PATH    Full install path for this skill.
  --force              Replace an existing target directory.
  -h, --help           Show this help message.
EOF
}

FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-root)
      TARGET_ROOT="$2"
      TARGET_DIR="${TARGET_ROOT}/${SKILL_NAME}"
      shift 2
      ;;
    --target-dir)
      TARGET_DIR="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$(dirname "$TARGET_DIR")"

if [[ -e "$TARGET_DIR" ]]; then
  if [[ "$FORCE" != "1" ]]; then
    echo "target already exists: $TARGET_DIR" >&2
    echo "rerun with --force to replace it" >&2
    exit 1
  fi
  rm -rf "$TARGET_DIR"
fi

mkdir -p "$TARGET_DIR"

copy_tree() {
  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude '.git' \
      --exclude '.DS_Store' \
      "${SCRIPT_DIR}/" \
      "${TARGET_DIR}/"
  else
    cp -R "${SCRIPT_DIR}/." "${TARGET_DIR}/"
    rm -rf "${TARGET_DIR}/.git"
  fi
}

copy_tree

chmod +x "${TARGET_DIR}/install.sh" "${TARGET_DIR}/scripts/semiconductor_daily_update.sh"

cat <<EOF
Installed ${SKILL_NAME} to:
${TARGET_DIR}

Run it with:
bash "${TARGET_DIR}/scripts/semiconductor_daily_update.sh"
EOF
