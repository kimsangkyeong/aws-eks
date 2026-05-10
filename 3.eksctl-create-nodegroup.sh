#!/bin/bash
#######################################################################################################
### File Name : 3.eksctl-create-nodegroup.sh
### Description : Install eks cluster nodegroup with eksctl
### Information :
###               1. eksctl upgrade nodegroup은 rolling node 처리 지원하며 반드시 --name 파라미터 필수
###                  - k8s/ami 버전 변경 시  -f 사용불가, 노드롤링 업데이트처리
###               2. eksctl update 는 단순 설정 반영하며, -f 지원
###                  - scaling, labels/tags/taints
###               3. nodegroup을 삭제 후 다시 생성하는 프로세스가 필요한 경우
###                  - Instance type 변경, UserData 변경(preBootScrapCommands 등) 시
###                  - eksctl delete nodegroup 처리 후  eksctl create nodegroup -f 처리하기
###                  - 참고: eksctl delete nodegroup -f xxx.yaml --approve --disable-eviction --wait
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.03.28      ksk         First Version.
###    1.1     2026.04.09      ksk         add create addon role
###    1.2     2026.05.10      ksk         modify upgrade nodegroup bug
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

# EKS Cluster Data Plane 서버 설치용 shell script Home directory 정보 설정
SCRIPT_HOME_PATH="${PWD}/3.eksctl-dataplane-homedir"

# template의 값을 치환하여 eksctl nodegroup config 파일 생성하기
${SCRIPT_HOME_PATH}/3-1.render_eksctl_nodegroup_config.sh  $PROJECT_NAME  $ENVIRONMENT ${SCRIPT_HOME_PATH}/$TEMPLATE_FILE ${SCRIPT_HOME_PATH}/$OUTPUT_FILE

if [ $# -ge 1 ]; then
    if [ $1 == "dry" ]; then
        echo "eksctl create nodegroup -f  ${SCRIPT_HOME_PATH}/${OUTPUT_FILE} --dry-run"
        eksctl create nodegroup -f  ${SCRIPT_HOME_PATH}/${OUTPUT_FILE}  --dry-run
    elif [ $1 == "up" ]; then
        echo "eksctl update nodegroup -f  ${SCRIPT_HOME_PATH}/${OUTPUT_FILE} --wait"
        eksctl update nodegroup -f  ${SCRIPT_HOME_PATH}/${OUTPUT_FILE} --wait
    fi
else
    eksctl create nodegroup -f  ${SCRIPT_HOME_PATH}/${OUTPUT_FILE}

    kubectl label nodes -l role=management node-role.kubernetes.io/management=1
    kubectl label nodes -l role=worker node-role.kubernetes.io/worker=1

    kubectl get nodes

    # eksctl이 자동 생성하는 security group의 outbound any ip, any port 삭제하기 - 보안강화
    echo "eksctl이 자동 생성하는 security group의 outbound any ip, any port 삭제하기 - 보안강화"
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
fi

# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
