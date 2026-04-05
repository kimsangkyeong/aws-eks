#!/bin/bash
#######################################################################################################
### File Name : 4-1.helm-intall-aws-loadbalancer.sh
### Description : helm install aws-loadbalancer.sh
### Information : reference aws site
###         - https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/aws-load-balancer-controller.html
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.04.05      ksk         First Version.
#######################################################################################################
# =========<<<< Signal command processing login (start) >>>>===========================================
trap 'echo "$(date +${logdatefmt}) $0 signal(SIGINT) captured" | tee -a ${logfnm}; exit 1;' SIGINT
trap 'echo "$(date +${logdatefmt}) $0 signal(SIGQUIT) captured" | tee -a ${logfnm}; exit 1;' SIGQUIT
trap 'echo "$(date +${logdatefmt}) $0 signal(SIGTERM) captured" | tee -a ${logfnm}; exit 1;' SIGTERM
# =========<<<< Signal command processing login (end) >>>>=============================================

# =========<<<< Important Global Variable Registration Area Marking Comment (start) >>>>===============
# Log file name variable for storing script execution information:used in Signal common processing logic
logfnm="./${USER}.script-trap-log.$(date +%Y%m%d)"
logdatefmt="%Y%m%d-%H:%M:%S" # date/time format variable for logging info:used in Signal common logic
# =========<<<< Important Global Variable Registration Area Marking Comment (end) >>>>=================

# =========<<<< Function Registration Area Marking Comment (start) >>>>================================
#############################################################################
## Function Name : create-iam-role-for-albc
## Description : aws loadbalacer controller용 sa / policy eksctl로 생성하기.
## Information :
#############################################################################
create-iam-role-for-albc()
{
    echo "--- AWS Loadbalancer Controller SA / policy 생성 시작 ---"
    cluster_name=$1
    region_code=$2
    aws_account_id=$3
    echo " .. cluster: [${cluster_name}], region: [${region_code}], accountid: [${aws_account_id}]"

    # 1. 사용자 대신 AWS API를 직접 호출할 수 있는 AWS 로드 밸런서 컨트롤러의 IAM 정책을 다운로드합니다.
    curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json
    
    # 2. 다운로드한 정책을 사용하여 IAM 정책을 만들기
    aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

    # 3. 클러스터에 IAM SA 생성, policy 정책 Assign
    eksctl create iamserviceaccount \
    --cluster=${cluster_name} \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::${aws_account_id}:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region ${region_code} \
    --approve

}

#############################################################################
## Function Name : helm-install-aws-loadbalancer
## Description : Helm 으로 aws loadbalancer controller 설치하기.
## Information :
#############################################################################
helm-install-aws-loadbalancer()
{
    echo "--- Helm 으로 aws loadbalancer controller 설치 시작 ---"
    cluster_name=$1
    echo "  .. cluster: [${cluster_name}] "

    # 1. eks-charts 차트 Helm 리포지토리를 추가합니다. 
    helm repo add eks https://aws.github.io/eks-charts
    
    # 2. 최신 차트가 적용되도록 로컬 리포지토리를 업데이트합니다.
    helm repo update eks

    # 3. AWS 로드 밸런서 컨트롤러를 설치합니다.
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=${cluster_name} \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --version 1.14.0

    # 4. 배포된 차트는 보안 업데이트를 자동으로 수신하지 않음. 새 차트가 사용가능할 때 수용으로 업그레이드해야 한다.
    #    업그레이드를 위해 helm upgrade를 사용하는 경우 CRD를 수동으로 설치해야 한다. 
    wget https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml
    kubectl apply -f crds.yaml

    # 5. 컨트롤러가 설치되어 있는지? 확인
    kubectl get deployment -n kube-system aws-load-balancer-controller

}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
# 사용법 안내 함수
usage() {
    echo "Usage: $0 <cluster-name> <region-code> <AWS_ACCOUNT_ID>"
    echo "Example: $0 eks-example ap-northeast-2  XXXXXXXXXXXX"
    exit 1
}

# 1. 인자 개수 체크 ($# 는 인자의 개수를 의미)
if [ "$#" -ne 3 ]; then
    echo "Error: 인자의 개수가 맞지 않습니다."
    usage
fi

# 변수할당
Cluster_Name=$1
Region_Code=$2
AWS_Account_ID=$3

# 2. aws loadbalacer controller용 sa / policy eksctl로 생성하기.
create-iam-role-for-albc $Cluster_Name $Region_Code $AWS_Account_ID

# 3. Helm 으로 aws loadbalancer controller 설치하기
helm-install-aws-loadbalancer $Cluster_Name

# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
