#!/bin/sh
while true; do
  echo "{\"version\": \"1.1\", \"host\": \"wireshark-scanner\", \"_type\": \"wireshark\", \"short_message\": \"Starting periodic tshark capture\"}"
  
  tshark -i "${SENSOR_INTERFACE:-eth0}" -a duration:"${CAPTURE_DURATION:-60}" -T ek -f "not port 12201 and not port 12202 and not port 12203 and not port 22 and not port 9000" > /tmp/capture.json 2>/dev/null
  
  cat /tmp/capture.json | grep '"layers"' | head -n 1000 | while read -r line; do
     echo "{\"version\": \"1.1\", \"host\": \"wireshark-scanner\", \"_type\": \"wireshark\", \"short_message\": \"tshark packet capture\", \"_packet\": ${line}}"
  done

  echo "{\"version\": \"1.1\", \"host\": \"wireshark-scanner\", \"_type\": \"wireshark\", \"short_message\": \"Finished periodic tshark capture\"}"
  sleep "${CAPTURE_INTERVAL:-300}"
done
