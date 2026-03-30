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
## Function Name : getRoleForEbsCsiDriver
## Description : EKS Cluster Addon VPC CNI Driver를 위한 Role 정보조회
## Information : Pod Identity 방식으로 IRSA 처리목적
#############################################################################
getRoleForVPCCNIDriver()
{
    # Role Trust Relationship
    VPCCNIDriverRoleForEKS=$(cat <<EOF
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
    echo "$VPCCNIDriverRoleForEKS"
}

#############################################################################
## Function Name : getPolicyOfRoleForVPCCNIDriver
## Description : EKS Cluster Addon VPC CNI Driver Role을 위한 Role 정보조회
## Information :
#############################################################################
getPolicyOfRoleForVPCCNIDriver()
{
    # AWS Managed Policy
    AWSManagedPolicyForVPCCNIDriver=$(cat <<EOF
    AmazonEKS_CNI_Policy 
EOF
)

    echo " -- < aws managed policy >--- "
    echo "$AWSManagedPolicyForVPCCNIDriver"
    echo ""

}

#############################################################################
## Function Name : getRoleForEbsCsiDriver
## Description : EKS Cluster Addon EBS CSI Driver를 위한 Role 정보조회
## Information : Pod Identity 방식으로 IRSA 처리목적
#############################################################################
getRoleForEbsCsiDriver()
{
    # Role Trust Relationship
    EBSCSIDriverRoleForEKS=$(cat <<EOF
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
    echo "$EBSCSIDriverRoleForEKS"
}

#############################################################################
## Function Name : getPolicyOfRoleForEbsCsiDriver
## Description : EKS Cluster Addon EBS CSI Driver Role을 위한 Role 정보조회
## Information :
#############################################################################
getPolicyOfRoleForEbsCsiDriver()
{
    # AWS Custom Policy
    AWSCustomPolicyForEbsCsiDriver=$(cat <<EOF
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
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInstances",
                "ec2:DescribeSnapshots",
                "ec2:DescribeTags",
                "ec2:DescribeVolumes",
                "ec2:DescribeVolumesModifications"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "ec2:CreateTags",
            "Resource": [
                "arn:aws:ec2:*:*:volume/*",
                "arn:aws:ec2:*:*:snapshot/*"
            ],
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": [
                        "CreateVolume",
                        "CreateSnapshot"
                    ]
                }
            }
        }
    ]
}
EOF
)
    echo " -- < aws custom policy >--- "
    echo "$AWSCustomPolicyForEbsCsiDriver"
    echo ""

}

#############################################################################
## Function Name : getRoleForEfsCsiDriver
## Description : EKS Cluster Addon EFS CSI Driver를 위한 Role 정보조회
## Information : Pod Identity 방식으로 IRSA 처리목적
#############################################################################
getRoleForEfsCsiDriver()
{
    # Role Trust Relationship
    EFSCSIDriverRoleForEKS=$(cat <<EOF
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
    echo "$EFSCSIDriverRoleForEKS"
}
#############################################################################
## Function Name : getPolicyOfRoleForEfsCsiDriver
## Description : EKS Cluster Addon EFS CSI Driver Role을 위한 Role 정보조회
## Information :
#############################################################################
getPolicyOfRoleForEfsCsiDriver()
{
    # AWS Custom Policy
    AWSCustomPolicyForEfsCsiDriver=$(cat <<EOF
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
    echo " -- < aws custom policy >--- "
    echo "$AWSCustomPolicyForEfsCsiDriver"
    echo ""

}

#############################################################################
## Function Name : getRoleForS3CsiDriver
## Description : EKS Cluster Addon S3 CSI Driver를 위한 Role 정보조회
## Information : Pod Identity 방식으로 IRSA 처리목적
#############################################################################
getRoleForS3CsiDriver()
{
    # Role Trust Relationship
    S3CSIDriverRoleForEKS=$(cat <<EOF
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
    echo "$S3CSIDriverRoleForEKS"
}

#############################################################################
## Function Name : getPolicyOfRoleForS3CsiDriver
## Description : EKS Cluster Addon S3 CSI Driver Role을 위한 Role 정보조회
## Information :
#############################################################################
getPolicyOfRoleForS3CsiDriver()
{
    # AWS Custom Policy
    AWSCustomPolicyForS3CsiDriver=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "MountpointS3CanListBuckets",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::<S3 Object Bucket>"
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
            "Resource": "arn:aws:s3:::<S3 Object Bucket>/*"
        }
    ]
}
EOF
)
    echo " -- < aws custom policy >--- "
    echo "$AWSCustomPolicyForS3CsiDriver"
    echo ""

}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
jobProcess "start"  # monitoring - start

printf "\n-------------------------\n"
echo "1. eksctl 환경파일 작성에 필요한 EKS Cluster addon VPC CNI Driver Role에 필요한 정책 설정하기"
getPolicyOfRoleForVPCCNIDriver

printf "\n-------------------------\n"
echo "2. eksctl 환경파일 작성에 필요한 EKS Cluster addon VPC CNI Driver Role Trust Relationship 설정하기"
echo "   ==> eks cluster addon VPC CNI Driver role name example : role-eks-addon-vpc-cni "
getRoleForVPCCNIDriver

printf "\n-------------------------\n"
echo "3. eksctl 환경파일 작성에 필요한 EKS Cluster addon EBS CSI Driver Role에 필요한 정책 설정하기"
echo "   ==> eks clsuter addon EBS CSI Driver custom policy name example : policy-eks-addon-ebs-csi "
getPolicyOfRoleForEbsCsiDriver

printf "\n-------------------------\n"
echo "4. eksctl 환경파일 작성에 필요한 EKS Cluster addon EBS CSI Driver Role Trust Relationship 설정하기"
echo "   ==> eks cluster addon EBS CSI Driver role name example : role-eks-addon-ebs-csi "
getRoleForEbsCsiDriver

printf "\n-------------------------\n"
echo "5. eksctl 환경파일 작성에 필요한 EKS Cluster addon EFS CSI Driver Role에 필요한 정책 설정하기"
echo "   ==> eks clsuter addon EFS CSI Driver custom policy name example : policy-eks-addon-efs-csi "
getPolicyOfRoleForEfsCsiDriver

printf "\n-------------------------\n"
echo "6. eksctl 환경파일 작성에 필요한 EKS Cluster addon EFS CSI Driver Role Trust Relationship 설정하기"
echo "   ==> eks clsuter addon EFS CSI Driver custom policy name example : role-eks-addon-efs-csi "
getRoleForEfsCsiDriver

printf "\n-------------------------\n"
echo "7. eksctl 환경파일 작성에 필요한 EKS Cluster addon S3 CSI Driver Role에 필요한 정책 설정하기"
echo "   ==> eks clsuter addon S3 CSI Driver custom policy name example : policy-eks-addon-s3-csi "
getPolicyOfRoleForS3CsiDriver

printf "\n-------------------------\n"
echo "8. eksctl 환경파일 작성에 필요한 EKS Cluster addon S3 CSI Driver Role Trust Relationship 설정하기"
echo "   ==> eks clsuter addon S3 CSI Driver custom policy name example : role-eks-addon-s3-csi "
getRoleForS3CsiDriver

jobProcess "end"   # monitoring - end
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================
