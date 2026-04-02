#!/bin/bash
#######################################################################################################
### File Name : 1-d.create-keypair.sh
### Description : create keypair on the Bastion Server
### Information : 
###
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.04.02      ksk         First Version.
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
## Function Name : create-keypair
## Description : 동일 Key 이름이 있으면 Skip 없으면 keypair 생성하고 pem 파일 저장하기.
## Information :
#############################################################################
create-keypair()
{
    echo "--- AWS Keypair 생성 시작 ---"
    KEY_NAME=$1
    KEY_FILE="${KEY_NAME}.pem"

    # 1. AWS CLI를 통해 키페어 존재 여부 확인 (있으면 "EXISTS", 없으면 "EMPTY")
    CHECK_KEY=$(aws ec2 describe-key-pairs --key-names "$KEY_NAME" --query 'KeyPairs[0].KeyName' --output text 2>&1)
    
    # 에러 메시지에 'NotFound'가 포함되어 있는지 확인하여 분기 처리
    case "$CHECK_KEY" in
        *"InvalidKeyPair.NotFound"*)
            echo ">>>> Key pair '$KEY_NAME' 가 없습니다. 새로 생성합니다."
            
            # 키 생성 및 파일 저장
            aws ec2 create-key-pair \
                --key-name "$KEY_NAME" \
                --query 'KeyMaterial' \
                --output text > "$KEY_FILE"
            
            # 권한 변경 및 이동하기
            chmod 400 "$KEY_FILE" && mv "$KEY_FILE" $HOME/bin
            # 생성파일 점검하기           
            ls -al $HOME/bin/"$KEY_FILE"
            echo ".........."
            ;;
        "$KEY_NAME")
            echo ">>>> Key pair '$KEY_NAME' 가 이미 존재합니다. 생성을 건너뜁니다."
            # 생성파일 점검하기           
            ls -al $HOME/bin/"$KEY_FILE"
            echo ".........."
            ;;
        *)
            echo ">>>> 알 수 없는 오류가 발생했습니다: $CHECK_KEY"
            ;;
    esac
}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
# 사용법 안내 함수
usage() {
    echo "Usage: $0 <keyname>"
    echo "Example: $0 key-mgmt-eks-node"
    echo " ===================="
    echo " 생성 후 Instance에 접속 방법 : ssh -i $HOME/bin/key-mgmt-eks-node.pem ec2-user@<Worker-Node-Private-IP> "
    exit 1
}

# 1. 인자 개수 체크 ($# 는 인자의 개수를 의미)
if [ "$#" -ne 1 ]; then
    echo "Error: 인자의 개수가 맞지 않습니다."
    usage
fi

# 2. aws keypair 생성
create-keypair $1
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
