#!/usr/bin/env bash
set -e pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT="$DIR/../../../.."

export VM_MEMORY='2048'
export ASSETS_DIR="${ASSETS_DIR:-$GOPATH/src/github.com/coreos/matchbox/examples/assets}"
MATCHBOX_SHA=9a3347f1b5046c231f089374b63defb800b04079
SANITY_BIN=${SANITY_BIN:="$ROOT/bin/sanity"}

main() {
  TEMP=$(mktemp -d)
  echo "Creating $TEMP"

  echo "Getting matchbox"
  rm -rf matchbox
  git clone https://github.com/coreos/matchbox
  pushd matchbox
  git checkout $MATCHBOX_SHA
  chmod 600 tests/smoke/fake_rsa
  popd
  cp examples/fake-creds/{ca.crt,server.crt,server.key} matchbox/examples/etc/matchbox

  setup
  trap cleanup EXIT

  echo "Starting matchbox"
  pushd matchbox
  sudo -S -E ./scripts/devnet create
  popd

  echo "Waiting for matchbox to be ready"
  sleep 10

  echo "Starting terraform"
  (cd ${WORKSPACE} && make apply) &

  echo "Waiting for terraform to be ready"
  sleep 15

  echo "Starting QEMU/KVM nodes"
  pushd matchbox
  sudo -E ./scripts/libvirt create
  popd

  fg

  until kubelet "node1.example.com" \
    && kubelet "node2.example.com" \
    && kubelet "node3.example.com"
  do
    sleep 15
    echo "Waiting for Kubelets to start..."
  done

  ssh core@node1.example.com 'sudo systemctl start bootkube'

  until [[ "$(readyNodes)" == "3" ]]; do
    sleep 5
    echo "$(readyNodes) of 3 nodes are Ready..."
  done
  
  echo "Getting nodes..."
  k8s get nodes

  sleep 5
  until [[ "$(readyPods)" == "$(podCount)" && "$(readyPods)" -gt "0" ]]; do
    sleep 15
    echo "$(readyPods) pods are Running..."
    k8s get pods --all-namespaces || true
  done
  k8s get pods --all-namespaces || true

  until $(curl --silent --fail -k https://tectonic.example.com > /dev/null); do
    echo "Waiting for Tectonic Console..."
    k8s get pods --all-namespaces || true
    sleep 15
  done
  
  export NODE_COUNT=3
  export TEST_KUBECONFIG="${TEMP}/assets/auth/kubeconfig"
  echo "Running Go sanity tests"
  ${SANITY_BIN}

  echo "Tectonic bare-metal cluster came up!"
  echo
  
  echo "Cleaning up"
  cleanup
}

setup() {
  ${DIR}/get-kubectl.sh

  pushd matchbox
  sudo ./scripts/libvirt destroy || true
  sudo ./scripts/devnet destroy || true
  popd
  sudo rkt gc --grace-period=0
}

kubelet() {
  curl --silent --fail -m 1 http://$1:10255/healthz > /dev/null
}

ssh() {
  command ssh -i matchbox/tests/smoke/fake_rsa -o stricthostkeychecking=no "$@"
}

k8s() {
  ${ROOT}/bin/kubectl --kubeconfig=${TEMP}/assets/auth/kubeconfig "$@"
}

# ready nodes returns the number of Ready Kubernetes nodes
readyNodes() {
  k8s get nodes -o template --template='{{range .items}}{{range .status.conditions}}{{if eq .type "Ready"}}{{.}}{{end}}{{end}}{{end}}' | grep -o -E True | wc -l
}

# ready pods returns the number of Running pods
readyPods() {
  k8s get pods --all-namespaces -o template --template='{{range .items}}{{range .status.conditions}}{{if eq .type "Ready"}}{{.}}{{end}}{{end}}{{end}}' | grep -o -E True | wc -l
}

# podCount returns the number of pods
podCount() {
  k8s get pods --all-namespaces -o template --template='{{range .items}}{{range .status.conditions}}{{if eq .type "Ready"}}{{.}}{{end}}{{end}}{{end}}' | grep -o -E status | wc -l
}

cleanup() {
  echo "Killing Tectonic Installer"
  kill ${INSTALLER_PID} || true
  
  echo "Cleanup matchbox and VMs"
  pushd matchbox
  sudo ./scripts/libvirt destroy || true
  sudo ./scripts/devnet destroy || true
  popd
  sudo rkt gc --grace-period=0
  rm -rf ${TEMP}
}

main "$@"
