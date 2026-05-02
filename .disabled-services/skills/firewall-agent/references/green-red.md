# Green/Red Reference

IPFire Green/Red mode:

- RED: untrusted uplink.
- GREEN: protected service network.

Recommended stack values:

```text
IPFIRE_GREEN_IP=10.77.0.1
STACK_HOST_GREEN_IP=10.77.0.10
STACK_BIND_IP=10.77.0.10
```

Only ports in `firewall/allowed-ports.env` should be reachable inbound.
