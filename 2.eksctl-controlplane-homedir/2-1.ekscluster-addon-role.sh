#!/bin/bash
#######################################################################################################
### File Name : 2-1.ekscluster-addon-role.sh
### Description : role of ekscluster and nodegroup
### Information : eksctl schema  정보
###               https://schema.eksctl.io/
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.03.30      ksk         First Version.
###    1.1     2026.04.08      ksk         create eks addon roles
###    1.2     2026.04.10      ksk         create eks control plane & nodegroup roles
###    1.3     2026.04.12      ksk         modify nodegroup roles - AmazonEC2FullAccess 추가
###                                                     ingress로 ALB 생성권한 필요.
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

# replace text variables
PROJECT_NAME=""  # 프로젝트 이름
ENVIRONMENT=""   # 환경구분

# 변수
ROLE_NAME=""
TRUST_POLICY_DOC=""
INLINE_POLICY_NAME=""
INLINE_POLICY_DOC=""
MANAGED_POLICIES=("")
ROLE_TAGS=("")

# =========<<<< Important Global Variable Registration Area Marking Comment (end) >>>>=================

# =========<<<< Function Registration Area Marking Comment (start) >>>>================================
#############################################################################
## Function Name : jobProcess
## Description : Main Job 프로세스 실행 시 모니터링 정보 출력
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
## Function Name : createRole
## Description : Role 생성공통 처리하기
## Information :
#############################################################################
createRole()
{

    echo "--- 검사 시작: $ROLE_NAME ---"

    # 1. Role 존재 여부 확인 및 생성
    # --query 'Role.Arn' 은 성공 시 ARN을 반환하며, 실패 시 에러 코드를 냅니다.
    if aws iam get-role --role-name "$ROLE_NAME" > /dev/null 2>&1; then
        echo "[SKIP] IAM Role '$ROLE_NAME' 이 이미 존재합니다."
        echo " IAM Role Tag 정보 Update"
        # 이미 존재할 경우 태그 업데이트 (Idempotency 보장)
        aws iam tag-role \
            --role-name "$ROLE_NAME" \
            --tags "${ROLE_TAGS[@]}"
    else
        echo "[CREATE] IAM Role '$ROLE_NAME' 을 생성합니다."
        echo "TRUST_POLICY_DOC"
        echo "$TRUST_POLICY_DOC"
        aws iam create-role \
            --role-name "$ROLE_NAME" \
            --assume-role-policy-document "$TRUST_POLICY_DOC"
            --tags "${ROLE_TAGS[@]}"
    fi

    # 2. 정책 적용 (Policy는 존재하더라도 덮어쓰기(Overwrite)가 가능하므로 매번 실행하는 것이 안전합니다)
    echo "[UPDATE] Inline 및 Managed Policy 설정을 동기화합니다..."

    # Inline Policy 업데이트 - custom policy 존재한 경우
    if [ "$INLINE_POLICY_NAME" != "none" ]; then
        echo "[$INLINE_POLICY_NAME] Custom Inline Policy 설정을 동기화합니다..."
        echo "INLINE_POLICY_DOC"
        echo "$INLINE_POLICY_DOC"
        aws iam put-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-name "$INLINE_POLICY_NAME" \
            --policy-document "$INLINE_POLICY_DOC"
    fi

    # Managed Policies 연결
    echo "MANAGED_POLICIES - ${MANAGED_POLICIES[@]}"
    for policy_arn in "${MANAGED_POLICIES[@]}"; do
        echo "[$policy_arn] AWS Managed Policy 설정을 동기화합니다..."
        aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$policy_arn"
    done

}

#############################################################################
## Function Name : createRoleForEKSControlPlane
## Description : EKS Cluster Control Plane을 위한 Role 생성하기
## Information : EKS Cluster 리소스 생성권한 생성
#############################################################################
createRoleForEKSControlPlane()
{

    # 1. 설정
    ROLE_NAME="role-${PROJECT_NAME}-${ENVIRONMENT}-eks-cluster"

    # 2. Trust Relationship (Heredoc)
    TRUST_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "eks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
)
    # 3. Inline Policy (Heredoc) - custom policy
    INLINE_POLICY_NAME="none"
    INLINE_POLICY_DOC=$(cat <<EOF
                        none
EOF
)

    # 4. Managed Policy 리스트
    MANAGED_POLICIES=(
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    )

    # 5. Role Tags
    ROLE_TAGS=(
        "Key=Name,Value=${ROLE_NAME}"
        "Key=project,Value=${PROJECT_NAME}"
        "Key=environment,Value=${ENVIRONMENT}"
    )

    # 6. create role
    createRole

}

#############################################################################
## Function Name : createRoleForEKSNodegroup
## Description : EKS Cluster Nodegroup을 위한 Role 생성하기
## Information : EKS Nodegroup의CNI 관리, EC2, ECR 조회 등 권한 부여
#############################################################################
createRoleForEKSNodegroup()
{

    # 1. 설정
    ROLE_NAME="role-${PROJECT_NAME}-${ENVIRONMENT}-eks-nodegroup"

    # 2. Trust Relationship (Heredoc)
    TRUST_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
)
    # 3. Inline Policy (Heredoc) - custom policy
    INLINE_POLICY_NAME="none"
    INLINE_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowPodIdentityAgent",
            "Effect": "Allow",
            "Action": [
                "eks-auth:AssumeRoleForPodIdentity"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)

    # 4. Managed Policy 리스트
    MANAGED_POLICIES=(
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        "arn:aws:iam::aws:policy/AmazonEC2FullAccess"        
    )

    # 5. Role Tags
    ROLE_TAGS=(
        "Key=Name,Value=${ROLE_NAME}"
        "Key=project,Value=${PROJECT_NAME}"
        "Key=environment,Value=${ENVIRONMENT}"
    )

    # 6. create role
    createRole

}

#############################################################################
## Function Name : createRoleForVPCCNIDriver
## Description : EKS Cluster Addon VPC CNI Driver를 위한 Role 생성하기
## Information : Pod Identity 방식으로 IRSA 처리목적
#############################################################################
createRoleForVPCCNIDriver()
{

    # 1. 설정
    ROLE_NAME="role-${PROJECT_NAME}-${ENVIRONMENT}-eks-addon-vpc-cni"

    # 2. Trust Relationship (Heredoc)
    TRUST_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
EOF
)
    # 3. Inline Policy (Heredoc) - custom policy
    INLINE_POLICY_NAME="none"
    INLINE_POLICY_DOC=$(cat <<EOF
                        none
EOF
)

    # 4. Managed Policy 리스트
    MANAGED_POLICIES=(
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    )

    # 5. Role Tags
    ROLE_TAGS=(
        "Key=Name,Value=${ROLE_NAME}"
        "Key=project,Value=${PROJECT_NAME}"
        "Key=environment,Value=${ENVIRONMENT}"
    )

    # 6. create role
    createRole

}

#############################################################################
## Function Name : createRoleForEBSCSIDriver
## Description : EKS Cluster Addon EBS CSI Driver를 위한 Role 생성하기
## Information : Pod Identity 방식으로 IRSA 처리목적
#############################################################################
createRoleForEBSCSIDriver()
{

    # 1. 설정
    ROLE_NAME="role-${PROJECT_NAME}-${ENVIRONMENT}-eks-addon-ebs-csi"

    # 2. Trust Relationship (Heredoc)
    TRUST_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
EOF
)

    # 3. Inline Policy (Heredoc) - custom policy
    INLINE_POLICY_NAME="EKSAddonEBSCSIDriverPolicy"
    INLINE_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSnapshot",
                "ec2:AttachVolume",
                "ec2:DetachVolume",
                "ec2:ModifyVolume",
                "ec2:CreateVolume",
                "ec2:DeleteVolume",
                "ec2:DescribeVolumeStatus"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)

    # 4. Managed Policy 리스트
    MANAGED_POLICIES=(
        "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    )

    # 5. Role Tags
    ROLE_TAGS=(
        "Key=Name,Value=${ROLE_NAME}"
        "Key=project,Value=${PROJECT_NAME}"
        "Key=environment,Value=${ENVIRONMENT}"
    )

    # 6. create role
    createRole

}

#############################################################################
## Function Name : createRoleForEFSCSIDriver
## Description : EKS Cluster Addon EFS CSI Driver를 위한 Role 생성하기
## Information : Pod Identity 방식으로 IRSA 처리목적
#############################################################################
createRoleForEFSCSIDriver()
{

    # 1. 설정
    ROLE_NAME="role-${PROJECT_NAME}-${ENVIRONMENT}-eks-addon-efs-csi"

    # 2. Trust Relationship (Heredoc)
    TRUST_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
EOF
)

    # 3. Inline Policy (Heredoc) - custom policy
    INLINE_POLICY_NAME="EKSAddonEFSCSIDriverPolicy"
    INLINE_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "elasticfilesystem:DescribeAccessPoints",
                "elasticfilesystem:DescribeFileSystems",
                "elasticfilesystem:DescribeMountTargets",
                "ec2:DescribeAvailabilityZones"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticfilesystem:CreateAccessPoint"
            ],
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "aws:RequestTag/efs.csi.aws.com/cluster": "true"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": "elasticfilesystem:DeleteAccessPoint",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
                }
            }
        }
    ]
}
EOF
)

    # 4. Managed Policy 리스트
    MANAGED_POLICIES=(
    )

    # 5. Role Tags
    ROLE_TAGS=(
        "Key=Name,Value=${ROLE_NAME}"
        "Key=project,Value=${PROJECT_NAME}"
        "Key=environment,Value=${ENVIRONMENT}"
    )

    # 6. create role
    createRole
}

#############################################################################
## Function Name : createRoleForS3CSIDriver
## Description : EKS Cluster Addon S3 CSI Driver를 위한 Role 생성하기
## Information : Pod Identity 방식으로 IRSA 처리목적
#############################################################################
createRoleForS3CSIDriver()
{

    # 1. 설정
    ROLE_NAME="role-${PROJECT_NAME}-${ENVIRONMENT}-eks-addon-s3-csi"

    # 2. Trust Relationship (Heredoc)
    TRUST_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
EOF
)

    # 3. Inline Policy (Heredoc) - custom policy
    INLINE_POLICY_NAME="EKSAddonS3CSIDriverPolicy"
    INLINE_POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "MountpointS3CanListBuckets",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::*"
        },
        {
            "Sid": "MountpointS3CanReadWriteObjects",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::*/*"
        }
    ]
}
EOF
)

    # 4. Managed Policy 리스트
    MANAGED_POLICIES=(
    )

    # 5. Role Tags
    ROLE_TAGS=(
        "Key=Name,Value=${ROLE_NAME}"
        "Key=project,Value=${PROJECT_NAME}"
        "Key=environment,Value=${ENVIRONMENT}"
    )

    # 6. create role
    createRole

}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================

PROJECT_NAME=$1
ENVIRONMENT=$2

if [ -z "$PROJECT_NAME" -o -z "$ENVIRONMENT" ]; then
    echo "Usage: ./2-1.ekscluster-addon-role.sh <project_name> <environment>"
    echo "Example: ./2-1.ekscluster-addon-role.sh hellow dev "
    exit 1
fi

printf "\n#########################\n"
printf "\n-<< ./2-1.ekscluster-addon-role.sh $PROJECT_NAME $ENVIRONMENT >>--\n"
printf "\n#########################\n"

jobProcess "start"  # monitoring - start

###  << 이하EKS Cluster Control Plane & Nodegroup Role 생성>> ###
printf "\n-------------------------\n"
echo "cluter-1. eksctl 환경파일 작성에 필요한 EKS Cluster Control Plane Role 생성 하기"
createRoleForEKSControlPlane
jobProcess "checking"   # monitoring - checking

printf "\n-------------------------\n"
echo "cluter-2. eksctl 환경파일 작성에 필요한 EKS Cluster Nodegroup Role 생성 하기"
createRoleForEKSNodegroup
jobProcess "checking"   # monitoring - checking

###  << 이하EKS Cluster Addon 서비스 Role 생성>> ###
printf "\n-------------------------\n"
echo "addon-1. eksctl 환경파일 작성에 필요한 EKS Cluster addon VPC CNI Driver Role 생성 하기"
createRoleForVPCCNIDriver
jobProcess "checking"   # monitoring - checking

printf "\n-------------------------\n"
echo "addon-2. eksctl 환경파일 작성에 필요한 EKS Cluster addon EBS CSI Driver Role 생성 하기"
createRoleForEBSCSIDriver
jobProcess "checking"   # monitoring - checking

printf "\n-------------------------\n"
echo "addon-3. eksctl 환경파일 작성에 필요한 EKS Cluster addon EFS CSI Driver Role 생성 하기"
createRoleForEFSCSIDriver
jobProcess "checking"   # monitoring - checking

printf "\n-------------------------\n"
echo "addon-4. eksctl 환경파일 작성에 필요한 EKS Cluster addon S3 CSI Driver Role 생성 하기"
createRoleForS3CSIDriver

jobProcess "end"   # monitoring - end

# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
