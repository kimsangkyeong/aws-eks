#!/bin/bash
#######################################################################################################
### File Name : 1-2.install-eksctl.sh
### Description : Install eksctl on the Bastion Server
### Information : * aws reference site
###               - https://docs.aws.amazon.com/ko_kr/eks/latest/eksctl/installation.html
###               - https://schema.eksctl.io/
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
install-eksctl()
{
    echo "--- $(uname -s) / $2 설치 시작 ---"
    ARCH=${1:-amd64}   # 기본값  amd64
    PLATFORM=$(uname -s)_$ARCH

    # 최신버전 다운로드
    curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

    # (Optional) Verify checksum
    curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" \
           | grep $PLATFORM | sha256sum --check

    # 파일임시 디렉토리에 풀기
    mkdir -p $HOME/tmp
    tar -xzf eksctl_$PLATFORM.tar.gz -C $HOME/tmp && rm eksctl_$PLATFORM.tar.gz

    # 프로그램을 빌드 및 설치하고, 임시 디렉토리 삭제
    sudo install -m 0755 $HOME/tmp/eksctl $HOME/bin && rm $HOME/tmp/eksctl

    # eksctl completion 명령어실행 결과를 소싱하도록 환경 설정
    if [ $(grep "eksctl completion bash" $HOME/.bashrc | wc -l) -eq 0 ]; then
        echo 'source <(eksctl completion bash)' >> $HOME/.bashrc
        source $HOME/.bashrc
    fi

    # eksctl 정상설치 여부 버전 체크 확인
    eksctl version
}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
# 사용법 안내 함수
usage() {
    echo "Usage: $0 <arch>"
    echo "Example: $0 amd64"
    echo "  - arch: amd64, arm64, armv6, armv7"
    exit 1
}

# 1. 인자 개수 체크 ($# 는 인자의 개수를 의미)
if [ "$#" -ne 1 ]; then
    echo "Error: 인자의 개수가 맞지 않습니다."
    usage
fi

# 변수 할당
ARCH=$(echo "$1" | tr '[:upper:]' '[:lower:]')

# 2. 아키텍처 값 유효성 체크
case "$ARCH" in
    amd64|arm64|armv6|armv7) ;;
    *) echo "Error: 지원하지 않는 아키텍처입니다 ($ARCH)."; usage ;;
esac

# 3. eksctl 도구 설치 및 환경설정
install-eksctl $ARCH
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================