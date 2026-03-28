#!/bin/bash
#######################################################################################################
### File Name : 1-1.install-kubectl.sh
### Description : Install kubectl on the Bastion Server
### Information : * aws reference site
###               - https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
###               You must check every time before installation whether the AWS S3 bucket path for the
###               new version has changed.
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
## Function Name : getList()
## Description : AWS 제공하는site의 정보를 읽어서 설치 가능 버전 목록 전체 조회
## Information :
#############################################################################
getList()
{
    curl -sL "https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html" | \
    grep -oE 'https://s3\.[^" ]+/bin/[^" ]+/kubectl(\.exe)?' | \
    sort -u | \
    jq -R -s '
      split("\n") | map(select(length > 0)) |
      map(split("/") as $p | {
        os: $p[7],
        arch: $p[8],
        version: $p[4],
        url: .
      }) |
      group_by(.os) | map({
        OS: (if .[0].os == "darwin" then "macOS" else .[0].os end),
        downloads: map({
          version: .version,
          architecture: .arch,
          command: ("curl -O " + .url)
        })
     })
    '
}

#############################################################################
## Function Name : getParamList()
## Description : OS, Version, Architecture 조건에 맞는 다운로드 URL 조회하기
## Information : 부가 정보 출력여부를PRECHECK 변수로 처리
#############################################################################
getParamList()
{
    OS=${1:-linux}      # 기본값 linux
    VER=${2:-1.35}      # 기본값 1.35
    ARCH=${3:-amd64}    # 기본값 amd64
    PRECHECK=${4-true}  # 기본값 true  - 사전점검 여부

    if $PRECHECK; then # 사전점검시만 메시시 출력함
        echo "Searching for: OS=$OS, Version=$VER, Arch=$ARCH..."
    fi

    RESULT=$(curl -sL "https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html" | \
    grep -oE 'https://s3\.[^" ]+/bin/[^" ]+/kubectl(\.exe)?' | \
    sort -u | \
    jq -Rr --arg os "$OS" --arg ver "$VER" --arg arch "$ARCH" '
      select(split("/") as $p | $p[7] == $os and ($p[4] | startswith($ver)) and ($p[8] | startswith($arch)))
    ')

    if [ -z "$RESULT" ]; then
        echo "결과를 찾을 수 없습니다. 파라미터를 확인해 주세요."
        echo "--> 조금후에 출력해주는 설치가능 목록을 참고하세요."
        sleep 4
        getList
        return 1  # 오류exit
    else
        if ! $PRECHECK; then # 사전점검시는메시지 출력안함
            echo "$RESULT"
        fi
        return 0 # 정상 응답
    fi
}

#############################################################################
## Function Name : install-kubectl()
## Description : 원하는 버전의 프로그램을 설치하고 환경구성함.
## Information :
#############################################################################
install-kubectl()
{
    echo "--- $1 / $2 / $3 설치 시작 ---"

    curl -O $(getParamList $1 $2 $3 false) # 다운로드
    chmod +x ./kubectl  # 실행 권한 부여
    mkdir -p $HOME/bin && mv ./kubectl $HOME/bin/kubectl  #실행파일 디렉토리로이동
    if [ $(echo $PATH | grep "$HOME/bin:" | wc -l) -eq 0 ]; then  # $HOME/bin: PATH 추가
        export PATH=$HOME/bin:$PATH
        echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
    elif [ $(echo $PATH | grep "$HOME/shell:" | wc -l) -eq 0 ]; then  # $HOME/shell: PATH 추가
        export PATH=$HOME/shell:$PATH
        echo 'export PATH=$HOME/shell:$PATH' >> ~/.bashrc
    fi

    # 설치프로그램 정상체크 - 버전 확인
    kubectl version --client
}
# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
# 사용법 안내 함수
usage() {
    echo "Usage: $0 <os> <version> <arch>"
    echo "Example: $0 linux 1.35 amd64"
    echo "  - os: linux, darwin, windows"
    echo "  - version: e.g., 1.35, 1.34 (EKS supported versions)"
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
    linux|darwin|windows) ;; # 허용된 값
    *) echo "Error: 지원하지 않는 OS입니다 ($OS)."; usage ;;
esac

# 3. 아키텍처 값 유효성 체크
case "$ARCH" in
    amd64|arm64) ;;
    *) echo "Error: 지원하지 않는 아키텍처입니다 ($ARCH)."; usage ;;
esac

# 4. 버전 형식 체크 (숫자.숫자 형태인지 정규식 검사)
if [[ ! "$VER" =~ ^[0-9]+\.[0-9]+ ]]; then
    echo "Error: 버전 형식이 올바르지 않습니다 ($VER). 예: 1.31"
    usage
fi

# 5. 입력 조건에 맞는 URL 존재 여부 확인
getParamList $OS $VER $ARCH true
if [ $? -eq 1 ]; then
    exit 1; # 종료처리
fi

# 6. kubectl 도구 설치 및 환경설정
install-kubectl $OS $VER $ARCH
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================