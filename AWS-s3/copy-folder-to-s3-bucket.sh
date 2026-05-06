#!/usr/bin/env bash

set -euo pipefail

upload_file_to_s3() {
    local file_path="$1"
    local bucket_name="$2"
    local prefix="$3"
    local object_key

    object_key="$(basename "$file_path")"
    if [ -n "$prefix" ]; then
        object_key="$prefix/$object_key"
    fi

    aws s3 cp "$file_path" "s3://$bucket_name/$object_key"
}

upload_folder_to_s3() {
    local folder_path="$1"
    local bucket_name="$2"
    local prefix="$3"

    if [ -z "$prefix" ]; then
        prefix="$(basename "$folder_path")"
    fi

    aws s3 cp "$folder_path" "s3://$bucket_name/$prefix" --recursive
}

if ! command -v aws >/dev/null 2>&1; then
    echo "Error: aws CLI is not installed or not in PATH." >&2
    exit 1
fi

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source-path> <bucket-name[/prefix]>" >&2
    exit 1
fi

source_path="$1"
destination="$2"

bucket_name="${destination%%/*}"
if [ "$bucket_name" = "$destination" ]; then
    prefix=""
else
    prefix="${destination#*/}"
    prefix="${prefix#/}"
    prefix="${prefix%/}"
fi

if [ -z "$bucket_name" ]; then
    echo "Error: invalid destination bucket: $destination" >&2
    exit 1
fi

if [ ! -e "$source_path" ]; then
    echo "Error: source path does not exist: $source_path" >&2
    exit 1
fi

if [ -f "$source_path" ]; then
    upload_file_to_s3 "$source_path" "$bucket_name" "$prefix"
elif [ -d "$source_path" ]; then
    upload_folder_to_s3 "$source_path" "$bucket_name" "$prefix"
else
    echo "Error: source path must be a regular file or directory: $source_path" >&2
    exit 1
fi

