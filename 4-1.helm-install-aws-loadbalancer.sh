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

# Common parameters
PROJECT_NAME=""                      # Project Name  정보 - 필수 항목
ENVIRONMENT=""                       # Environment 정보 - 필수 항목 
REGION_CODE=""                       # Region code
AWS_ACCOUNT_ID=""                    # AWS Account ID
ROLE_NAME=""                         # AWS Loadbalaner Controller Role Name
# =========<<<< Important Global Variable Registration Area Marking Comment (end) >>>>=================

# =========<<<< Function Registration Area Marking Comment (start) >>>>================================
#############################################################################
## Function Name : createRole
## Description : Role 생성공통 처리하기
## Information :
#############################################################################
createRole()
{

    echo "--- 검사 시작: $ROLE_NAME ---"

    # 1. Role 존재 여부 확인 및 생성
    # --query 'Role.Arn' 은 성공 시 ARN을 반환하며, 실패 시 에러 코드를 냅니다.
    if aws iam get-role --role-name "$ROLE_NAME" > /dev/null 2>&1; then
        echo "[SKIP] IAM Role '$ROLE_NAME' 이 이미 존재합니다."
        echo " IAM Role Tag 정보 Update"
        # 이미 존재할 경우 태그 업데이트 (Idempotency 보장)
        aws iam tag-role \
            --role-name "$ROLE_NAME" \
            --tags "${ROLE_TAGS[@]}"
    else
        echo "[CREATE] IAM Role '$ROLE_NAME' 을 생성합니다."
        echo "TRUST_POLICY_DOC"
        echo "$TRUST_POLICY_DOC"
        aws iam create-role \
            --role-name "$ROLE_NAME" \
            --assume-role-policy-document "$TRUST_POLICY_DOC"
            --tags "${ROLE_TAGS[@]}"
    fi

    # 2. 정책 적용 (Policy는 존재하더라도 덮어쓰기(Overwrite)가 가능하므로 매번 실행하는 것이 안전합니다)
    echo "[UPDATE] Inline 및 Managed Policy 설정을 동기화합니다..."

    # Inline Policy 업데이트 - custom policy 존재한 경우
    if [ "$INLINE_POLICY_NAME" != "none" ]; then
        echo "[$INLINE_POLICY_NAME] Custom Inline Policy 설정을 동기화합니다..."
        echo "INLINE_POLICY_DOC"
        echo "$INLINE_POLICY_DOC"
        aws iam put-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-name "$INLINE_POLICY_NAME" \
            --policy-document "$INLINE_POLICY_DOC"
    fi

    # Managed Policies 연결
    echo "MANAGED_POLICIES - ${MANAGED_POLICIES[@]}"
    for policy_arn in "${MANAGED_POLICIES[@]}"; do
        echo "[$policy_arn] AWS Managed Policy 설정을 동기화합니다..."
        aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$policy_arn"
    done

}

#############################################################################
## Function Name : create-iam-role-for-albc
## Description : aws loadbalacer controller용 sa / policy eksctl로 생성하기.
## Information :
#############################################################################
create-iam-role-for-albc()
{
    echo "--- AWS Loadbalancer role 생성 시작 ---"

    # 1. 설정
    ROLE_NAME="role-${PROJECT_NAME}-${ENVIRONMENT}-eks-AWSLoadBalancerControllerIAMPolicy"

    # 2. Trust Relationship (Heredoc)
    TRUST_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
EOF
)
    # 3. 사용자 대신 AWS API를 직접 호출할 수 있는 AWS 로드 밸런서 컨트롤러의 최신 IAM 정책을 다운로드합니다.
     curl -Lo iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

    # 4. Inline Policy (Heredoc) - custom policy
    INLINE_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
    INLINE_POLICY_DOC=$(cat ./iam_policy.json) # Download한 aws-load-balancer-controller/main/docs/install/iam_policy.json

    # 5. Managed Policy 리스트
    MANAGED_POLICIES=(
    )

    # 6. Role Tags
    ROLE_TAGS=(
        "Key=Name,Value=${ROLE_NAME}"
        "Key=project,Value=${PROJECT_NAME}"
        "Key=environment,Value=${ENVIRONMENT}"
        "Key=creator,Value=infra"
    )

    # 7. create role
    createRole

}

#############################################################################
## Function Name : helm-install-aws-loadbalancer
## Description : Helm 으로 aws loadbalancer controller 설치하기.
## Information :
#############################################################################
helm-install-aws-loadbalancer()
{
    echo "--- Helm 으로 aws loadbalancer controller 설치 시작 ---"
    echo "  .. cluster: [eks-cluster-${PROJECT_NAME}-${ENVIRONMENT}] "

    # 1. eks-charts 차트 Helm 리포지토리를 추가합니다. 
    helm repo add eks https://aws.github.io/eks-charts
    
    # 2. 최신 차트가 적용되도록 로컬 리포지토리를 업데이트합니다.
    helm repo update eks

    # 3. AWS 로드 밸런서 컨트롤러를 설치합니다.
    CHART_VERSION="3.2.1"
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName="eks-cluster-${PROJECT_NAME}-${ENVIRONMENT}" \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --version $CHART_VERSION

    # 4. Pod Identity Association 등록하기 - aws-load-balancer-controller / role
    aws eks create-pod-identity-association \
        --cluster-name "eks-cluster-${PROJECT_NAME}-${ENVIRONMENT}" \
        --namespace kube-system \
        --service-account aws-load-balancer-controller \
        --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}

    # 5. 배포된 차트는 보안 업데이트를 자동으로 수신하지 않음. 새 차트가 사용가능할 때 수용으로 업그레이드해야 한다.
    #    업그레이드를 위해 helm upgrade를 사용하는 경우 CRD를 수동으로 설치해야 한다. 
    wget -L https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml
    kubectl apply -f crds.yaml
    mv crds.yaml  crds.yaml.$(date +%Y%m%d)

    # 6. 컨트롤러가 설치되어 있는지? 확인
    kubectl get deployment -n kube-system aws-load-balancer-controller

}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
# 사용법 안내 함수
usage() {
    echo "Usage: $0 <project_name> <environment> <region-code> <aws_account_id>"
    echo "Example: $0 eks-example dev ap-northeast-2  XXXXXXXXXXXX"
    exit 1
}

# 1. 인자 개수 체크 ($# 는 인자의 개수를 의미)
if [ "$#" -ne 4 ]; then
    echo "Error: 인자의 개수가 맞지 않습니다."
    usage
fi

# 변수할당
PROJECT_NAME=$1
ENVIRONMENT=$2
REGION_CODE=$3
AWS_ACCOUNT_ID=$4

# 2. aws loadbalacer controller용 sa / policy eksctl로 생성하기.
create-iam-role-for-albc 

# 3. Helm 으로 aws loadbalancer controller 설치하기
helm-install-aws-loadbalancer 
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
