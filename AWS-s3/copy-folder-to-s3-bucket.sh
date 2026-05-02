#!/usr/bin/env bash

set -euo pipefail

copy_folder_to_s3_bucket() {
    local folder_path="$1"
    local bucket_name="$2"
    local prefix

    prefix="$(basename "$folder_path")"

    aws s3 cp "$folder_path" "s3://$bucket_name/$prefix" --recursive
}

if ! command -v aws >/dev/null 2>&1; then
    echo "Error: aws CLI is not installed or not in PATH." >&2
    exit 1
fi

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <folder-path> <bucket-name>" >&2
    exit 1
fi

folder_path="$1"
bucket_name="$2"

if [ ! -d "$folder_path" ]; then
    echo "Error: folder path does not exist or is not a directory: $folder_path" >&2
    exit 1
fi

copy_folder_to_s3_bucket "$folder_path" "$bucket_name"

