#!/usr/bin/env bash

# asdf 삭제
rm -rf $HOME/.asdf || true

sudo apt update
sudo apt install -y curl git

# asdf 설치
git clone https://github.com/asdf-vm/asdf.git ~/.asdf
cd ~/.asdf && git switch -c v${ASDF_VERSION} && cd -

# asdf 초기화 스크립트 설정
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc

# asdf 플러그인 설치
asdf plugin add helm
asdf plugin add helm-diff
asdf plugin add helmfile
asdf plugin add yq
asdf plugin add k9s
asdf plugin add kubectx
asdf plugin-add kubetail https://github.com/janpieper/asdf-kubetail.git

# 패키지 설치
asdf install
