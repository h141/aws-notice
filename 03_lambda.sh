#!/bin/bash
# -------------------------------------
# StepFunctions Lambda
# -------------------------------------
conconf_path="$HOME/_config_03_lambda.sh"
# ------------
if [ -f "$conconf_path" ]; then
  . "$conconf_path"
fi

stackname="stack-shub-alert-sf-lambda"
PYTHONIOENCODING=UTF-8
status=$(aws cloudformation describe-stacks --stack-name $stackname | jq -r .Stacks[].StackStatus)
if [ "${status}" == "CREATE_COMPLETE" ]; then
  echo cloudformation stack $stackname has already been created.
else
  set -eu
  # --------------------------------
  # ParameterKey=vS3bucketName,ParameterValue='${cfbucket}'
  # search S3 bucket for CFn template
  cfbucket=$(aws s3 ls|grep cf-templates-.*-${AWS_REGION}|cut -d " " -f 3|head -1)
  echo vS3bucketName: ${cfbucket}
  echo
  # --------------------------------
  # ParameterKey=vLayerZipPath,ParameterValue='${layerzippath}'
  # upload lambda zipfile
  echo Upload lambda zipfile to S3 bucket ${cfbucket}
  echo
  for file in $(ls -1F code/*.py); do
    cp -f $file /tmp/lambda_function.py
    zipname=$(basename $file .py| cut -d "_" -f2-)
    zip -j $zipname /tmp/lambda_function.py >/dev/null
    aws s3 cp ${zipname}.zip s3://${cfbucket}/code/
    rm -f ${zipname}.zip
  done
  echo
  # upload layer zipfile
  echo Upload layer file to S3 bucket ${cfbucket}
  echo
  layerzippath=$(ls -1F layer/*.zip|head -1)
  aws s3 cp $layerzippath s3://${cfbucket}/layer/
  echo
  # --------------------------------
  # ParameterKey=vAccountName,ParameterValue='${accountname}'
  if [ -z "${accountname+UNDEF}" ]; then
    accountname="PROD"
  fi
  echo vAccountName: ${accountname}
  echo
  # ------------------------------------- SNS ---
  # ParameterKey=vSSMSNSdefault,ParameterValue='${sns_default}'
  if [ -z "${sns_default+UNDEF}" ]; then
    topics=$(aws sns list-topics | jq -r '.Topics[].TopicArn'|cut --d : --f 6)
    echo Please, select an sns_default to notify.
    select sns_default in ${topics}
    do break ; done 
    echo sns_default="$sns_default" >> "$conconf_path"
    echo
  fi
  echo vSSMSNSdefault: ${sns_default}
  echo
  # ------------------------------------- ADB ---
  # ParameterKey=vDevOpsPAT,ParameterValue='${pat}'
  if [ -z "${pat+UNDEF}" ]; then
    read -p "Enter azure devops PAT:" pat
  fi
  echo vDevOpsPAT: ${pat}
  # ParameterKey=vDevOpsORGANIZATION,ParameterValue='${organization}'
  if [ -z "${organization+UNDEF}" ]; then
    read -p "Enter azure devops ORGANIZATION:" organization
  fi
  echo vDevOpsORGANIZATION: ${organization}
  echo
  # ------
  # ParameterKey=vSSMADBdefault,ParameterValue='${adb_default}'
  if [ -z "${adb_default_project+UNDEF}" ]; then
    read -p "Enter azure devops PROJECT:" adb_default_project
  fi
  if [ -z "${adb_default_team+UNDEF}" ]; then
    read -p "Enter azure devops TEAM:" adb_default_team
  fi
  # --
  if [ -z "${adb_default_title+UNDEF}" ]; then
    read -p "Enter azure devops TITLE[AWS System failure]:" adb_default_title
  fi
  adb_default_title="${adb_default_title:=AWS System failure}"
  # --
  if [ -z "${adb_default_type+UNDEF}" ]; then
    read -p "Enter azure devops TYPE [bug]:" adb_default_type
  fi
  adb_default_type="${adb_default_type:=bug}"
  # --
  if [ -z "${adb_default_tags+UNDEF}" ]; then
    read -p "Enter azure devops TAGS [aws; alarm;]:" adb_default_tags
  fi
  adb_default_tags="${adb_default_tags:=aws; alarm;}"
  # --
  if [ -z "${adb_default_parentid+UNDEF}" ]; then
    read -p "Enter azure devops PARENT ID :" adb_default_parentid
  fi
  # --
  if [ -z "${adb_default_parentid+UNDEF}" ]; then
    adb_default='{project:"'${adb_default_project}'",team:"'${adb_default_team}'",title:"'${adb_default_title}'",type:"'${adb_default_type}'",tags:"'${adb_default_tags}'"}'
  else
    adb_default='{project:"'${adb_default_project}'",team:"'${adb_default_team}'",title:"'${adb_default_title}'",type:"'${adb_default_type}'",tags:"'${adb_default_tags}'",parentid:"'${adb_default_parentid}'"}'
  fi
  echo vSSMADBdefault: ${adb_default}
  echo
  # ------------------------------------- CPN ---
  # ParameterKey=vSSMCPNdefault,ParameterValue='${cpn_default}'
  if [ -z "${cpn_default+UNDEF}" ]; then
    echo cpn_default example: +819012345678,+819098765432
    read -p "Enter your phone numbers in E.164 format:" cpn_default
  fi
  echo
  echo vSSMCPNdefault: ${cpn_default}
  # -----------------------
  # ParameterKey=vSMFilePath,ParameterValue='${smfilepath}'
  # upload stepfunctions smfile
  echo
  echo Upload stepfunctions smfile to S3 bucket ${cfbucket}
  smfilepath=$(ls -1F statemachine/*.yaml|head -1)
  aws s3 cp $smfilepath s3://${cfbucket}/statemachine/
  echo
  # ------------------------------------------
  template_file="file://./03_lambda.yaml"
  # --
  # adb_default=$(echo $adb_default | sed 's/ /\\ /g')
  set -x
  aws cloudformation create-stack --stack-name $stackname \
    --template-body $template_file \
    --enable-termination-protection \
    --tags Key=Product,Value=IntegratedNotification \
    --parameters \
    "ParameterKey=vS3bucketName,ParameterValue='${cfbucket}'" \
    "ParameterKey=vLayerZipPath,ParameterValue='${layerzippath}'" \
    "ParameterKey=vAccountName,ParameterValue='${accountname}'" \
    "ParameterKey=vSSMSNSdefault,ParameterValue='${sns_default}'" \
    "ParameterKey=vSSMCPNdefault,ParameterValue='${cpn_default}'" \
    "ParameterKey=vSMFilePath,ParameterValue='${smfilepath}'" \
    "ParameterKey=vDevOpsPAT,ParameterValue='${pat}'" \
    "ParameterKey=vDevOpsORGANIZATION,ParameterValue='${organization}'" \
    "ParameterKey=vConnectInstanceId,ParameterValue='${instanceid}'" \
    "ParameterKey=vConnectQueueId,ParameterValue='${queueid}'" \
    "ParameterKey=vConnectQueueName,ParameterValue='${queuename}'" \
    "ParameterKey=vConnectFlowId,ParameterValue='${flowid}'" \
    "ParameterKey=vConnectFlowName,ParameterValue='${flowname}'" \
    "ParameterKey=vConnectSourcePhoneNumber,ParameterValue='${phonenumber}'" \
    "ParameterKey=vSSMADBdefault,ParameterValue='${adb_default}'"
  set +x
  # -------------------------------------
  # wait status change
  status="CREATE_IN_PROGRESS"
  echo Start CloudFormation Stack
  while [ $status == "CREATE_IN_PROGRESS" ]; do
    echo sleep 30
    sleep 30
    status=$(aws cloudformation describe-stacks --stack-name $stackname | jq -r .Stacks[].StackStatus)
    echo Now CloudFormation Stack Status $status
  done
  if [ $status != "CREATE_COMPLETE" ]; then
    echo "ERROR  CloudFormation Stack Status $status"
    printf '\033[31m%s\033[m\n' "Forced Termination"
    exit 
  fi
  { set +eu; } 2>/dev/null
fi

  