#!/bin/bash
#######################################################################################################
### File Name : 2-2.render_eksctl_cluster_config.sh
### Description : eksctl의 config 파일을 template을 이용하여 변수 치환 작업
### Information : eksctl schema  정보
###               https://schema.eksctl.io/
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.04.07      ksk         First Version.
###    1.1     2026.04.10      ksk         add creat security groups
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
TEMPLATE_FILE="" # template 파일
OUTPUT_FILE=""   # 변수 치환된eksctl cluster config 파일
ACCOUNT_ID=""    # AWS 계정ID
EKS_SUBNETS=""       # EKS Cluster Subnets
EKS_CLUSTER_TAGS=""  # EKS Cluster Tags
CSHARESG_ID=""   # EKS Cluster Control Plane & Node Shared Node Security Group
CPSG_IDS=""       # EKS ControlPlaneSecurityID, EKS의 기본 SG외에 추가로 SG 할당하는 방법
CPSG_ID1=""       # EKS ControlPlaneSecurityID1

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
        echo -e "\n<< config 변환 작업시작>> : $(date +%Y%m%d-%H:%M:%S)"
    else
        if [ $jobStatus == "checking" ]; then
            printf "...........\n"
            printf "<< 작업중간체크>> : $(date +%Y%m%d-%H:%M:%S) \n"
        else
            printf "===========\n"
            printf "<< config 변환 작업완료>> : $(date +%Y%m%d-%H:%M:%S) \n"
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
## Function Name : getClusterSharedNodeSGID
## Description : Security Group Tag 이름을 이용하여 SG ID 조회하기.
##               EKS Cluster Control Plane & Shared Node Security Group
## Information :
#############################################################################
getClusterSharedNodeSGID()
{

    CSHARESG_TAG_NAME="sgrp-${PROJECT_NAME}-${ENVIRONMENT}-eks-cluster-${PROJECT_NAME}-${ENVIRONMENT}-sharednode" 

    CSHARESG_ID=$(aws ec2 describe-security-groups \
               --filters "Name=tag:Name,Values=${CSHARESG_TAG_NAME}" \
               --query "SecurityGroups[0].GroupId" \
               --output text)

    # 조회 결과가 없을 경우 예외 처리
    if [ "$CSHARESG_ID" == "None" ] || [ -z "$CSHARESG_ID" ]; then
        echo "${CSHARESG_TAG_NAME} SecurityGroup 을 생성합니다."
        CSHARESG_ID=$(aws ec2 create-security-group \
                        --group-name "$CSHARESG_TAG_NAME" \
                        --description "EKS Cluster Control Plane And Shared Node Security Group" \
                        --vpc-id "$VPC_ID" --query "GroupId" --output text)
        if [ "$CSHARESG_ID" == "None" ] || [ -z "$CSHARESG_ID" ]; then
            echo "${CSHARESG_TAG_NAME} SecurityGroup 생성중 오류가 발생했습니다."
            exit 1
        fi
        # sg 생성시 만들어 지는 default egress outbound rule 삭제
        aws ec2 revoke-security-group-egress --group-id "$CSHARESG_ID" --protocol all --port all --cidr 0.0.0.0/0 > /dev/null

        # Tags 추가
        SG_TAGS=(
            "Key=project,Value=$PROJECT_NAME"
            "Key=environment,Value=$ENVIRONMENT"
            "Key=Name,Value=$CSHARESG_TAG_NAME"
        )
        aws ec2 create-tags --resources "$CSHARESG_ID" --tags "${SG_TAGS[@]}"
    fi

    echo "$CSHARESG_ID"
}

#############################################################################
## Function Name : getControlPlaneSGID
## Description : Security Group Tag 이름을 이용하여 SG ID 조회하기.
##               EKS의API Server 접속관리를 위해 기본외 SG 추가
## Information :
#############################################################################
getControlPlaneSGID()
{

    CPSG_TAG_NAME1="sgrp-${PROJECT_NAME}-${ENVIRONMENT}-eks-cluster-${PROJECT_NAME}-${ENVIRONMENT}-apiserver-access"
    CPSG_ID1=$(aws ec2 describe-security-groups \
               --filters "Name=tag:Name,Values=${CPSG_TAG_NAME1}" \
               --query "SecurityGroups[0].GroupId" \
               --output text)

    # 조회 결과가 없을 경우 예외 처리
    if [ "$CPSG_ID1" == "None" ] || [ -z "$CPSG_ID1" ]; then
        echo "${CPSG_TAG_NAME1} SecurityGroup 을 생성합니다."
        CPSG_ID1=$(aws ec2 create-security-group \
                        --group-name "$CPSG_TAG_NAME1" \
                        --description "EKS Cluster Control Plane apiserver access Extra Security Group" \
                        --vpc-id "$VPC_ID" --query "GroupId" --output text)
        if [ "$CPSG_ID1" == "None" ] || [ -z "$CPSG_ID1" ]; then
            echo "${CPSG_TAG_NAME1} SecurityGroup 생성중 오류가 발생했습니다."
            exit 1
        fi
        # sg 생성시 만들어 지는 default egress outbound rule 삭제
        aws ec2 revoke-security-group-egress --group-id "$CPSG_ID1" --protocol all --port all --cidr 0.0.0.0/0 > /dev/null

        # Tags 추가
        SG_TAGS=(
            "Key=project,Value=$PROJECT_NAME"
            "Key=environment,Value=$ENVIRONMENT"
            "Key=Name,Value=$CPSG_TAG_NAME1"
        )
        aws ec2 create-tags --resources "$CPSG_ID1" --tags "${SG_TAGS[@]}"
    fi

IFS= read -r -d '' CPSG_BLOCK <<EOF
    - "$CPSG_ID1"
EOF

    # 2. sed에서 사용할 수 있도록 줄바꿈 처리 (\n 추가)
    # sed는 s/A/B/ 구문에서 B에 실제 줄바꿈이 있으면 에러가 나기 때문에 이 처리가 필수입니다.
    CPSG_IDS="${CPSG_BLOCK//$'\n'/\\n}"

    echo "$CPSG_IDS"
}

#############################################################################
## Function Name : applyRulesforSecurityGroup
## Description : Security Group의 ingress, egress 설정하기
## Information :
#############################################################################
applyRulesforSecurityGroup()
{
    local sg_id=$1
    local rule_type=$2
    shift 2
    rules=("$@")

    for rule in "${rules[@]}"; do
        # 쉼표(,)를 기준으로 필드 분리
        IFS=',' read -r proto from_port to_port source desc <<< "$rule"

        if [[ "$proto" == "-1" || "$proto" == "all" ]]; then
            echo "Applying $rule_type rule: [$desc] ($proto $from_port $to_port from $source)"
        else
            echo "Applying $rule_type rule: [$desc] ($proto $from_port-$to_port from $source)"
        fi

        # 대상이 SG ID(sg-*)인지 CIDR인지에 따라 JSON 구조 생성
        if [[ $source == sg-* ]]; then

            # Security Group ID 기반 규칙
            if [[ "$proto" == "-1" || "$proto" == "all" ]]; then
                PERM_JSON="[{\"IpProtocol\":\"-1\",\"UserIdGroupPairs\":[{\"GroupId\":\"$source\",\"Description\":\"$desc\"}]}]"
            else
                PERM_JSON="[{\"IpProtocol\":\"$proto\",\"FromPort\":$from_port,\"ToPort\":$to_port,\"UserIdGroupPairs\":[{\"GroupId\":\"$source\",\"Description\":\"$desc\"}]}]"
            fi
        else
            # CIDR 기반 규칙
            if [[ "$proto" == "-1" || "$proto" == "all" ]]; then
                # 프로토콜이 All인 경우 포트 필드를 제외한 JSON 생성
                PERM_JSON="[{\"IpProtocol\":\"-1\",\"IpRanges\":[{\"CidrIp\":\"$source\",\"Description\":\"$desc\"}]}]"
            else
                # 기존과 동일하게 포트 포함
                PERM_JSON="[{\"IpProtocol\":\"$proto\",\"FromPort\":$from_port,\"ToPort\":$to_port,\"IpRanges\":[{\"CidrIp\":\"$source\",\"Description\":\"$desc\"}]}]"
            fi
        fi

        # AWS CLI 실행 (JSON 구조를 --ip-permissions에 전달)
        if [[ "$rule_type" == "ingress" ]]; then
            echo "aws ec2 authorize-security-group-ingress --group-id \"$sg_id\" --ip-permissions \"$PERM_JSON\"  "
            aws ec2 authorize-security-group-ingress \
                --group-id "$sg_id" \
                --ip-permissions "$PERM_JSON" > /dev/null 2>&1 || echo "  (Existing rule or error)"
        else
            echo "aws ec2 authorize-security-group-ingress --group-id \"$sg_id\" --ip-permissions \"$PERM_JSON\"  "
            aws ec2 authorize-security-group-egress \
                --group-id "$sg_id" \
                --ip-permissions "$PERM_JSON" > /dev/null 2>&1 || echo "  (Existing rule or error)"
        fi
    done
}

#############################################################################
## Function Name : applyRulesforEKSClusterSG
## Description : EKS Cluster Main SG, SharedNode SG ingress/egress rule 설정
## Information :
#############################################################################
applyRulesforEKSClusterS()
{
    # 1. VPC의 모든 CIDR 가져오기
    VPC_CIDR_LIST=($(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query "Vpcs[0].CidrBlockAssociationSet[*].CidrBlock" --output text))

    EGRESS_RULES_TO_EFS=()
    INGRESS_RULES_FOR_APISERVER=()
    INGRESS_RULES_FOR_SSH_ACCESS=()
    for cidr in "${VPC_CIDR_LIST[@]}"; do
        # 2. EFS Outbound 규칙 배열 생성
        EGRESS_RULES_TO_EFS+=("tcp,2049,2049,$cidr,Allow node to VPC CIDR $cidr for access EFS")
        # 3. APISERVER Inbound 규칙 배열 생성
        INGRESS_RULES_FOR_APISERVER+=("tcp,443,443,$cidr,Allow node to VPC CIDR $cidr for access EKS APIServer")
        INGRESS_RULES_FOR_SSH_ACCESS+=("tcp,22,22,$cidr,Allow node to VPC CIDR $cidr for SSH access EKS Workernode ")
    done

    # rule variables format:  protocol, from_port, to_port, securit group id or cidr, description

    # Cluster Shared Node Security Group Ingress Rules
    CSHARESG_INGRESS_RULES=(
        "all,all,all,${CSHARESG_ID},Allow managed and unmanaged nodes to communicate with each other (all ports)"     # Cluster Controlplane self 호출inbound 통신 허용
        "tcp,443,443,${CPSG_ID1},Allow External SG to EKS Cluster API Server"    # Cluster Dataplane 호출inbound >통신 허용
        "${INGRESS_RULES_FOR_SSH_ACCESS[@]}"
    )
    # Cluster Shared Node Security Group Egress Rules
    CSHARSG_EGRESS_RULES=(
        "all,all,all,${CSHARESG_ID},Allow nodes to communicate with each other (all ports)"    # Cluster Dataplane 호출outbound 통신 허용
        "tcp,443,443,0.0.0.0/0,Allow nodes to https communicate with internet (https ports)"   # any ip, 443 port 호출outbound 통신 허용
        "${EGRESS_RULES_TO_EFS[@]}"
    )

    # Control Plane extra Security Group Ingress Rules
    CPSG_INGRESS_RULES=(
        "${INGRESS_RULES_FOR_APISERVER[@]}"
    )
    # Control Plane extra Security Group Egress Rules
    CPSG_EGRESS_RULES=(
        "tcp,443,443,${CSHARESG_ID},Allow External SG to EKS Cluster API Server"     # outbound 통신 허용to EKS Cluster API Server
    )

    echo "[PROCESS] Cluster SG 규칙 등록 중..."
    applyRulesforSecurityGroup "$CSHARESG_ID" "ingress" "${CSHARESG_INGRESS_RULES[@]}"
    applyRulesforSecurityGroup "$CSHARESG_ID" "egress"  "${CSHARSG_EGRESS_RULES[@]}"
    applyRulesforSecurityGroup "$CPSG_ID1"    "ingress" "${CPSG_INGRESS_RULES[@]}"
    applyRulesforSecurityGroup "$CPSG_ID1"    "egress"  "${CPSG_EGRESS_RULES[@]}"
}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================

# 변수 할당
PROJECT_NAME=$1  # 프로젝트 이름
ENVIRONMENT=$2   # 환경구분
TEMPLATE_FILE=$3  # template 파일
OUTPUT_FILE=$4  # 변수 치환된 파일

if [ -z "$PROJECT_NAME" -o -z "$ENVIRONMENT" -o -z "$TEMPLATE_FILE" -o -z "$OUTPUT_FILE" ]; then
    echo "Usage: ./2-2.render_eksctl_cluster_config.sh <project_name> <environment> <template_filename> <output_filename>"
    echo "Example: ./2-2.render_eksctl_cluster_config.sh hellow dev eksctl_cluster_conf.yaml hellow-dev-eksctl_cluster_conf.yaml "
    exit 1
fi

printf "\n#########################\n"
printf "\n-<< ./2-2.render_eksctl_cluster_config.sh  $PROJECT_NAME $ENVIRONMENT $TEMPLATE_FILE $OUTPUT_FILE >>--\n"
printf "\n#########################\n"
jobProcess "start"  # monitoring - start

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
echo "5. getClusterSharedNodeSGID"
getClusterSharedNodeSGID
jobProcess "checking"   # monitoring - checking

printf "\n-------------------------\n"
echo "6. getControlPlaneSGID"
getControlPlaneSGID
jobProcess "checking"   # monitoring - checking

printf "\n-------------------------\n"
echo "7. applyRulesforEKSClusterS"
applyRulesforEKSClusterS

sed -e "s/<account_id>/${ACCOUNT_ID}/g" \
    -e "s/<project_name>/${PROJECT_NAME}/g" \
    -e "s/<environment>/${ENVIRONMENT}/g" \
    -e "s/<vpc_id>/${VPC_ID}/g" \
    -e "s|<eks_subnets>|${EKS_SUBNETS}|g" \
    -e "s|<eks_cluster_tags>|${EKS_CLUSTER_TAGS}|g" \
    -e "s/<eks_main_sg>/${CMAINSG_ID}/g" \
    -e "s/<eks_shared_node_sg>/${CSHARESG_ID}/g" \
    -e "s/<controlplanesecuritygroup_ids>/${CPSG_IDS}/g" \
    $TEMPLATE_FILE > $OUTPUT_FILE

jobProcess "end"   # monitoring - end
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
