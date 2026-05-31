#!/bin/bash
# zip_and_upload_to_s3.sh

# Usage: ./zip_and_upload_to_s3.sh <source_dir> <output_zip> [<s3_bucket>] [<s3_key_prefix>]
# Example: ./zip_and_upload_to_s3.sh src lambda_collector.zip
# Example: ./zip_and_upload_to_s3.sh src lambda_collector.zip lambda-code-897035677417 eq-analytics/collector/

set -e

SRC_DIR="$1"
# zip file name
OUTPUT_ZIP="${2:-lambda_collector.zip}"
S3_BUCKET="${3:-lambda-code-897035677417}"
# without filename
S3_KEY_PREFIX="${4:-eq-analytics/collector/}"

if [ -z "$SRC_DIR" ] || [ -z "$OUTPUT_ZIP" ]; then
  echo "Usage: $0 <source_dir> <output_zip> [<s3_bucket>] [<s3_key_prefix>]"
  exit 1
fi

# Ensure S3_KEY_PREFIX ends with a slash
case "$S3_KEY_PREFIX" in
  */) : ;;
  *) S3_KEY_PREFIX="$S3_KEY_PREFIX/" ;;
esac

# Full S3 key includes prefix + file name
S3_KEY="$S3_KEY_PREFIX$OUTPUT_ZIP"

# Remove old zip if exists
rm -f "$OUTPUT_ZIP"

# Create zip from source directory (Python files only)
cd "$SRC_DIR"
zip -r9 "../$OUTPUT_ZIP" . -i '*.py'
cd - > /dev/null

echo "Created $OUTPUT_ZIP from $SRC_DIR"

# Upload to S3 (full key includes file name)
aws s3 cp "$OUTPUT_ZIP" "s3://$S3_BUCKET/$S3_KEY" --profile RubDev
echo "Uploaded $OUTPUT_ZIP to s3://$S3_BUCKET/$S3_KEY"