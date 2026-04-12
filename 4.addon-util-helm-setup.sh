#!/bin/bash
#######################################################################################################
### File Name : 4.addon-util-helm-setup.sh
### Description : Install utils on EKS with helm
### Information :
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.03.28      ksk         First Version.
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
PROJECT_NAME=""                      # Project Name  정보 - 필수 항목
ENVIRONMENT=""                       # Environment 정보 - 필수 항목 
ACCOUNT_ID=""                        # Account ID
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

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================

jobProcess "start"  # monitoring - start

# Helm utils 설치용 shell script Home directory 정보 설정
SCRIPT_HOME_PATH="${PWD}/4.helm-utils-homedir"

# 1. aws-loadbalancer-controller 도구 설치 및 환경설정
PROJECT_NAME="tb07297"                      # Project Name  정보
ENVIRONMENT="dev"                           # Environment 정보
getAccountID                                # Account ID 정보 - 필수 항목
REGION_CODE="ap-northeast-2"                # Region Code

echo -e "\n-------------------------\n"
echo "# 1. aws-loadbalancer-controller 도구 설치 및 환경설정"
echo "4-1.helm-install-aws-loadbalancer.sh $PROJECT_NAME $ENVIRONMENT $REGION_CODE $ACCOUNT_ID"
${SCRIPT_HOME_PATH}/4-1.helm-install-aws-loadbalancer.sh $PROJECT_NAME $ENVIRONMENT $REGION_CODE $ACCOUNT_ID
#jobProcess "checking"   # monitoring - checking

jobProcess "end"   # monitoring - end
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
