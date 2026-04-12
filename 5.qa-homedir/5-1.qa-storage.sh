#!/bin/bash
#######################################################################################################
### File Name : 5-1.qa-storage.sh
### Description : EKS Cluster QA - Storage
### Information :
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.04.12      ksk         First Version.
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

# 1. ebs driver 점검
SCRIPT_HOME_PATH=$1
echo -e "\n-------------------------\n"
echo "# 1. ebs driver 점검 프로그램 배포"
echo "${HOME}/bin/kubectl apply -f $SCRIPT_HOME_PATH/5-1.qa-storage.yaml"
${HOME}/bin/kubectl apply -f $SCRIPT_HOME_PATH/5-1.qa-storage.yaml
echo -e "\n-------------------------\n"
echo -e "\n----<< 배포 후 점검 잠시 대기 5초---\n"
sleep 5
echo "# Storage Class가 정상 배포 되었는지 확인"
${HOME}/bin/kubectl get sc qa-ebs-sc
echo "# PVC가 Bound 되었는지 확인"
${HOME}/bin/kubectl get pvc qa-ebs-claim
echo "# Pod이 Running 상태인지 확인"
${HOME}/bin/kubectl get pod qa-ebs-app -o wide
sleep 1
echo "# 데이터 정상 쓰기 확인"
${HOME}/bin/kubectl exec qa-ebs-app -- cat /data/out.txt
echo "# ebs driver 점검 프로그램 삭제 "
echo "${HOME}/bin/kubectl delete -f $SCRIPT_HOME_PATH/5-1.qa-storage.yaml"
${HOME}/bin/kubectl delete -f $SCRIPT_HOME_PATH/5-1.qa-storage.yaml

# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
