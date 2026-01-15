#!/usr/bin/env bash
set -e

# Helper script for Astor Remote Docker setup
# Usage: ./remote.sh [build|run|test|shell] [args...]

COMPOSE_FILE="dev/compose-remote.yml"
SERVICE="astor-remote"

# Change to project root if script is run from dev/
if [[ -f "compose-remote.yml" ]]; then
    cd ..
fi

case "$1" in
    "build")
        echo "[*] Building Remote Docker Image..."
        docker compose -f "$COMPOSE_FILE" build
        ;;
    "run")
        # Usage: ./remote.sh run Lang-1
        BUG="${2:-Lang-1}"
        echo "[*] Running Astor on $BUG in Remote Docker..."
        # We mount nothing, just run the script that is inside the image
        # disable suspend so it runs immediately
        docker compose -f "$COMPOSE_FILE" run --rm -e DEBUG_SUSPEND=n "$SERVICE" \
            /opt/astor/dev/run_astor_on_d4j.sh "$BUG"
        ;;
    "debug")
        # Usage: ./remote.sh debug Lang-1
        BUG="${2:-Lang-1}"
        echo "[*] Running Astor on $BUG in Remote Docker (Waiting for Debugger on 5005)..."
        docker compose -f "$COMPOSE_FILE" run --rm -p 5005:5005 -e DEBUG_SUSPEND=y "$SERVICE" \
            /opt/astor/dev/run_astor_on_d4j.sh "$BUG"
        ;;
    "test-all")
        echo "[*] Running Astor Unit Tests..."
        docker compose -f "$COMPOSE_FILE" run --rm "$SERVICE" \
            /bin/bash -c "source /usr/local/bin/use-java8 && cd /opt/astor && mvn test"
        ;;
    "validate")
        # Usage: ./remote.sh validate Lang-1
        BUG="${2:-Lang-1}"
        echo "[*] Validating $BUG (Checkout + Verify Failing Tests)..."
        # We use the internal d4j-checkout helper, then run defects4j test
        docker compose -f "$COMPOSE_FILE" run --rm "$SERVICE" \
            /bin/bash -c "/usr/local/bin/d4j-checkout $BUG && cd /work/$BUG && echo '[*] Running defects4j test...' && defects4j test"
        ;;
    "run-project")
        # Usage: ./remote.sh run-project Lang
        PROJECT="${2}"
        if [[ -z "$PROJECT" ]]; then
            echo "Usage: $0 run-project <Project> (e.g. Lang, Math, Time, Chart, Closure, Mockito)"
            exit 1
        fi

        echo "[*] Fetching bug IDs for project: $PROJECT ..."
        # Query defects4j for all bug IDs of the project.
        # We expect a list of numbers. filtering with grep to avoid noise.
        # || true is important because if grep finds nothing it exits with 1
        BUG_IDS=$(docker compose -f "$COMPOSE_FILE" run --rm "$SERVICE" \
            /bin/bash -c "defects4j query -p $PROJECT -q bug.id" | tr -d '\r' | grep -E '^[0-9]+$' | sort -n || true)

        if [[ -z "$BUG_IDS" ]]; then
            echo "No bugs found for project '$PROJECT'. Check project name."
            exit 1
        fi

        COUNT=$(echo "$BUG_IDS" | wc -w)
        echo "[*] Found $COUNT bugs. Starting sequential execution..."

        for id in $BUG_IDS; do
            BUG="${PROJECT}-${id}"
            echo "========================================"
            echo "[*] Processing $BUG ..."
            echo "========================================"

            # Run Astor. If it fails (exit code != 0), we print error but continue loop.
            docker compose -f "$COMPOSE_FILE" run --rm -e DEBUG_SUSPEND=n "$SERVICE" \
                /opt/astor/dev/run_astor_on_d4j.sh "$BUG" || echo "(!) Error processing $BUG - check logs. Continuing..."
        done
        ;;
    "shell")
        echo "[*] Opening Shell in neuem Container..."
        docker compose -f "$COMPOSE_FILE" run --rm "$SERVICE" /bin/bash
        ;;
    "attach")
        echo "[*] Versuche, eine Shell in einen laufenden Container zu öffnen..."
        # Container-Name automatisch ermitteln
        CONTAINER_ID=$(docker ps --filter "name=${SERVICE}" --filter "status=running" --format "{{.ID}}" | head -n 1)
        if [[ -z "$CONTAINER_ID" ]]; then
            echo "Kein laufender Container für $SERVICE gefunden. Starte zuerst einen Container mit 'run' oder 'debug'."
            exit 1
        fi
        docker exec -it "$CONTAINER_ID" /bin/bash
        ;;
    *)
        echo "Usage: $0 {build|run|debug|test-all|shell}"
        echo "  build       - Rebuild the Docker image (with current code)"
        echo "  run <bug>   - Run Astor on a bug (e.g. Lang-1) - No Debugger wait"
        echo "  debug <bug> - Run Astor on a bug and WAIT for Debugger on port 5005"
        echo "  test-all    - Run all Astor unit tests (mvn test)"
        echo "  validate <bug> - Checkout a bug and run 'defects4j test' (verify reproduction)"
        echo "  run-project <Proj> - Run Astor on ALL bugs of a project (sequentially)"
        echo "  context [name] - List or switch Docker contexts"
        echo "  shell       - interactive bash"
        exit 1
        ;;
esac
