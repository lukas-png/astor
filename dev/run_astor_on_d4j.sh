#!/usr/bin/env bash
set -euo pipefail

BUG="${1:-Lang-1}"                      # z.B. Lang-1
FAILING_TEST_RAW="${2:-}"
WORK="${3:-/work}"
MAXTIME="${MAXTIME:-60}"

# Bug checkout + compile
/usr/local/bin/use-java7 >/dev/null 2>&1 || true
/usr/local/bin/d4j-checkout "$BUG"

BUGDIR="${WORK}/${BUG}"
cd "$BUGDIR"
defects4j test

# If no failing test was provided, pull the first trigger from Defects4J metadata
if [[ -z "$FAILING_TEST_RAW" ]]; then
  TRIGGERS="$(defects4j export -p tests.trigger || true)"
  if [[ -z "$TRIGGERS" ]]; then
    echo "No failing test provided and tests.trigger is empty. Usage: $0 <BUG like Lang-1> <FAILING_TEST like a.b.C::testX>"
    exit 1
  fi
  FAILING_TEST_RAW="$(printf '%s\n' "$TRIGGERS" | head -n 1)"
  echo "[*] Using failing test from tests.trigger: $FAILING_TEST_RAW"
else
  echo "[*] Using failing test from argument: $FAILING_TEST_RAW"
fi

# Normalisieren: Astor will meistens Class#method
FAILING_TEST="${FAILING_TEST_RAW/::/#}"

# D4J Projektinfos exportieren
SRC="$(defects4j export -p dir.src.classes)"
TST="$(defects4j export -p dir.src.tests)"
BIN="$(defects4j export -p dir.bin.classes)"
BINT="$(defects4j export -p dir.bin.tests)"
DEPS="$(defects4j export -p cp.compile)"

# Manche Projekte brauchen cp.test statt cp.compile (falls Astor/Test-Klassen fehlen)
# -> optional fallback:
if [[ -z "$DEPS" ]]; then
  DEPS="$(defects4j export -p cp.test || true)"
fi

echo "[*] BUGDIR: $BUGDIR"
echo "[*] SRC:    $SRC"
echo "[*] TST:    $TST"
echo "[*] BIN:    $BIN"
echo "[*] BINT:   $BINT"
echo "[*] DEPS:   $DEPS"
echo "[*] FAILING_TEST: $FAILING_TEST"


#  Astor JAR Pfad bestimmen
ASTOR_JAR="${ASTOR_JAR:-/opt/astor/target/astor-*.jar}"

# Wenn mehrere JARs matchen, nimm das neueste
ASTOR_JAR_REAL="$(ls -1t $ASTOR_JAR 2>/dev/null | head -n 1 || true)"
if [[ -z "$ASTOR_JAR_REAL" ]]; then
  echo "Could not find Astor jar at: $ASTOR_JAR"
  echo "Build Astor first: (inside container) cd /opt/astor && mvn -DskipTests package"
  exit 1
fi

echo "[*] Using ASTOR_JAR: $ASTOR_JAR_REAL"


GZOLTAR_JAR_DIR="${GZOLTAR_JAR_DIR:-/opt/astor/lib}"

# WICHTIG: Astor läuft  mit Java 8
/usr/local/bin/use-java8 >/dev/null 2>&1 || true

java -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=*:5005 -Xmx4g -cp "$ASTOR_JAR_REAL" fr.inria.main.evolution.AstorMain -location . -mode jgenprog -scope package -failing "$FAILING_TEST" -dependencies "$DEPS" -srcjavafolder "$SRC" -srctestfolder "$TST" -binjavafolder "$BIN" -bintestfolder "$BINT" -maxtime "$MAXTIME" -stopfirst true -faultlocalization gzoltar -locationGzoltarJar "$GZOLTAR_JAR_DIR"
