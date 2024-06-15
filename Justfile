set dotenv-load

default:
  @just --list

[group('prep')]
podman:
  echo 'deb http://download.opensuse.org/repositories/home:/alvistack/${OS}/ /' | sudo tee /etc/apt/sources.list.d/home:alvistack.list
  curl -fsSL https://download.opensuse.org/repositories/home:alvistack/${OS}/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_alvistack.gpg > /dev/null
  sudo apt update
  sudo apt install -y podman

  sudo cp /etc/sudoers /etc/sudoers.$(date +"%Y%m%d-%H%M%S").bak
  echo "%sudo ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
  sudo -k -n podman version

[group('prep')]
crio:
  echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${OS}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
  echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${CRIO_VERSION}/${OS}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:{CRIO_VERSION}.list

  sudo mkdir -p /usr/share/keyrings
  curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS$/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
  curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${CRIO_VERSION}/${OS}/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg

  sudo apt update -qq
  sudo apt install -y fuse-overlayfs containernetworking-plugins
  sudo apt install -y cri-o cri-o-runc

[group('prep')]
asdf:
  @hack/asdf.sh

[group('prep')]
nfs:
  @hack/nfs-server.sh
  @minikube ssh -- sudo sh -c "apt update && apt install -y nfs-common"

[group('prep')]
dns:
  @hack/dns.sh

[group('prep')]
registry:
  @hack/registry/registry.sh
  @hack/registry/crio.sh

[group('prep')]
registry-ok:
  @minikube ssh -- curl -XGET -k http://${REGISTRY_URL}/ -I

[group('k8s')]
k8s-up:
  @minikube start --v=6 --driver=podman --container-runtime=cri-o --memory 8192 --cpus 8 --disk-size 80g --network-plugin=cni --kubernetes-version=v${K8S_VERSION}

[group('k8s')]
k8s-down:
  minikube stop || true
  minikube delete || true
  rm -rf ~/.minikube || true
  podman system reset

[group('docker')]
docker-build APP="${DOCKER_TRAIN_IMAGE}":
  @echo "Building {{APP}}..."; \
  work_dir={{invocation_directory()}}/charts/{{APP}}/src; \
  cd $work_dir; \
  tag=$(cat $work_dir/VERSION); \
  sudo podman build -t "$REGISTRY_URL/{{APP}}:$tag" . ;\
  cd -

[group('docker')]
docker-run APP="${DOCKER_TRAIN_IMAGE}":
  @echo "Running {{APP}}..."; \
  work_dir={{invocation_directory()}}/charts/{{APP}}/src; \
  cd $work_dir; \
  tag=$(cat $work_dir/VERSION); \
  sudo podman run \
    --name {{APP}} \
    --shm-size=2g \
    --replace \
    -e MAX_EPOCHS=1 \
    -v $NFS_PATH/data:/app/data \
    -v $NFS_PATH/models:/app/models \
    -v $NFS_PATH/logs:/app/logs \
    $REGISTRY_URL/{{APP}}:$tag; \
  cd -

[group('docker')]
docker-push APP="${DOCKER_TRAIN_IMAGE}":
  @echo "Pushing {{APP}}..."; \
  work_dir={{invocation_directory()}}/charts/{{APP}}/src; \
  cd $work_dir; \
  tag=$(cat $work_dir/VERSION); \
  sudo podman push "$REGISTRY_URL/{{APP}}:$tag" ;\
  cd -

[group('helmfile')]
apply:
  @helmfile -e $ENV apply

[group('helmfile')]
apply-only LABEL='name=app':
  @helmfile -e $ENV apply -l {{LABEL}}

[group('helmfile')]
sync:
  @helmfile -e $ENV sync

[group('helmfile')]
sync-only LABEL='name=app':
  @helmfile -e $ENV sync -l {{LABEL}}

[group('helmfile')]
template:
  @helmfile -e $ENV template

[group('helmfile')]
template-only LABEL='name=app':
  @helmfile -e $ENV template -l {{LABEL}}

[group('helmfile')]
destroy:
  @helmfile -e $ENV destroy

[group('helmfile')]
destroy-only LABEL='name=app':
  @helmfile -e $ENV destroy -l {{LABEL}}

[group('helmfile')]
list:
  @helmfile -e $ENV list

[group('helmfile')]
status: # Retrieve status of releases in state file
  @helmfile -e $ENV status

env ENV:
  @echo ".env.{{ENV}} -> .env"
  @ln -sf .env.{{ENV}} .env
