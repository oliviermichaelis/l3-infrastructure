#!/bin/sh

# This script provisions linkerd with the linkerd-viz and multi-cluster extensions
# on AWS EKS clusters provisioned by the opentofu stack in this repository

set -e
set -x

# variables
PODINFO_HELM_REPO=/home/olivier/Documents/oliviermichaelis/podinfo/charts/podinfo
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
#CLUSTER_IDS=(1 2 3)
CLUSTER_IDS=(1 2)
#CLUSTER_REGIONS=("eu-central-1" "eu-west-3" "eu-south-1")
CLUSTER_REGIONS=("eu-central-1" "eu-west-3")

for id in ${CLUSTER_IDS[@]}
do
		KUBECONFIG="--kubeconfig ${SCRIPT_DIR}/../.kube-context/cluster-${id}.yaml"
    aws eks update-kubeconfig --region ${CLUSTER_REGIONS[id-1]} --name cluster-${id} --alias cluster-${id} ${KUBECONFIG}
    linkerd ${KUBECONFIG} install \
        --identity-trust-anchors-file ${SCRIPT_DIR}/certificates/.certificates/ca.crt \
        --identity-issuer-certificate-file ${SCRIPT_DIR}/certificates/.certificates/issuer.crt \
        --identity-issuer-key-file ${SCRIPT_DIR}/certificates/.certificates/issuer.key \
        --proxy-cpu-request 25m \
        --set proxyInit.runAsRoot=true \
        | \
        kubectl ${KUBECONFIG} apply -f -
    linkerd ${KUBECONFIG} viz install | kubectl ${KUBECONFIG} apply -f -
    kubectl kustomize ${SCRIPT_DIR}/../kubernetes/linkerd | kubectl ${KUBECONFIG} apply -f -
done

for id in ${CLUSTER_IDS[@]}
do
    for remoteId in ${CLUSTER_IDS[@]}
    do
        if [[ $id == $remoteId ]]; then
            echo "skipping"
            continue
        fi
        API_SERVER=$(aws eks --region ${CLUSTER_REGIONS[remoteId-1]} describe-cluster --name cluster-$remoteId | jq -r .cluster.endpoint)

				KUBECONFIG="--kubeconfig ${SCRIPT_DIR}/../.kube-context/cluster-${remoteId}.yaml"
        linkerd ${KUBECONFIG} multicluster link --cluster-name=cluster-${remoteId} --api-server-address=$API_SERVER | kubectl --kubeconfig ${SCRIPT_DIR}/../.kube-context/cluster-${id}.yaml apply -f -
    done
done

# iterate over cluster IDs
for id in ${CLUSTER_IDS[@]}
do
		KUBECONFIG="--kubeconfig ${SCRIPT_DIR}/../.kube-context/cluster-${id}.yaml"
    # install metrics-server
    kubectl ${KUBECONFIG} apply -f ${SCRIPT_DIR}/../kubernetes/namespace.yaml
    helm ${KUBECONFIG} upgrade --install metrics-server metrics-server/metrics-server -n kube-system --set=args={--kubelet-insecure-tls}

    # install podinfo
    helm \
        ${KUBECONFIG} \
        upgrade --install \
        podinfo ${PODINFO_HELM_REPO} \
        --values ${SCRIPT_DIR}/../kubernetes/podinfo.yaml \
        --set ui.message=cluster-${id} \
        --set queueName=cluster-${id} \
        --namespace podinfo

    # export the deployed service to the other clusters
    kubectl ${KUBECONFIG} --namespace podinfo label svc podinfo mirror.linkerd.io/exported=false --overwrite=true
done

# Install Prometheus
KUBECONFIG_CLUSTER_1="--kubeconfig ${SCRIPT_DIR}/../.kube-context/cluster-1.yaml"
kubectl ${KUBECONFIG_CLUSTER_1} kustomize cluster-1 | kubectl ${KUBECONFIG_CLUSTER_1} apply -f -
helm \
		${KUBECONFIG_CLUSTER_1} \
    upgrade --install \
    kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --values ${SCRIPT_DIR}/../kubernetes/cluster-1/kube-prometheus-stack.yaml \
    --namespace prometheus
helm \
		${KUBECONFIG_CLUSTER_1} \
    upgrade --install \
    pushgateway prometheus-community/prometheus-pushgateway\
    --values ${SCRIPT_DIR}/../kubernetes/cluster-1/prometheus-pushgateway.yaml \
    --namespace prometheus

helm ${KUBECONFIG_CLUSTER_1} upgrade -i flagger-loadtester-1 --namespace podinfo flagger/loadtester --values ${SCRIPT_DIR}/../kubernetes/cluster-1/loadtester.yaml --set nameOverride=flagger-loadtester-1
helm ${KUBECONFIG_CLUSTER_1} upgrade -i flagger-loadtester-2 --namespace podinfo flagger/loadtester --values ${SCRIPT_DIR}/../kubernetes/cluster-1/loadtester.yaml --set nameOverride=flagger-loadtester-2
helm ${KUBECONFIG_CLUSTER_1} upgrade -i flagger-loadtester-3 --namespace podinfo flagger/loadtester --values ${SCRIPT_DIR}/../kubernetes/cluster-1/loadtester.yaml --set nameOverride=flagger-loadtester-3
helm ${KUBECONFIG_CLUSTER_1} upgrade -i flagger-loadtester-4 --namespace podinfo flagger/loadtester --values ${SCRIPT_DIR}/../kubernetes/cluster-1/loadtester.yaml --set nameOverride=flagger-loadtester-4
helm ${KUBECONFIG_CLUSTER_1} upgrade -i flagger-loadtester-5 --namespace podinfo flagger/loadtester --values ${SCRIPT_DIR}/../kubernetes/cluster-1/loadtester.yaml --set nameOverride=flagger-loadtester-5

# linkerd smi install --skip-checks | kubectl --context cluster-1 apply -f -
kubectl ${KUBECONFIG_CLUSTER_1} apply -f ${SCRIPT_DIR}/serverauthorization.yaml
kubectl ${KUBECONFIG_CLUSTER_1} apply -f ${SCRIPT_DIR}/trafficsplit.yaml

#kubectl ${KUBECONFIG_CLUSTER_1} apply -f ${SCRIPT_DIR}/../pilot/manifests


for region in ${CLUSTER_REGIONS[@]}; do
    NLBS=$(aws elbv2 --region ${region} describe-load-balancers --output json | jq -r '.LoadBalancers[].LoadBalancerArn')
    for lb in $NLBS; do
        while [[ "$(aws elbv2 --region ${region} describe-load-balancers --output json --load-balancer-arns ${lb} | jq -r '.LoadBalancers[].State.Code')" != "active" ]]
        do
            echo "sleeping..."
            sleep 1
        done
    done
done

for id in ${CLUSTER_IDS[@]}
do
    kubectl --kubeconfig ${SCRIPT_DIR}/../.kube-context/cluster-${id}.yaml --namespace podinfo label svc podinfo mirror.linkerd.io/exported=true --overwrite=true
done
# kubectl ${KUBECONFIG_CLUSTER_1} rollout restart deployment -n podinfo pilot

# kubectx cluster-1
# make -f /home/olivier/Documents/oliviermichaelis/linkerd-least-latency/Makefile install
# make -f /home/olivier/Documents/oliviermichaelis/linkerd-least-latency/Makefile deploy

