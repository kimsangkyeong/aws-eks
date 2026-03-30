#!/bin/bash

ACCOUNT=$(aws sts get-caller-identity | jq -r ".Account")

echo "$ACCOUNT"
sed "s/xxxxxxxxxxxx/$ACCOUNT/g" cluster.yaml > cluster-act.yaml

eksctl create cluster -f cluster-act.yaml

eksctl get cluster -r ap-northeast-2
