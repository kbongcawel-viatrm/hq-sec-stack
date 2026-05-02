path "secret/data/hq-sec-stack/*" {
  capabilities = ["create", "update", "read", "list"]
}

path "secret/metadata/hq-sec-stack/*" {
  capabilities = ["read", "list", "update"]
}

path "sys/tools/random/*" {
  capabilities = ["update"]
}
