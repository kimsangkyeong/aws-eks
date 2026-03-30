#!/bin/bash

ACCOUNT=$(aws sts get-caller-identity | jq -r ".Account")

echo "$ACCOUNT"
sed "s/xxxxxxxxxxxx/$ACCOUNT/g" cluster.yaml > cluster-act.yaml

# eksctl create cluster -f cluster-act.yaml  --dry-run

eksctl create cluster -f cluster-act.yaml

eksctl get cluster -r ap-northeast-2

# kubectl label nodes -l eks.amazonaws.com/nodegroup=management node-role.kubernetes.io/management=1
# kubectl label nodes -l eks.amazonaws.com/nodegroup=worker node-role.kubernetes.io/worker=1
