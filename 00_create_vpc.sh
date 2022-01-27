#!/bin/bash
PYTHONIOENCODING=UTF-8
stackname="stack-shub-alert-vpc"
PYTHONIOENCODING=UTF-8
status=$(aws cloudformation describe-stacks --stack-name $stackname 2>/dev/null | jq -r .Stacks[].StackStatus)
if [ "${status}" == "CREATE_COMPLETE" ]; then
  echo cloudformation stack $stackname has already been created.
elif [ -n "${status}" ]; then
    echo "ERROR  CloudFormation Stack Status $status"
    printf '\033[31m%s\033[m\n' "Forced Termination. Delete Stack $stackname."
    exit 
else
  template_file="file://./00_create_vpc.yaml"
  aws cloudformation create-stack --stack-name $stackname \
    --template-body $template_file \
    --enable-termination-protection \
    --tags Key=Product,Value=IntegratedNotification
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
  if [ "x$status" != "xCREATE_COMPLETE" ]; then
    echo "ERROR  CloudFormation Stack Status $status"
    printf '\033[31m%s\033[m\n' "Forced Termination"
    exit 
  fi
  { set +eu; } 2>/dev/null
  # ---
  echo "Do you want to interrupt it?"
  echo "If you start this script again, the previous process will continue."
  read -p "Interrupt? [y]" interrupt
  interrupt="${interrupt:=y}"
  if [ $interrupt == "y" -o $interrupt == "Y" ]; then
    exit
  fi
fi
