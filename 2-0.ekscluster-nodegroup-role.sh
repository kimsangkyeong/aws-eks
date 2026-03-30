#!/bin/bash
#######################################################################################################
### File Name : 2-0.ekscluster-nodegroup-role.sh
### Description : role of ekscluster and nodegroup
### Information : eksctl schema  정보
###               https://schema.eksctl.io/
###====================================================================================================
### version       date        author        reason
###----------------------------------------------------------------------------------------------------
###    1.0     2026.03.29      ksk         First Version.
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
## Function Name : getClusterRoleForEKS
## Description : EKS Cluster를 위한 Role 정보조회
## Information :
#############################################################################
getClusterRoleForEKS()
{
    # Role Trust Relationship
    ClusterRoleForEKS=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "eks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)
    echo "$ClusterRoleForEKS"
}

#############################################################################
## Function Name : getPolicyOfClusterRoleForEKS
## Description : EKS Cluster의 Role을위한 Policy 조회
## Information :
#############################################################################
getPolicyOfClusterRoleForEKS()
{
    # AWS Managed Policy
    AWSManagedPolicyForClusterRole=$(cat <<EOF
    AmazonEKSClusterPolicy
EOF
)
    echo " -- < aws managed policy >--- "
    echo "$AWSManagedPolicyForClusterRole"
    echo ""

}

#############################################################################
## Function Name : getNodeGroupRoleForEKS
## Description : EKS Cluster NodeGroup를 위한 Role 정보조회
## Information :
#############################################################################
getNodeGroupRoleForEKS()
{
    # Role Trust Relationship
    NodeGroupRoleForEKS=$(cat <<EOF
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
    echo "$NodeGroupRoleForEKS"
}

#############################################################################
## Function Name : getPolicyOfNodeGroupRoleForEKS
## Description : EKS Cluster NodeGroup의 Role을위한 Policy 조회
## Information :
#############################################################################
getPolicyOfNodeGroupRoleForEKS()
{
    # AWS Managed Policy
    AWSManagedPolicyForNodeGroupRole=$(cat <<EOF
    AmazonEKSWorkerNodePolicy
    AmazonEC2ContainerRegistryReadOnly
    AmazonEKS_CNI_Policy
EOF
)

    # AWS Custom Policy
    AWSCustomPolicyForNodeGroupRole=$(cat <<EOF
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
    echo " -- < aws managed policy >--- "
    echo "$AWSManagedPolicyForNodeGroupRole"
    echo ""
    sleep 2
    echo " -- < aws custom policy >--- "
    echo "$AWSCustomPolicyForNodeGroupRole"
    echo ""

}

# =========<<<< Function Registration Area Marking Comment (end) >>>>==================================

# =========<<<< Main Logic Coding Area Marking Comment (start) >>>>====================================
jobProcess "start"  # monitoring - start

printf "\n-------------------------\n"
echo "1. eksctl 환경파일 작성에 필요한 EKS Cluster Role에 필요한 정책 설정하기"
echo "   ==> eks clsuter custom policy name example : policy-xxxxx-eks-cluster "
getPolicyOfClusterRoleForEKS

printf "\n-------------------------\n"
echo "2. eksctl 환경파일 작성에 필요한 EKS Cluster Role Trust Relationship 설정하기"
echo "   ==> eks cluster role name example : role-xxxxx-eks-cluster "
getClusterRoleForEKS

printf "\n-------------------------\n"
echo "3. eksctl 환경파일 작성에 필요한 EKS Cluster NodeGroup Role에 필요한 정책 설정하기"
echo "   ==> eks cluster nodegroup custom policy name example : policy-xxxxx-eks-nodegroup "
getPolicyOfNodeGroupRoleForEKS

printf "\n-------------------------\n"
echo "4. eksctl 환경파일 작성에 필요한 EKS Cluster NodeGroup Role Trust Relationship 설정하기"
echo "   ==> eks cluster nodegroup role name example : role-xxxxx-eks-nodegroup "
getNodeGroupRoleForEKS

jobProcess "end"   # monitoring - end
# =========<<<< Main Logic Coding Area Marking Comment (end) >>>>======================================