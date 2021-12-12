#!/bin/bash
PYTHONIOENCODING=UTF-8
# -------------------------------------
# SNS Infra Alert
# -------------------------------------
sns_infra_alert_name="infra-alert-snstopic"
aws sns list-topics | jq -r '.Topics[].TopicArn'|cut --d : --f 6|grep "^${sns_infra_alert_name}$" >/dev/null
rtn_sns_infra_alert=$?
if [ ${rtn_sns_infra_alert} == 0 ]; then
  echo "SNS topic \"${sns_infra_alert_name}\" already exists." 
else
  echo Create SNS Topic and Subscription
  echo
  read -p "Enter mail address for SNStopic \"${sns_infra_alert_name}\":" mailaddress
  # ------------------------------------------
  template_file="file://./00_sns_infra_alert.yaml"
  stackname="stack-tmp-infra-alert-snstopic"
  # --
  aws cloudformation create-stack --stack-name $stackname \
    --template-body $template_file \
    --no-enable-termination-protection \
    --tags Key=Product,Value=IntegratedNotification \
    --parameters \
    "ParameterKey=vMailAddress,ParameterValue='${mailaddress}'" \
    "ParameterKey=vSNSTopic,ParameterValue='${sns_infra_alert_name}'"
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
export sns_infra_alert=$( aws sns list-topics | jq -r '.Topics[].TopicArn'| \
  grep ":${sns_infra_alert_name}$" )
echo "export sns_infra_alert=\"${sns_infra_alert}\""
