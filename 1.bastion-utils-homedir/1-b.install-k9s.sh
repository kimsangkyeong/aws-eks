#!/bin/bash
#######################################################################################################
### File Name : 1-b.install-k9s.sh
### Description : Install k9s on the Bastion Server
### Information : * k9s reference site
###               - https://github.com/derailed/k9s/releases
###               - https://k9scli.io/topics/install/
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
## Function Name : install-k9s
## Description : 최신버전의 프로그램 다운로드후 설치하고 환경구성함.
## Information :
#############################################################################
install-k9s()
{
    echo "--- $(uname -s) / $2 설치 시작 ---"
    OS=$(uname -s)
    ARCH=${1:-amd64}   # 기본값  amd64

    # 최신버전 다운로드
    curl -sLO "https://github.com/derailed/k9s/releases/latest/download/k9s_${OS}_${ARCH}.tar.gz"

    # 파일 압축풀기
    tar -xzf k9s_${OS}_${ARCH}.tar.gz

    chmod +x k9s && mv k9s $HOME/bin

    # k9s 정상설치 여부 버전 체크 확인
    k9s version

    # clean up files
    rm k9s_${OS}_${ARCH}.tar.gz README.md LICENSE
}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
# 사용법 안내 함수
usage() {
    echo "Usage: $0 <arch>"
    echo "Example: $0 amd64"
    echo "  - arch: amd64, arm64, armv7"
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
    amd64|arm64|armv7) ;;
    *) echo "Error: 지원하지 않는 아키텍처입니다 ($ARCH)."; usage ;;
esac

# 3. k9s 도구 설치 및 환경설정
install-k9s $ARCH
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
