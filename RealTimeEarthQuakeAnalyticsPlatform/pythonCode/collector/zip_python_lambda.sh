#!/bin/bash
# zip_python_lambda.sh
# Usage: ./zip_python_lambda.sh <source_dir> <output_zip>
# Example: ./zip_python_lambda.sh src lambda_collector.zip

set -e

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <source_dir> <output_zip>"
  exit 1
fi

SRC_DIR="$1"
OUTPUT_ZIP="$2"

# Remove old zip if exists
rm -f "$OUTPUT_ZIP"

# Create zip from source directory (Python files only)
cd "$SRC_DIR"
zip -r9 "../$OUTPUT_ZIP" . -i '*.py'
cd - > /dev/null

echo "Created $OUTPUT_ZIP from $SRC_DIR"
