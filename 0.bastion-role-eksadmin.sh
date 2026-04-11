#!/bin/bash
#######################################################################################################
### File Name : 0.bastion-role-eksadmin.sh
### Description : role of Bastion Server for eksadmin
### Information :
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.03.29      ksk         First Version.
###    1.1     2026.04.12      ksk         rename filename and modify policy
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
## Function Name : getBastionRoleForEKSAdmin
## Description : EKS Admin을 위한 Bastion 서버의 Role 정보 조회
## Information :
#############################################################################
getBastionRoleForEKSAdmin()
{
    # Role Trust Relationship
    BastionRoleForEKSAdmin=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)
    echo "$BastionRoleForEKSAdmin"
}

#############################################################################
## Function Name : getPolicyOfBastionRoleForEKSAdmin
## Description : EKS Admin을 위한 Bastikon 서버의 Role을 위한 Policy 조회
## Information :
#############################################################################
getPolicyOfBastionRoleForEKSAdmin()
{
    # AWS Managed Policy
    AWSManagedPolicyForExecuteEKSCTL=$(cat <<EOF
    AWSCloudFormationFullAccess - eksctl이 모든 리소스를 stack으로 생성
EOF
)

    # AWS Custom Policy
    AWSCustomPolicyForExecuteEKSCTL=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EKSFullManagement",
            "Effect": "Allow",
            "Action": [
                "eks:*",
                "ssm:GetParameter",
                "kms:CreateGrant",
                "kms:DescribeKey"
            ],
            "Resource": "*"
        },
        {
            "Sid": "IAMManagementWithTagging",
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:GetRole",
                "iam:ListRoles",
                "iam:AttachRolePolicy",
                "iam:ListAttachedRolePolicies",
                "iam:DetachRolePolicy",
                "iam:CreatePolicy",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:GetRolePolicy",
                "iam:CreateInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:CreateOpenIDConnectProvider",
                "iam:DeleteOpenIDConnectProvider",
                "iam:GetOpenIDConnectProvider",
                "iam:CreateServiceLinkedRole",
                "iam:TagRole",
                "iam:UntagRole",
                "iam:TagInstanceProfile",
                "iam:UntagInstanceProfile",
                "iam:TagOpenIDConnectProvider",
                "iam:UntagOpenIDConnectProvider",
                "iam:TagPolicy",
                "iam:UntagPolicy",
                "iam:UpdateAssumeRolePolicy"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ScopedPassRole",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": [
                "arn:aws:iam::*:role/eksctl-*",
                "arn:aws:iam::*:role/*eks*role*",
                "arn:aws:iam::*:role/*eks*Role*",
                "arn:aws:iam::*:role/*Role*eks*",
                "arn:aws:iam::*:role/*role*eks*"
            ],
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": [
                        "eks.amazonaws.com",
                        "ec2.amazonaws.com",
                        "eks-addons.amazonaws.com",
                        "pods.eks.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Sid": "InfrastructureManagement",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateVpc",
                "ec2:Describe*",
                "ec2:CreateSubnet",
                "ec2:CreateInternetGateway",
                "ec2:AttachInternetGateway",
                "ec2:CreateRouteTable",
                "ec2:CreateRoute",
                "ec2:AssociateRouteTable",
                "ec2:CreateSecurityGroup",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:CreateTags",
                "ec2:RunInstances",
                "ec2:TerminateInstances",
                "ec2:CreateLaunchTemplate",
                "ec2:DeleteLaunchTemplate",
                "ec2:CreateLaunchTemplateVersion",
                "ec2:DeleteLaunchTemplateVersions",
                "ec2:GetLaunchTemplateData",
                "ec2:ModifyLaunchTemplate",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DeleteSecurityGroup",
                "ec2:CreateKeyPair"
            ],
            "Resource": "*"
        },
        {
            "Sid": "S3",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CloudWatchLogsCLI",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:GetLogEvents",
                "logs:FilterLogEvents",
                "logs:StartQuery",
                "logs:GetQueryResults"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)
    echo " -- < aws managed policy >--- "
    echo "$AWSManagedPolicyForExecuteEKSCTL"
    echo ""
    sleep 2
    echo " -- < aws custom policy >--- "
    echo "$AWSCustomPolicyForExecuteEKSCTL"
    echo ""

}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
jobProcess "start"  # monitoring - start

printf "\n-------------------------\n"
echo "1. Bastion 서버의 Role에 필요한 정책 설정하기"
echo "   ==> Bastion Server custom policy name example : policy-<project_name>-<environment>-bastion-bastion-eksadmin"
getPolicyOfBastionRoleForEKSAdmin

printf "\n-------------------------\n"
echo "2. Bastion Role Trust Relationship 설정하기"
echo "   ==> Bastion Server Role name example : role-<project_name>-<environment>--bastion-eksadmin"
getBastionRoleForEKSAdmin

jobProcess "end"   # monitoring - end
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================