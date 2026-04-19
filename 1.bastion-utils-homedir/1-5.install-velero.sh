#!/bin/bash
#######################################################################################################
### File Name : 1-5.install-velero.sh
### Description : Install velero on the Bastion Server
### Information : * velero reference site
###               - https://github.com/velero-io/velero/releases/
###               You must check every time before installation whether the new version has changed.
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
# =========<<<< Important Global Variable Registration Area Marking Comment (end) >>>>=================

# =========<<<< Function Registration Area Marking Comment (start) >>>>================================
#############################################################################
## Function Name : getList()
## Description : velero 제공하는site의 정보를 읽어서 설치 가능 버전 목록 전체 조회
## Information :
#############################################################################
getList()
{
    echo -e "VERSION\t  OS-ARCH\t\tDOWNLOAD URL" && \
    echo -e "------- \t-----------\t\t--------------------------------------------------" && \
    curl -s https://api.github.com/repos/velero-io/velero/releases | \
    grep -E '"tag_name":|"browser_download_url":' | \
    sed -E 's/.*: "([^"]+)".*/\1/' | \
    while read -r line; do
        if [[ $line =~ ^v[0-9] ]]; then tag=$line; fi
        if [[ $line =~ \.tar\.gz$ ]]; then
            arch=$(echo $line | sed -E 's/.*velero-v[0-9.]+-([^/]+)\.tar\.gz/\1/')
            echo "$tag $arch $line"
        fi
    done | sort -V | column -t
}


#############################################################################
## Function Name : getParamList()
## Description : OS, Version, Architecture 조건에 맞는 다운로드 URL 조회하기
## Information : 부가 정보 출력여부를PRECHECK 변수로 처리
#############################################################################
getParamList()
{
    OS=${1:-linux}      # 기본값 linux
    VER=${2:-1.8.0}      # 기본값 1.8.1
    ARCH=${3:-amd64}    # 기본값 amd64
    OS_ARCH=${OS}-${ARCH}
    PRECHECK=${4-true}  # 기본값 true  - 사전점검 여부

    if $PRECHECK; then # 사전점검시만 메시시 출력함
        echo "Searching for: OS=$OS, Version=$VER, Arch=$ARCH..."
    fi

    DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/velero-io/velero/releases/tags/v${VER}" | \
                   grep "browser_download_url" | \
                   grep -i "${OS}" | \
                   grep -i "${ARCH}" | \
                   cut -d '"' -f 4)

    if [ -z "$DOWNLOAD_URL" ]; then
        echo "결과를 찾을 수 없습니다. 파라미터를 확인해 주세요."
        echo "--> 조금후에 출력해주는 설치가능 목록을 참고하세요."
        sleep 4
        getList
        return 1  # 오류exit
    else
        if ! $PRECHECK; then # 사전점검시는메시지 출력안함
            echo "$DOWNLOAD_URL"
        fi
        return 0 # 정상 응답
    fi
}

#############################################################################
## Function Name : install-velero()
## Description : 원하는 버전의 프로그램을 설치하고 환경구성함.
## Information :
#############################################################################
install-velero()
{
    echo "--- $1 / $2 / $3 설치 시작 ---"

    TARBALL_NAME="velero-v${2}-${1}-${3}"
    DOWNLOADFILENAME="${TARBALL_NAME}.tar.gz"
    curl -Lo $DOWNLOADFILENAME $(getParamList $1 $2 $3 false) # 다운로드
    tar -xvf $DOWNLOADFILENAME
    chmod +x ${TARBALL_NAME}/velero  # 실행 권한 부여
    mkdir -p $HOME/bin && mv ${TARBALL_NAME}/velero $HOME/bin/velero  #실행파일 디렉토리로이동
    if [ $(echo $PATH | grep "$HOME/bin:" | wc -l) -eq 0 ]; then  # $HOME/bin: PATH 추가
        export PATH=$HOME/bin:$PATH
        echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
    fi
    if [ $(echo $PATH | grep "$HOME/shell:" | wc -l) -eq 0 ]; then  # $HOME/shell: PATH 추가
        export PATH=$HOME/shell:$PATH
        echo 'export PATH=$HOME/shell:$PATH' >> ~/.bashrc
    fi

    # 설치프로그램 정상체크 - 버전 확인
    velero -h

    # file clean up
    rm -fr ${TARBALL_NAME}
}
# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
# 사용법 안내 함수
usage() {
    echo "Usage: $0 <os> <version> <arch>"
    echo "Example: $0 linux 1.8.0 amd64"
    echo "  - os: linux, darwin, windows"
    echo "  - version: e.g., 1.8.0, 1.7.2, (velero supported versions)"
    echo "  - arch: amd64, arm64"
    exit 1
}

# 1. 인자 개수 체크 ($# 는 인자의 개수를 의미)
if [ "$#" -ne 3 ]; then
    echo "Error: 인자의 개수가 맞지 않습니다."
    usage
fi

# 변수 할당
OS=$(echo "$1" | tr '[:upper:]' '[:lower:]') # 소문자로 변환
VER="$2"
ARCH=$(echo "$3" | tr '[:upper:]' '[:lower:]')

# 2. OS 값 유효성 체크
case "$OS" in
    linux|macos|windows) ;; # 허용된 값
    *) echo "Error: 지원하지 않는 OS입니다 ($OS)."; usage ;;
esac

# 3. 아키텍처 값 유효성 체크
case "$ARCH" in
    amd64|arm64|i386) ;;
    *) echo "Error: 지원하지 않는 아키텍처입니다 ($ARCH)."; usage ;;
esac

# 4. 버전 형식 체크 (숫자.숫자 형태인지 정규식 검사)
if [[ ! "$VER" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: 버전 형식이 올바르지 않습니다 ($VER). 예: 1.8.0"
    usage
fi

# 5. 입력 조건에 맞는 URL 존재 여부 확인
getParamList $OS $VER $ARCH true
if [ $? -eq 1 ]; then
    exit 1; # 종료처리
fi

# 6. velero 도구 설치 및 환경설정
install-velero $OS $VER $ARCH
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>=====================================