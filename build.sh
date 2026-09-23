#!/usr/bin/env bash
#
# build.sh - Build LaTeX documents with lualatex + biber.
#
# Usage: ./build.sh [options] [file.tex ...]
#   With no file arguments, targets main.tex plus every subfile in sections/.
#   With file arguments, targets only the given .tex file(s).
#
# Options:
#   -c, --clean      Remove the target(s)' build directories and exit (no build)
#   -r, --rebuild    Remove the target(s)' build directories, then build
#   -h, --help       Show this help
#
# Each file's build artifacts are placed alongside it, in a sibling
# "<file>-build/" directory (e.g. main-build/, sections/facilities-build/).
# Files in sections/ are subfiles (see subfiles package in main.tex) and
# are built standalone, inheriting main.tex's preamble.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
}

build_dir_for() {
  local tex_path="$1"
  local dir basename
  dir="$(dirname "$tex_path")"
  basename="$(basename "$tex_path" .tex)"
  if [ "$dir" = "." ]; then
    echo "${basename}-build"
  else
    echo "${dir}/${basename}-build"
  fi
}

clean_one() {
  local tex_path="$1"
  local build_dir
  build_dir="$(build_dir_for "$tex_path")"
  if [ -d "$build_dir" ]; then
    rm -rf "$build_dir"
    echo "Cleaned: ${build_dir}/"
  else
    echo "Nothing to clean: ${build_dir}/ does not exist"
  fi
}

build_one() {
  local tex_path="$1"
  local basename build_dir
  basename="$(basename "$tex_path" .tex)"
  build_dir="$(build_dir_for "$tex_path")"

  echo "Building ${tex_path} -> ${build_dir}/ ..."

  if ! latexmk \
    -lualatex \
    -interaction=nonstopmode \
    -halt-on-error \
    -file-line-error \
    -cd \
    -outdir="$(basename "$build_dir")" \
    "$tex_path"; then
    echo "Build failed: ${tex_path}" >&2
    return 1
  fi

  if [ -f "${build_dir}/${basename}.pdf" ]; then
    echo "Build succeeded: ${build_dir}/${basename}.pdf"
  else
    echo "Build failed: ${tex_path} (no PDF produced)" >&2
    return 1
  fi
}

MODE="build"
ARGS=()
for arg in "$@"; do
  case "$arg" in
    -c|--clean)
      MODE="clean"
      ;;
    -r|--rebuild)
      MODE="rebuild"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      ;;
    *)
      ARGS+=("$arg")
      ;;
  esac
done

if [ "${#ARGS[@]}" -gt 0 ]; then
  TARGETS=("${ARGS[@]}")
else
  TARGETS=("main.tex")
  for f in sections/*.tex; do
    [ -e "$f" ] && TARGETS+=("$f")
  done
fi

if [ "$MODE" = "clean" ] || [ "$MODE" = "rebuild" ]; then
  for target in "${TARGETS[@]}"; do
    clean_one "$target"
  done
fi

if [ "$MODE" = "clean" ]; then
  exit 0
fi

FAILED=()
for target in "${TARGETS[@]}"; do
  if ! build_one "$target"; then
    FAILED+=("$target")
  fi
done

echo
if [ "${#FAILED[@]}" -eq 0 ]; then
  echo "All builds succeeded (${#TARGETS[@]} file(s))."
else
  echo "Failed builds: ${FAILED[*]}" >&2
  exit 1
fi
