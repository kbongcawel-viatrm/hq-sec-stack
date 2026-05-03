FROM alpine:3.20

RUN apk add --no-cache nmap tshark jq curl python3

COPY nmap/scan.sh /usr/local/bin/scan.sh
COPY wireshark/capture.sh /usr/local/bin/capture.sh

RUN chmod +x /usr/local/bin/scan.sh /usr/local/bin/capture.sh
