#!/bin/bash
#######################################################################################################
### File Name : 1-c.install-session-manager.sh
### Description : Install k9s on the Bastion Server
### Information : * aws session manager reference site
###    - https://docs.aws.amazon.com/ko_kr/systems-manager/latest/userguide/session-manager-working-with.html
###    - https://docs.aws.amazon.com/ko_kr/systems-manager/latest/userguide/install-plugin-linux.html
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.03.28      ksk         First Version.
###    1.1     2026.03.29      ksk         add clean file list
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
#############################################################################
## Function Name : install-session-manager
## Description : 최신버전의 프로그램 다운로드후 설치하고 환경구성함.
## Information :
#############################################################################
install-session-manager()
{
    echo "--- $1 / $2 설치 시작 ---"
    OS=${1:-al2023}
    ARCH=${2:-amd64}   # 기본값  amd64

    # 최신버전 RPM 패키지 다운로드 후 설치하기
    if [ $ARCH == "arm64" ]; then
        case $OS in
            "amazonlinux2" | "rhel7")
                sudo yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm
                ;;
            *)  
                sudo yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm
                ;;
        esac
    else
        case $OS in
            "amazonlinux2" | "rhel7")
                sudo yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm
                ;;
            *)  
                sudo dnf install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm
                ;;
        esac
    fi


    # session-manager 정상설치 여부 버전 체크 확인
    session-manager-plugin

}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
# 사용법 안내 함수
usage() {
    echo "Usage: $0 <os> <arch>"
    echo "Example: $0 AL2023 amd64"
    echo "  - os: AmazonLinux2, AL2023, RHEL7, RHEL8, RHEL9"
    echo "  - arch: amd64, arm64"
    echo " ===================="
    echo " 플러그인 제거 방법 : sudo yum erase session-manager-plugin -y "
    echo " 설치 후 Instance에 접속 방법 : aws ssm start-session --target <instance-id> "
    exit 1
}

# 1. 인자 개수 체크 ($# 는 인자의 개수를 의미)
if [ "$#" -ne 2 ]; then
    echo "Error: 인자의 개수가 맞지 않습니다."
    usage
fi

# 변수 할당
OS=$(echo "$1" | tr '[:upper:]' '[:lower:]')
ARCH=$(echo "$2" | tr '[:upper:]' '[:lower:]')

# 2. OS 값 유효성 체크
case "$OS" in
    amazonlinux2|al2023|rhel7|rhel8|rhel9) ;;
    *) echo "Error: 지원하지 않는 아키텍처입니다 ($ARCH)."; usage ;;
esac

# 3. 아키텍처 값 유효성 체크
case "$ARCH" in
    amd64|arm64) ;;
    *) echo "Error: 지원하지 않는 아키텍처입니다 ($ARCH)."; usage ;;
esac

# 4. session-manager 도구 설치 및 환경설정
install-session-manager $OS $ARCH
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
