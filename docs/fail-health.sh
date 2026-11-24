#!/bin/sh
set -eu
date -u +%Y-%m-%dT%H:%M:%SZ
touch /tmp/unhealthy.flag
curl -sS -o /dev/null -w 'health=%{http_code}\n' http://127.0.0.1/health
