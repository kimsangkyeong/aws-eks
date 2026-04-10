#!/bin/bash
#######################################################################################################
### File Name : 3.eksctl-create-nodegroup.sh
### Description : Install eks cluster nodegroup with eksctl 
### Information :
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.03.28      ksk         First Version.
###    1.1     2026.04.09      ksk         add create addon role
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
# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
PROJECT_NAME="tb07297"                      # Project Name  정보 - 필수 항목
ENVIRONMENT="dev"                           # Environment 정보 - 필수 항목 
TEMPLATE_FILE="eksctl_nodegroup_conf.yaml"  # template 파일 - 필수 항목
OUTPUT_FILE="${PROJECT_NAME}-${ENVIRONMENT}-${TEMPLATE_FILE}"  # 변수 치환된 파일

# template의 값을 치환하여 eksctl nodegroup config 파일 생성하기
./3-1.render_eksctl_nodegroup_config.sh  $PROJECT_NAME  $ENVIRONMENT $TEMPLATE_FILE $OUTPUT_FILE

if [ $# -ge 1 ]; then
    if [ $1 == "dry" ]; then
        echo "eksctl create nodegroup -f ${OUTPUT_FILE} --dry-run"
        eksctl create nodegroup -f ${OUTPUT_FILE}  --dry-run
    elif [ $1 == "up" ]; then
        echo "eksctl upgrade nodegroup -f ${OUTPUT_FILE} --approve"
        eksctl upgrade nodegroup -f ${OUTPUT_FILE} --approve
    fi
else
    eksctl create nodegroup -f ${OUTPUT_FILE}

    kubectl label nodes -l role=management node-role.kubernetes.io/management=1
    kubectl label nodes -l role=worker node-role.kubernetes.io/worker=1

    kubectl get nodes
fi

# eksctl이 자동 생성하는 security group의 outbound any ip, any port 삭제하기 - 보안강화
EKSCTL_GEN_SGS=(
         $(aws ec2 describe-security-groups    \
            --filters "Name=group-name,Values=eks*eks-cluster-${PROJECT_NAME}-${ENVIRONMENT}-*" \
                      "Name=vpc-id,Values=$(aws ec2 describe-vpcs \
                                             --filters "Name=tag:Name,Values=vpc-${PROJECT_NAME}-${ENVIRONMENT}" \
                                             --query "Vpcs[0].VpcId" \
                                             --output text)" \
             --query "SecurityGroups[*].GroupId" \
             --output text)
)
for eksctl_gen_sg in "${EKSCTL_GEN_SGS[@]}"; do
    echo " eksctl에서 자동 생성한 Security Group [$eksctl_gen_sg] egress any ip, all port 삭제 하기"
    aws ec2 revoke-security-group-egress \
     --group-id "$eksctl_gen_sg" --protocol all --port all --cidr 0.0.0.0/0 > /dev/null
done

# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
