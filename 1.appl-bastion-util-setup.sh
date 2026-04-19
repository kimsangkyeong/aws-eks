#!/bin/bash
#######################################################################################################
### File Name : 1.bastion-util-setup.sh
### Description : Install utils on the Bastion Server
### Information :
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.04.19      ksk         First Version.
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

# Common parameters
PARAM_OS="linux"
PARAM_ARCH="amd64"

# jq parameters
JQ_PARAM_OS=$PARAM_OS
JQ_PARAM_VER="1.8.1"
JQ_PARAM_ARCH=$PARAM_ARCH

# kubectl parameters
KUBECTL_PARAM_OS=$PARAM_OS
KUBECTL_PARAM_VER="1.35"
KUBECTL_PARAM_ARCH=$PARAM_ARCH

# awscliv2 parameters
AWSCLIV2_PARAM_OS=$PARAM_OS
AWSCLIV2_PARAM_ARCH=$PARAM_ARCH

# k9s parameters
K9S_PARAM_ARCH=$PARAM_ARCH

# =========<<<< Important Global Variable Registration Area Marking Comment (end) >>>>=================

# =========<<<< Function Registration Area Marking Comment (start) >>>>================================
#############################################################################
## Function Name :
## Description :
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

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
jobProcess "start"  # monitoring - start

# Bastion 서버 설치용 shell script Home directory 정보 설정
SCRIPT_HOME_PATH="${PWD}/1.bastion-utils-homedir"

# jq는하위 도구 설치에 사용되므로 First로 설치되어야 함.
# a. jq 도구 설치 및 환경설정
echo -e "\n-------------------------\n"
echo "# a. jq 도구 설치 및 환경설정"
echo "1-a.install-jq.sh $JQ_PARAM_OS $JQ_PARAM_VER $JQ_PARAM_ARCH"
${SCRIPT_HOME_PATH}/1-a.install-jq.sh $JQ_PARAM_OS $JQ_PARAM_VER $JQ_PARAM_ARCH
jobProcess "checking"   # monitoring - checking

# 1. kubectl 도구 설치 및 환경설정
echo -e "\n-------------------------\n"
echo "# 1. kubectl 도구 설치 및 환경설정"
echo "1-1.install-kubectl.sh $KUBECTL_PARAM_OS $KUBECTL_PARAM_VER $KUBECTL_PARAM_ARCH"
${SCRIPT_HOME_PATH}/1-1.install-kubectl.sh $KUBECTL_PARAM_OS $KUBECTL_PARAM_VER $KUBECTL_PARAM_ARCH
jobProcess "checking"   # monitoring - checking

# 3. awscliv2 도구 설치 및 환경설정
printf "\n-------------------------\n"
echo "# 2. awscliv2 도구 설치 및 환경설정"
echo "1-3.install-awscliv2.sh $AWSCLIV2_PARAM_OS $AWSCLIV2_PARAM_ARCH"
${SCRIPT_HOME_PATH}/1-3.install-awscliv2.sh $AWSCLIV2_PARAM_OS $AWSCLIV2_PARAM_ARCH
jobProcess "checking"   # monitoring - checking

# b. k9s 도구 설치 및 환경설정
echo -e "\n-------------------------\n"
echo "# b. k9s 도구 설치 및 환경설정"
echo "1-b.install-k9s.sh $K9S_PARAM_ARCH"
${SCRIPT_HOME_PATH}/1-b.install-k9s.sh $K9S_PARAM_ARCH
jobProcess "checking"   # monitoring - checking

# 4. helm 도구 설치 및 환경설정
printf "\n-------------------------\n"
echo "# 4. helm 도구 설치 및 환경설정"
echo "1-4.install-helm.sh"
${SCRIPT_HOME_PATH}/1-4.install-helm.sh

jobProcess "end"   # monitoring - end
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
