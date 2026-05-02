#!/bin/sh
set -eu

api="${GRAYLOG_API_URL:-http://graylog:9000/api}"
user="${GRAYLOG_ROOT_USERNAME:-admin}"
pass="${GRAYLOG_ROOT_PASSWORD:-admin}"

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

post_input() {
  title="$1"
  type="$2"
  port="$3"
  payload="/tmp/${title}.json"
  cat > "${payload}" <<JSON
{
  "title": "${title}",
  "type": "${type}",
  "global": true,
  "configuration": {
    "bind_address": "0.0.0.0",
    "port": ${port},
    "recv_buffer_size": 262144,
    "number_worker_threads": 2,
    "override_source": null
  }
}
JSON
  status="$(curl -sS -o /tmp/graylog-input-response.txt -w '%{http_code}' \
    -u "${user}:${pass}" \
    -H "X-Requested-By: hq-sec-stack" \
    -H "Content-Type: application/json" \
    -X POST "${api}/system/inputs" \
    --data-binary @"${payload}" || true)"

  case "${status}" in
    200|201|202)
      log "created Graylog input ${title}"
      ;;
    400|409)
      log "Graylog input ${title} may already exist or conflict: $(cat /tmp/graylog-input-response.txt)"
      ;;
    *)
      log "Graylog input ${title} returned HTTP ${status}: $(cat /tmp/graylog-input-response.txt)"
      ;;
  esac
}

until curl -fsS -u "${user}:${pass}" -H "X-Requested-By: hq-sec-stack" "${api}/system/lbstatus" >/dev/null; do
  log "waiting for Graylog API at ${api}"
  sleep 10
done

post_input "hq-sec-gelf-udp" "org.graylog2.inputs.gelf.udp.GELFUDPInput" "${GRAYLOG_GELF_UDP_PORT:-12201}"
post_input "hq-sec-nmap-gelf" "org.graylog2.inputs.gelf.udp.GELFUDPInput" "12202"
post_input "hq-sec-wireshark-gelf" "org.graylog2.inputs.gelf.udp.GELFUDPInput" "12203"
post_input "hq-sec-syslog-udp" "org.graylog2.inputs.syslog.udp.SyslogUDPInput" "${GRAYLOG_SYSLOG_INPUT_PORT:-1514}"
post_input "hq-sec-syslog-tcp" "org.graylog2.inputs.syslog.tcp.SyslogTCPInput" "${GRAYLOG_SYSLOG_INPUT_PORT:-1514}"

log "Graylog input bootstrap completed"
