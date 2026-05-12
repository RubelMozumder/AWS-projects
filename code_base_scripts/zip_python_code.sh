#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"

to_abs_path() {
  local path="$1"
  local project_name

  project_name="$(basename "$PROJECT_ROOT")"

  if [[ "$path" = /* ]]; then
    echo "$path"
  elif [[ "$path" == "$project_name"/* ]]; then
    echo "$REPO_ROOT/$path"
  elif [[ -e "$REPO_ROOT/$path" ]]; then
    echo "$REPO_ROOT/$path"
  else
    echo "$PROJECT_ROOT/$path"
  fi
}

# -----------------------------
# Default values
# -----------------------------
SRC_DIR="$PROJECT_ROOT/pythonCode/sqs_to_dynamodb/src"
REQUIREMENTS="$SRC_DIR/requirements.txt"
OUTPUT=""
BUILD_DIR="$PROJECT_ROOT/build/sqs_to_dynamodb"
PYTHON_BIN="python3"

# -----------------------------
# Help message
# -----------------------------
usage() {
  echo "Usage: $0 [-s src_dir] [-r requirements.txt] [-o output.zip] [-b build_dir] [-p python_bin]"
  echo ""
  echo "Options:"
  echo "  -s  Source directory (default: src)"
  echo "  -r  Requirements file (default: requirements.txt)"
  echo "  -o  Output zip file (default: <source_parent_folder>.zip)"
  echo "  -b  Build directory (default: build)"
  echo "  -p  Python binary (default: python3)"
  exit 1
}

# -----------------------------
# Parse CLI options
# -----------------------------
while getopts "s:r:o:b:p:h" opt; do
  case $opt in
    s) SRC_DIR="$OPTARG" ;;
    r) REQUIREMENTS="$OPTARG" ;;
    o) OUTPUT="$OPTARG" ;;
    b) BUILD_DIR="$OPTARG" ;;
    p) PYTHON_BIN="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

SRC_DIR="$(to_abs_path "$SRC_DIR")"
REQUIREMENTS="$(to_abs_path "$REQUIREMENTS")"
BUILD_DIR="$(to_abs_path "$BUILD_DIR")"

if [[ -z "$OUTPUT" ]]; then
  package_name="$(basename "$(dirname "$SRC_DIR")")"
  OUTPUT="$SRC_DIR/${package_name}.zip"
fi

OUTPUT="$(to_abs_path "$OUTPUT")"

if [[ -d "$OUTPUT" ]]; then
  package_name="$(basename "$(dirname "$SRC_DIR")")"
  OUTPUT="$OUTPUT/${package_name}.zip"
elif [[ "$OUTPUT" != *.zip ]]; then
  OUTPUT="${OUTPUT}.zip"
fi

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Source directory not found: $SRC_DIR"
  exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "zip command not found. Please install zip and rerun."
  exit 1
fi

echo "Building Lambda package..."
echo "Source: $SRC_DIR"
echo "Requirements: $REQUIREMENTS"
echo "Output: $OUTPUT"
echo "Build dir: $BUILD_DIR"
echo "Python: $PYTHON_BIN"

# -----------------------------
# Clean build directory
# -----------------------------
rm -rf "$BUILD_DIR"
rm -f "$OUTPUT"
mkdir -p "$BUILD_DIR"
mkdir -p "$(dirname "$OUTPUT")"

# -----------------------------
# Install dependencies
# -----------------------------
if [ -f "$REQUIREMENTS" ]; then
  echo "Installing dependencies..."
  $PYTHON_BIN -m pip install -r "$REQUIREMENTS" -t "$BUILD_DIR"
fi

# -----------------------------
# Copy source code
# -----------------------------
echo "Copying source code..."
for item in "$SRC_DIR"/* "$SRC_DIR"/.*; do
  [ -e "$item" ] || continue

  base_name="$(basename "$item")"
  if [[ "$base_name" == "." || "$base_name" == ".." ]]; then
    continue
  fi

  if [[ "$base_name" == "build" ]]; then
    continue
  fi

  item_abs="$(cd "$(dirname "$item")" && pwd)/$base_name"
  if [[ "$item_abs" == "$BUILD_DIR" || "$item_abs" == "$OUTPUT" ]]; then
    continue
  fi

  cp -r "$item" "$BUILD_DIR"/
done

# -----------------------------
# Create zip (important: zip contents, not folder)
# -----------------------------
echo "Creating zip..."
(
  cd "$BUILD_DIR"
  zip -r "$OUTPUT" .
)

echo "Done: $OUTPUT"