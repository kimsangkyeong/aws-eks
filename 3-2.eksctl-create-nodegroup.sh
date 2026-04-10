#!/bin/bash
#######################################################################################################
### File Name : 3-2.eksctl-create-nodegroup.sh
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
./3-2-0.render_eksctl_nodegroup_config.sh  $PROJECT_NAME  $ENVIRONMENT $TEMPLATE_FILE $OUTPUT_FILE

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

    #eksctl get nodegroup -r ap-northeast-2

    echo "kubectl label nodes -l eks.amazonaws.com/nodegroup=management node-role.kubernetes.io/management=1"
    echo "kubectl label nodes -l eks.amazonaws.com/nodegroup=worker node-role.kubernetes.io/worker=1"
fi
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
