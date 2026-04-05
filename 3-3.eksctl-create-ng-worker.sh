#!/bin/bash

ACCOUNT=$(aws sts get-caller-identity | jq -r ".Account")
EKSCTL_NODEGROUP_WORKER_CONFIG="eksctl_ng_worker_conf"
EKSCTL_NODEGROUP_WORKER_CONFIG_FILE="${EKSCTL_NODEGROUP_WORKER_CONFIG}.yaml"
EKSCTL_NODEGROUP_WORKER_CONFIG_ACT_FILE="${EKSCTL_NODEGROUP_WORKER_CONFIG}-act.yaml"

echo "$ACCOUNT"
sed "s/xxxxxxxxxxxx/$ACCOUNT/g" ${EKSCTL_NODEGROUP_WORKER_CONFIG_FILE} > ${EKSCTL_NODEGROUP_WORKER_CONFIG_ACT_FILE}

if [ $# -ge 1 ]; then
    if [ $1 == "dry" ]; then
        echo "eksctl create nodegroup -f ${EKSCTL_NODEGROUP_WORKER_CONFIG_ACT_FILE} --dry-run"
        eksctl create nodegroup -f ${EKSCTL_NODEGROUP_WORKER_CONFIG_ACT_FILE}  --dry-run
    elif [ $1 == "up" ]; then
        echo "eksctl upgrade nodegroup -f ${EKSCTL_NODEGROUP_WORKER_CONFIG_ACT_FILE} --approve"
        eksctl upgrade nodegroup -f ${EKSCTL_NODEGROUP_WORKER_CONFIG_ACT_FILE} --approve
    fi
else
    eksctl create nodegroup -f ${EKSCTL_NODEGROUP_WORKER_CONFIG_ACT_FILE}

    #eksctl get nodegroup -r ap-northeast-2

    echo "kubectl label nodes -l eks.amazonaws.com/nodegroup=management node-role.kubernetes.io/management=1"
    echo "kubectl label nodes -l eks.amazonaws.com/nodegroup=worker node-role.kubernetes.io/worker=1"
fi
