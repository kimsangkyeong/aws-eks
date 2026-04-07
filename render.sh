#!/bin/bash
#######################################################################################################
### File Name : render0.sh
### Description : eksctl의 config 파일을 template을 이용하여 변수 치환 작업
### Information : eksctl schema  정보
###               https://schema.eksctl.io/
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.04.07      ksk         First Version.
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

# Job Process parameters
START_TIME=0    # job 시작 시간
END_TIME=0      # job 종료 시간
ELAPSED_TIME=0  # job 수행 시간

# replace text variables
PROJECT_NAME=""  # 프로젝트 이름
ENVIRONMENT=""   # 환경구분
ACCOUNT_ID=""    # AWS 계정ID
EKS_SUBNETS=""       # EKS Cluster Subnets
EKS_CLUSTER_TAGS=""  # EKS Cluster Tags
CPSG_IDS=""       # EKS ControlPlaneSecurityID, EKS의 기본 SG외에 추가로 SG 할당하는 방법

# =========<<<< Important Global Variable Registration Area Marking Comment (end) >>>>=================

# =========<<<< Function Registration Area Marking Comment (start) >>>>================================
#############################################################################
## Function Name : jobProcess
## Description : Main Job 프로세스 실행 시 모니터링 정보 출력
## Information :
#############################################################################
jobProcess()
{
    jobStatus=${1:-start}  # 기본값 start

    if [ $jobStatus == "start" ]; then
        START_TIME=$(date +%s)
        echo -e "\n<< 설치 작업시작>> : $(date +%Y%m%d-%H:%M:%S)"
    else
        if [ $jobStatus == "checking" ]; then
            printf "...........\n"
            printf "<< 작업중간체크>> : $(date +%Y%m%d-%H:%M:%S) \n"
        else
            printf "===========\n"
            printf "<< 설치작업완료>> : $(date +%Y%m%d-%H:%M:%S) \n"
        fi
        END_TIME=$(date +%s)
        ELAPSED_TIME=$(( END_TIME - START_TIME ))
        if [ $ELAPSED_TIME -ge 3600 ]; then
            HOUR=$(( ELAPSED_TIME / 3600 ))
            MIN=$(( (ELAPSED_TIME % 3600) / 60 ))
            SEC=$(( ELAPSED_TIME % 60 ))
            display_msg="누적 실행 시간: ${HOUR} 시 ${MIN} 분 ${SEC} 초"
        elif [ $ELAPSED_TIME -ge 60 ]; then
            MIN=$(( ELAPSED_TIME / 60 ))
            SEC=$(( ELAPSED_TIME % 60 ))
            display_msg="누적 실행 시간:  ${MIN} 분 ${SEC} 초"
        else
            SEC=$ELAPSED_TIME
            display_msg="누적 실행 시간:  ${SEC} 초"
        fi
        if [ $jobStatus == "checking" ]; then
            echo "중간 $display_msg"
            printf "...........\n"
        else
            echo "총 $display_msg"
            printf "===========\n\n"
        fi
    fi
}

#############################################################################
## Function Name : AccountID
## Description : AWS 임시 자격증명을 이용하여 AccountID 조회하기
## Information :
#############################################################################
getAccountID()
{
    ACCOUNT_ID=$(aws sts get-caller-identity | jq -r ".Account")

    # 조회 결과가 없을 경우 예외 처리
    if [ "$ACCOUNT_ID" == "None" ] || [ -z "$ACCOUNT_ID" ]; then
        echo "❌ Error: aws sts get-caller-identity | jq -r \".Account\" 조회 오류."
        exit 1
    fi

    echo "$ACCOUNT_ID"
}

#############################################################################
## Function Name : getVpcID
## Description : VPC Tag 이름을 이용하여 VPC ID 조회하기
## Information :
#############################################################################
getVpcID()
{

    VPC_TAG_NAME="vpc-${PROJECT_NAME}-${ENVIRONMENT}"
    VPC_TAG_NAME="tb07297-vpc"  # test
    VPC_ID=$(aws ec2 describe-vpcs \
              --filters "Name=tag:Name,Values=${VPC_TAG_NAME}" \
              --query "Vpcs[0].VpcId" \
              --output text)

    # 조회 결과가 없을 경우 예외 처리
    if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
        echo "❌ Error: ${VPC_TAG_NAME}의 VPC ID를 찾을 수 없습니다."
        exit 1
    fi

    echo "$VPC_ID"
}

#############################################################################
## Function Name : getEKSSubnets
## Description : EKS Cluster 배포할 Subnets
## Information :
#############################################################################
getEKSSubnets()
{
    PUBLIC_2A_TAG_NAME="tb07297-subnet-public1-ap-northeast-2a"
    PUBLIC_2C_TAG_NAME="tb07297-subnet-public2-ap-northeast-2b"
    PRIVATE_2A_TAG_NAME="tb07297-subnet-private2-eks-2a"
    PRIVATE_2C_TAG_NAME="tb07297-subnet-private2-eks-2b"
    PUBLIC_2A=$(aws ec2 describe-subnets \
             --filters "Name=tag:Name,Values=${PUBLIC_2A_TAG_NAME}" \
             --query "Subnets[0].SubnetId" \
             --output text)
    PUBLIC_2C=$(aws ec2 describe-subnets \
             --filters "Name=tag:Name,Values=${PUBLIC_2C_TAG_NAME}" \
             --query "Subnets[0].SubnetId" \
             --output text)
    PRIVATE_2A=$(aws ec2 describe-subnets \
             --filters "Name=tag:Name,Values=${PRIVATE_2A_TAG_NAME}" \
             --query "Subnets[0].SubnetId" \
             --output text)
    PRIVATE_2C=$(aws ec2 describe-subnets \
             --filters "Name=tag:Name,Values=${PRIVATE_2C_TAG_NAME}" \
             --query "Subnets[0].SubnetId" \
             --output text)

    if [ "$PUBLIC_2A" == "None" ] || [ -z "$PUBLIC_2A" ]; then
        echo "❌ Error: ${PUBLIC_2A_TAG_NAME}의 Subnet ID를 찾을 수 없습니다."
        exit 1
    elif [ "$PUBLIC_2C" == "None" ] || [ -z "$PUBLIC_2C" ]; then
        echo "❌ Error: ${PUBLIC_2C_TAG_NAME}의 Subnet ID를 찾을 수 없습니다."
        exit 1
    elif [ "$PRIVATE_2A" == "None" ] || [ -z "$PRIVATE_2A" ]; then
        echo "❌ Error: ${PRIVATE_2A_TAG_NAME}의 Subnet ID를 찾을 수 없습니다."
        exit 1
    elif [ "$PRIVATE_2C" == "None" ] || [ -z "$PRIVATE_2C" ]; then
        echo "❌ Error: ${PRIVATE_2C_TAG_NAME}의 Subnet ID를 찾을 수 없습니다."
        exit 1
    fi

    # 1. 치환할 내용을 변수에 저장 (들여쓰기 포함) Template의 띄워쓰기 연계.
    #    IFS= 을 read 앞에 추가하여 public 앞의 공백도 유지하기
IFS= read -r -d '' SUBNETS_BLOCK <<EOF
    public:
      ap-northeast-2a:
        id: $PUBLIC_2A
      ap-northeast-2b:
        id: $PUBLIC_2C
    private:
      ap-northeast-2a:
        id: $PRIVATE_2A
      ap-northeast-2b:
        id: $PRIVATE_2C
EOF

    # 2. sed에서 사용할 수 있도록 줄바꿈 처리 (\n 추가)
    # sed는 s/A/B/ 구문에서 B에 실제 줄바꿈이 있으면 에러가 나기 때문에 이 처리가 필수입니다.
    EKS_SUBNETS="${SUBNETS_BLOCK//$'\n'/\\n}"

    echo "$EKS_SUBNETS"

}
#############################################################################
## Function Name : getEKSClusterTags
## Description : EKS Cluster이 Tags
## Information :
#############################################################################
getEKSClusterTags()
{
    # 1. 치환할 내용을 변수에 저장 (들여쓰기 포함) Template의 띄워쓰기 연계.
    #    IFS= 을 read 앞에 추가하여 공백도 유지하기
IFS= read -r -d '' TAGS_BLOCK <<EOF
    creator: tb07297
    tools: eksctl
EOF

    # 2. sed에서 사용할 수 있도록 줄바꿈 처리 (\n 추가)
    # sed는 s/A/B/ 구문에서 B에 실제 줄바꿈이 있으면 에러가 나기 때문에 이 처리가 필수입니다.
    EKS_CLUSTER_TAGS="${TAGS_BLOCK//$'\n'/\\n}"

    echo "$EKS_CLUSTER_TAGS"

}

#############################################################################
## Function Name : getControlPlaneSGID
## Description : Security Group Tag 이름을 이용하여 SG ID 조회하기.
##               EKS의API Server 접속관리를 위해 기본외 SG 추가
## Information :
#############################################################################
getControlPlaneSGID()
{

    CPSG_TAG_NAME1="tb07297-eks-app-sg"  # test
    CPSG_ID1=$(aws ec2 describe-security-groups \
               --filters "Name=tag:Name,Values=${CPSG_TAG_NAME1}" \
               --query "SecurityGroups[0].GroupId" \
               --output text)

    # 조회 결과가 없을 경우 예외 처리
    if [ "$CPSG_ID1" == "None" ] || [ -z "$CPSG_ID1" ]; then
        echo "❌ Error: ${CPSG_TAG_NAME1}의 SecurityGroup ID를 찾을 수 없습니다."
        exit 1
    fi

IFS= read -r -d '' CPSG_BLOCK <<EOF
    - "$CPSG_ID1"
EOF
    # 2. sed에서 사용할 수 있도록 줄바꿈 처리 (\n 추가)
    # sed는 s/A/B/ 구문에서 B에 실제 줄바꿈이 있으면 에러가 나기 때문에 이 처리가 필수입니다.
    CPSG_IDS="${CPSG_BLOCK//$'\n'/\\n}"

    echo "$CPSG_IDS"
}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
jobProcess "start"  # monitoring - start

# 변수 할당
PROJECT_NAME=$1  # 프로젝트 이름
ENVIRONMENT=$2   # 환경구분

if [ -z "$PROJECT_NAME" -o -z "$ENVIRONMENT" ]; then
    echo "Usage: ./render0.sh <project_name> <environment>"
    echo "Example: ./render0.sh tb07297 dev"
    exit 1
fi

printf "\n-------------------------\n"
echo "1. getAccountID"
getAccountID
jobProcess "checking"   # monitoring - checking

printf "\n-------------------------\n"
echo "2. getVpcID"
getVpcID
jobProcess "checking"   # monitoring - checking

printf "\n-------------------------\n"
echo "3. getEKSSubnets"
getEKSSubnets
jobProcess "checking"   # monitoring - checking

printf "\n-------------------------\n"
echo "4. getEKSClusterTags"
getEKSClusterTags
jobProcess "checking"   # monitoring - checking

printf "\n-------------------------\n"
echo "5. getControlPlaneSGID"
getControlPlaneSGID

TEMPLATE_FILE="eksctl_cluster_conf.yaml"  # template 파일
OUTPUT_FILE="${PROJECT_NAME}-${ENVIRONMENT}-${TEMPLATE_FILE}"  # 변수 치환된 파일

sed -e "s/<account_id>/${ACCOUNT_ID}/g" \
    -e "s/<project_name>/${PROJECT_NAME}/g" \
    -e "s/<environment>/${ENVIRONMENT}/g" \
    -e "s/<vpc_id>/${VPC_ID}/g" \
    -e "s|<eks_subnets>|${EKS_SUBNETS}|g" \
    -e "s|<eks_cluster_tags>|${EKS_CLUSTER_TAGS}|g" \
    -e "s/<controlplanesecuritygroup_ids>/${CPSG_IDS}/g" \
    $TEMPLATE_FILE > $OUTPUT_FILE

jobProcess "end"   # monitoring - end
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
