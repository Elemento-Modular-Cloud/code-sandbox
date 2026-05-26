alias k="kubectl"
alias a8s="export KUBECONFIG=/path/to/kubeconfig && cd /path/to/a8s"

kwatch() {
  # Usage: kwatch <env>
  local env=$1
  watch -n 2 "kubectl get pods -n $env | grep -E 'elemento|meson'"
}

klogs() {
  # Usage: klogs <env> <pod> [-f]
  local env=$1
  local pod=$2
  local follow=$3

  kubectl logs -n $env svc/$pod $follow
}

ksh() {
  # Usage: ksh <env> <pod>
  local env=$1
  local pod=$2

  kubectl exec -n $1 -it svc/$pod -- sh
}

awatch() {
  # Usage: awatch <env>
  a8s
  local env="meson-$1"
  kwatch $env
}

alogs() {
  # Usage: alogs <env> <pod> [-f]
  a8s
  local env="meson-$1"
  local pod="meson-$2"
  local follow=$3

  klogs $env $pod $follow
}

ash() {
  # Usage: ash <env> <pod>
  a8s
  local env="meson-$1"
  local pod="meson-$2"

  ksh $env $pod
}
