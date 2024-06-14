#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")

[ ! -f .env ] || export $(grep -v '^#' .env | xargs)

# Podman에 레지스트리 컨테이너 추가
echo "Starting registry container..."
sudo podman run --privileged -d \
  --replace \
  --name registry \
  -p 5000:5000 \
  -v /var/lib/registry:/var/lib/registry \
  -v ${SCRIPT_DIR}/config.yml:/etc/docker/registry/config.yml \
  --restart=always \
  registry:2
echo "Registry container started."

# Podman을 업데이트하여 인시큐어 레지스트리에 대해 동작
sudo tee -a /etc/containers/registries.conf <<EOF
[[registry]]
location = "${REGISTRY_URL}"
insecure = true
EOF

minikube ssh -- 'REGISTRY_URL=$REGISTRY_URL; sudo tee -a /etc/containers/registries.conf <<EOF
[[registry]]
location = "${REGISTRY_URL}"
insecure = true
EOF'
