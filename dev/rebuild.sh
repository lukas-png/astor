#!/usr/bin/env bash
set -euo pipefail

echo "[*] Rebuild Astor (Java 8)"
/usr/local/bin/use-java8 >/dev/null 2>&1 || true
cd /opt/astor
mvn -DskipTests package
