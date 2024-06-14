#!/bin/bash

CRIO_CONF_FILE="/etc/crio/crio.conf"

INSECURE_REGISTRIES="insecure_registries = [
 \"host.local:5000\"
]"

update_crio_conf() {
    local conf_content="$1"
    local conf_file="$2"

    minikube ssh "grep -qF '$conf_content' $conf_file || echo '$conf_content' | sudo tee -a $conf_file > /dev/null"
}

restart_crio() {
    minikube ssh "sudo systemctl restart crio"
}

echo "Updating CRI-O configuration..."
update_crio_conf "$INSECURE_REGISTRIES" "$CRIO_CONF_FILE"

echo "Restarting CRI-O..."
restart_crio

echo "Update and restart completed."
