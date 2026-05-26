alias dynamo="export KUBECONFIG=/path/to/kubeconfig && cd /path/to/k8s-manifest"

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

dwatch() {
  # Usage: dwatch <env>
  dynamo
  local env="${1}-dynamo"
  kwatch $env
}

dlogs() {
  # Usage: dlogs <env> <pod> [-f]
  dynamo
  local env="${1}-dynamo"
  local pod=$2
  local follow=$3

  if [ "$pod" = "adapter" ] || [ "$pod" = "autodeploy" ]; then
    pod="elemento-$pod-dynamo"
  else
    pod="meson-$pod"
  fi

  klogs $env $pod $follow
}

dsh() {
  # Usage: dsh <env> <pod>
  dynamo
  local env="${1}-dynamo"
  local pod=$2

  if [ "$pod" = "adapter" ] || [ "$pod" = "autodeploy" ]; then
    pod="elemento-$pod-dynamo"
  else
    pod="meson-$pod"
  fi

  ksh $env $pod
}