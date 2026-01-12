#!/usr/bin/env bash
set -euo pipefail

echo "[*] Rebuild Astor (Java 8)"
. /usr/local/bin/use-java8 || echo "Warning: use-java8 script failed or not found"
java -version
cd /opt/astor
mvn -DskipTests package
