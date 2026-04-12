#!/bin/bash
#######################################################################################################
### File Name : 1-4.install-helm.sh
### Description : Install helm on the Bastion Server
### Information : * helm reference site
###               - https://helm.sh/ko/docs/intro/install/
###
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
#############################################################################
## Function Name : install-eksctl()
## Description : 최신버전의 프로그램 다운로드후 설치하고 환경구성함.
## Information :
#############################################################################
install-helm()
{

    # １. 설치 script 파일다운로드
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4

    # ２. 파일임시 디렉토리에 풀기
    chmod 700 get_helm.sh

    # ３. 설치할 디렉토리 확인／생성하기
    mkdir -p $HOME/bin

    # ４. ＰＡＴＨ 환경 변수 설정
    if [ $(echo $PATH | grep "$HOME/bin:" | wc -l) -eq 0 ]; then  # $HOME/bin: PATH 추가
        export PATH=$HOME/bin:$PATH
        echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
    fi

    # ５. 환경 변수 설정
    # HELM_INSTALL_DIR: 바이너리가 저장될 위치
    # USE_SUDO: 사용자 디렉토리에 설치하므로 sudo 권한 사용 안 함
    export HELM_INSTALL_DIR=$HOME/bin
    export USE_SUDO=false

    # ６. helm 설치하기
    ./get_helm.sh

    # ７. ｈｅｌｍ 정상설치 여부 버전 체크 확인
    helm version

    # ８. clean up files
    rm -f ./get_helm.sh

}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================

# 1. helm 도구 설치 및 환경설정
install-helm
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
