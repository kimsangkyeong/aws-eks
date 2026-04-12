#!/bin/bash
#######################################################################################################
### File Name : 1-3.install-awscliv2.sh
### Description : Install awscliv2 on the Bastion Server
### Information : * aws reference site
###               - https://docs.aws.amazon.com/ko_kr/cli/latest/userguide/getting-started-install.html
###
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
# =========<<<< Important Global Variable Registration Area Marking Comment (end) >>>>=================

# =========<<<< Function Registration Area Marking Comment (start) >>>>================================
#############################################################################
## Function Name : install-eksctl()
## Description : 최신버전의 프로그램 다운로드후 설치하고 환경구성함.
## Information :
#############################################################################
install-awscliv2()
{
    echo "--- $$ / $2 설치 시작 ---"
    OS=${1:-linux}     # 기본값 linux
    ARCH=${2:-amd64}   # 기본값 amd64

    # architecure해당 파일다운로드
    if [ $ARCH == "amd64" ]; then
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    else
        curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
    fi

    # 파일임시 디렉토리에 풀기
    unzip awscliv2.zip

    # /usr/local 디렉토리에설치하기
    #./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update

    # local user 환경으로 설치하기
    ./aws/install --bin-dir $HOME/bin --install-dir $HOME/.local/aws-cli --update

    # awscliv2 정상설치 여부 버전 체크 확인
    aws --version

    # 자동완성 기능 활성화하기
    if [ $(grep "aws_completer" $HOME/.bashrc | wc -l) -eq 0 ]; then  # aws_completer 추가
        echo "complete -C \"$HOME/bin/aws_completer\" aws" >> ~/.bashrc
    fi

    # clean up files
    rm -fr ./awscliv2.zip ./aws
}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
# 사용법 안내 함수
usage() {
    echo "Usage: $0 <os> <arch>"
    echo "Example: $0 linux amd64"
    echo "  - os: linux"
    echo "  - arch: amd64, arm64"
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
    linux) ;;
    *) echo "Error: 지원하지 않는 OS 입니다 ($OS)."; usage ;;
esac

# 3. 아키텍처 값 유효성 체크
case "$ARCH" in
    amd64|arm64) ;;
    *) echo "Error: 지원하지 않는 아키텍처입니다 ($ARCH)."; usage ;;
esac

# 3. awscliv2 도구 설치 및 환경설정
install-awscliv2 $OS $ARCH
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
