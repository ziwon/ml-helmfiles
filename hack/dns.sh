#!/usr/bin/env bash

[ -f .env ] && source .env

HOSTS_FILE="/etc/hosts"
MINIKUBE_HOSTS_FILE="/etc/hosts"

add_dns_to_hosts() {
    local line="$1"
    local file="$2"

    if ! grep -qF "$line" "$file"; then
        echo "$line" | sudo tee -a "$file" > /dev/null
        echo "Added '$line' to $file"
    else
        echo "'$line' already exists in $file"
    fi
}

echo "Updating local /etc/hosts..."
add_dns_to_hosts "$DNS_HOST" "$HOSTS_FILE"
add_dns_to_hosts "$DNS_MINIKUBE" "$HOSTS_FILE"

echo "Updating Minikube /etc/hosts..."
minikube ssh "grep -qxF '$DNS_HOST' $MINIKUBE_HOSTS_FILE || echo '$DNS_HOST' | sudo tee -a $MINIKUBE_HOSTS_FILE > /dev/null"
minikube ssh "grep -qxF '$DNS_MINIKUBE' $MINIKUBE_HOSTS_FILE || echo '$DNS_MINIKUBE' | sudo tee -a $MINIKUBE_HOSTS_FILE > /dev/null"

echo "Updating CoreDNS..."
CURRENT_COREFILE=$(kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}')
INDENT="        " # 칼맞춤용 인덴트
PATCHED_COREFILE=$(echo "$CURRENT_COREFILE" | sed "/hosts {/,/fallthrough/ s/fallthrough/${DNS_HOST} \n${INDENT}${DNS_MINIKUBE}\n${INDENT}fallthrough/")

echo "Patched Corefile:"
echo "$PATCHED_COREFILE"

PATCHED_COREFILE_ESCAPED=$(echo "$PATCHED_COREFILE" | jq -sRr @json)

kubectl patch configmap coredns -n kube-system --type merge --patch "$(cat <<EOF
{
  "data": {
    "Corefile": $PATCHED_COREFILE_ESCAPED
  }
}
EOF
)"

echo "Update completed."
