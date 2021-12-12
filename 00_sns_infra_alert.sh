#!/bin/bash
PYTHONIOENCODING=UTF-8
# -------------------------------------
# SNS Infra Alert
# -------------------------------------
sns_infra_alert="infra-alert-snstopic"
aws sns list-topics | jq -r '.Topics[].TopicArn'|cut --d : --f 6|grep -v "^${sns_infra_alert}$" >/dev/null
rtn_sns_infra_alert=$?
if [ $rtn_sns_infra_alert != 0 ]; then
  echo Create SNS Topic and Subscription
  echo
  read -p "Enter mail address for SNStopic \"${sns_infra_alert}\":" mailaddress
  # ------------------------------------------
  template_file="file://./00_sns_infra_alert.yaml"
  stackname="stack-tmp-infra-alert-snstopic"
  # --
  aws cloudformation create-stack --stack-name $stackname \
    --template-body $template_file \
    --enable-termination-protection \
    --tags Key=Product,Value=IntegratedNotification \
    --parameters \
    "ParameterKey=vMailAddress,ParameterValue='${mailaddress}'" \
    "ParameterKey=vSNSTopic,ParameterValue='${sns_infra_alert}'"
  { set +eu; } 2>/dev/null
else
  echo "SNS topic \"${sns_infra_alert}\" already exists." 
fi
