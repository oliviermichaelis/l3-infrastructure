CLUSTER_IDS=(1 2 3)
CLUSTER_REGIONS=("eu-central-1" "eu-west-3" "eu-south-1")
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";

for id in ${CLUSTER_IDS[@]}; do
		KUBECONFIG="--kubeconfig ${SCRIPT_DIR}/../.kube-context/cluster-${id}.yaml"
    kubectl kustomize ./../kubernetes/linkerd | kubectl ${KUBECONFIG} delete -f -
    linkerd ${KUBECONFIG} viz uninstall | kubectl ${KUBECONFIG} delete -f -
    linkerd ${KUBECONFIG} uninstall --force | kubectl ${KUBECONFIG} delete -f -
done

