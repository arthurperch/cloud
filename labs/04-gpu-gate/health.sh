#!/usr/bin/env bash
# Show LocalStack health as a clean table (only non-disabled services).
# For the recording: proves the gate's stack is up without the ugly JSON blob.
set -euo pipefail
curl -s localhost:4566/_localstack/health \
  | nu --stdin -c '$in | from json | get services | transpose service status | where status != "disabled" | sort-by service | select service status'
