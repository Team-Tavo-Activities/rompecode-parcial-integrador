#!/bin/sh
set -eu
rm -f /tmp/unhealthy.flag
date -u +%Y-%m-%dT%H:%M:%SZ
curl -sS -o /dev/null -w 'health=%{http_code}\n' http://127.0.0.1/health
