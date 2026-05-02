#!/bin/sh
set -eu

OSSEC_HOME=/var/ossec
OSSEC_SEED=/opt/ossec-seed

if [ ! -x "$OSSEC_HOME/bin/ossec-control" ]; then
    echo "Initializing OSSEC data volume at $OSSEC_HOME"
    mkdir -p "$OSSEC_HOME"
    cp -a "$OSSEC_SEED/." "$OSSEC_HOME/"
fi

cleanup() {
    "$OSSEC_HOME/bin/ossec-control" stop >/dev/null 2>&1 || true
    if [ -n "${AUTHD_PID:-}" ]; then
        kill "$AUTHD_PID" >/dev/null 2>&1 || true
    fi
}

trap cleanup INT TERM

"$OSSEC_HOME/bin/ossec-control" start

if [ "${OSSEC_AUTHD_ENABLED:-true}" = "true" ] && [ -x "$OSSEC_HOME/bin/ossec-authd" ]; then
    "$OSSEC_HOME/bin/ossec-authd" -p "${OSSEC_AUTHD_PORT:-1515}" ${OSSEC_AUTHD_OPTIONS:-} &
    AUTHD_PID=$!
fi

touch "$OSSEC_HOME/logs/ossec.log" "$OSSEC_HOME/logs/alerts/alerts.log"
tail -F "$OSSEC_HOME/logs/ossec.log" "$OSSEC_HOME/logs/alerts/alerts.log" &
TAIL_PID=$!

wait "$TAIL_PID"
