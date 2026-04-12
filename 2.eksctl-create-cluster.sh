#!/bin/bash
#######################################################################################################
### File Name : 2.eksctl-create-cluster.sh
### Description : Install eks cluster with eksctl 
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
# Parameter setting
PROJECT_NAME="tb07297"                    # Project Name  정보 - 필수 항목
ENVIRONMENT="dev"                         # Environment 정보 - 필수 항목 
TEMPLATE_FILE="eksctl_cluster_conf.yaml"  # template 파일  - 필수 항목
OUTPUT_FILE="${PROJECT_NAME}-${ENVIRONMENT}-${TEMPLATE_FILE}"  # 변수 치환된 파일

# EKS Cluster Control Plane 서버 설치용 shell script Home directory 정보 설정
SCRIPT_HOME_PATH="${PWD}/2.eksctl-controlplane-homedir"

# eks cluster control plane, nodegroup 및 addon role 생성하기
${SCRIPT_HOME_PATH}/2-1.ekscluster-addon-role.sh  $PROJECT_NAME  $ENVIRONMENT

# template의 값을 치환하여 eksctl cluster config 파일 생성하기
${SCRIPT_HOME_PATH}/2-2.render_eksctl_cluster_config.sh  $PROJECT_NAME  $ENVIRONMENT ${SCRIPT_HOME_PATH}/$TEMPLATE_FILE ${SCRIPT_HOME_PATH}/$OUTPUT_FILE

if [ $# -ge 1 ]; then
    if [ $1 == "dry" ]; then
        echo "eksctl create cluster -f  ${SCRIPT_HOME_PATH}/${OUTPUT_FILE} --dry-run"
        eksctl create cluster -f  ${SCRIPT_HOME_PATH}/${OUTPUT_FILE}  --dry-run
    elif [ $1 == "up" ]; then
        echo "eksctl upgrade cluster -f  ${SCRIPT_HOME_PATH}/${OUTPUT_FILE} --approve"
        eksctl upgrade cluster -f  ${SCRIPT_HOME_PATH}/${OUTPUT_FILE} --approve
    fi
else
    eksctl create cluster -f  ${SCRIPT_HOME_PATH}/${OUTPUT_FILE}

    #eksctl get cluster -r ap-northeast-2

fi
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================

