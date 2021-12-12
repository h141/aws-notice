#!/bin/bash
# -------------------------------------
# Network
# -------------------------------------
stackname="stack-shub-alert-network"
PYTHONIOENCODING=UTF-8
status=$(aws cloudformation describe-stacks --stack-name $stackname | jq -r .Stacks[].StackStatus)
if [ "${status}" == "CREATE_COMPLETE" ]; then
  echo cloudformation stack $stackname has already been created.
else
  set -eu
  az1name=$(aws ec2 describe-availability-zones --region ${AWS_REGION} | \
    jq -r '.AvailabilityZones[]|select( .ZoneId == "apne1-az1" ).ZoneName')
  az4name=$(aws ec2 describe-availability-zones --region ${AWS_REGION} | \
    jq -r '.AvailabilityZones[]|select( .ZoneId == "apne1-az4" ).ZoneName')
  # --
  if [ "$az1name" = "ap-northeast-1a" -o "$az4name" = "ap-northeast-1a" ]; then
    vaza="ap-northeast-1a"
  fi
  if [ "$az1name" = "ap-northeast-1c" -o "$az4name" = "ap-northeast-1c" ]; then
    vazc="ap-northeast-1c"
  fi
  if [ -z "${vaza+UNDEF}" -a "$az4name" = "ap-northeast-1c" ]; then
    vaza=$az1name
  fi
  if [ -z "${vaza+UNDEF}" -a "$az1name" = "ap-northeast-1c" ]; then
    vaza=$az4name
  fi
  if [ -z "${vazc+UNDEF}" -a "$az4name" = "ap-northeast-1a" ]; then
    vazc=$az1name
  fi
  if [ -z "${vazc+UNDEF}" -a "$az1name" = "ap-northeast-1a" ]; then
    vazc=$az4name
  fi
  template_file="file://./02_network.yaml"
  aws cloudformation create-stack --stack-name $stackname \
    --template-body $template_file \
    --enable-termination-protection \
    --tags Key=Product,Value=IntegratedNotification \
    --parameters \
    "ParameterKey=vAZa,ParameterValue='${vaza}'" \
    "ParameterKey=vAZc,ParameterValue='${vazc}'"
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
# -------------------------------------
# Tag VpcEndpointSSMID
set -eu
outputs=$( aws cloudformation describe-stacks --stack-name ${stackname} | jq .Stacks[0].Outputs[] )
# --
for service in SSM SNS Lambda Stepfunctions; do
  idkey="VpcEndpoint${service}ID"
  namekey="VpcEndpoint${service}Name"
  id=$(echo $outputs | jq -r '.|select( .OutputKey == "'$idkey'" ).OutputValue')
  name=$(echo $outputs | jq -r '.|select( .OutputKey == "'$namekey'" ).OutputValue')
  nowtag=$( aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "${id}" | \
    jq -r '.VpcEndpoints | any( .Tags[].Value == "'${name}'")' )
  if [ "${nowtag}" != "true" ]; then
    echo create vpcendpoint tag ${name}.
    aws ec2 create-tags --resources ${id} --tags Key=Name,Value=${name}
  else
    echo vpcendpoint tag ${name} exists already.  
  fi
done
{ set +eu; } 2>/dev/null
# -------------------------------------
