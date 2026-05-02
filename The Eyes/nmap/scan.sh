#!/bin/sh
while true; do
  echo "{\"_type\": \"nmap\", \"short_message\": \"Starting Nmap scan\", \"target\": \"${SCAN_TARGET:-10.77.0.0/24}\"}"
  nmap -T4 -F ${SCAN_TARGET:-10.77.0.0/24} -oX /tmp/scan.xml > /dev/null
  
  python3 -c '
import xml.etree.ElementTree as ET
import json
import sys

try:
    tree = ET.parse("/tmp/scan.xml")
    root = tree.getroot()
    for host in root.findall("host"):
        status = host.find("status").get("state")
        if status != "up": continue
        
        address_elem = host.find("address")
        if address_elem is None: continue
        address = address_elem.get("addr")
        
        ports = []
        port_elems = host.find("ports")
        if port_elems is not None:
            for p in port_elems.findall("port"):
                state_elem = p.find("state")
                if state_elem is not None and state_elem.get("state") == "open":
                    portid = p.get("portid")
                    protocol = p.get("protocol")
                    service = p.find("service")
                    svc_name = service.get("name") if service is not None else "unknown"
                    ports.append(f"{portid}/{protocol} ({svc_name})")
        
        if ports:
            doc = {
                "version": "1.1",
                "host": "nmap-scanner",
                "_type": "nmap",
                "short_message": f"Nmap host up: {address}",
                "_host_ip": address,
                "_open_ports": ", ".join(ports)
            }
            print(json.dumps(doc))
except Exception as e:
    print(json.dumps({"version": "1.1", "host": "nmap-scanner", "_type": "nmap", "short_message": "Error parsing nmap xml", "_error": str(e)}))
'
  echo "{\"_type\": \"nmap\", \"short_message\": \"Finished Nmap scan\"}"
  sleep "${SCAN_INTERVAL:-3600}"
done
