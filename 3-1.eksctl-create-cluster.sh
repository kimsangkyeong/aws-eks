#!/bin/bash

ACCOUNT=$(aws sts get-caller-identity | jq -r ".Account")
EKSCTL_CLUSTER_CONFIG="eksctl_cluster_conf"
EKSCTL_CLUSTER_CONFIG_FILE="${EKSCTL_CLUSTER_CONFIG}.yaml"
EKSCTL_CLUSTER_CONFIG_ACT_FILE="${EKSCTL_CLUSTER_CONFIG}-act.yaml"

echo "$ACCOUNT"
sed "s/xxxxxxxxxxxx/$ACCOUNT/g" ${EKSCTL_CLUSTER_CONFIG_FILE} > ${EKSCTL_CLUSTER_CONFIG_ACT_FILE}

if [ $# -ge 1 ]; then
    if [ $1 == "dry" ]; then
        echo "eksctl create cluster -f ${EKSCTL_CLUSTER_CONFIG_ACT_FILE} --dry-run"
        eksctl create cluster -f ${EKSCTL_CLUSTER_CONFIG_ACT_FILE}  --dry-run
    elif [ $1 == "up" ]; then
        echo "eksctl upgrade cluster -f ${EKSCTL_CLUSTER_CONFIG_ACT_FILE} --approve"
        eksctl upgrade cluster -f ${EKSCTL_CLUSTER_CONFIG_ACT_FILE} --approve
    fi
else
    eksctl create cluster -f ${EKSCTL_CLUSTER_CONFIG_ACT_FILE}

    #eksctl get cluster -r ap-northeast-2

    echo "kubectl label nodes -l eks.amazonaws.com/nodegroup=management node-role.kubernetes.io/management=1"
    echo "kubectl label nodes -l eks.amazonaws.com/nodegroup=worker node-role.kubernetes.io/worker=1"
fi
