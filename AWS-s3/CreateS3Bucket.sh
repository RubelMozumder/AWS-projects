#!/usr/bin/env bash

# -euo --> Exit immediately if a command exits with a non-zero status, 
# treat unset variables as an error, and prevent 
# errors in a pipeline from being masked.
set -euo pipefail

REGION="eu-central-1"

create_bucket_output() {
	local bucket_name="$1"

	aws s3api create-bucket \
		--bucket "$bucket_name" \
		--region "$REGION" \
		--create-bucket-configuration "LocationConstraint=$REGION"
}

if ! command -v aws >/dev/null 2>&1; then
	echo "Error: aws CLI is not installed or not in PATH." >&2
	exit 1
fi

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <bucket-name>" >&2
	exit 1
fi

create_bucket_output "$1"