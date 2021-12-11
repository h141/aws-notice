#!/bin/bash
PYTHONIOENCODING=UTF-8
PRE_IFS=$IFS
IFS=$'\n'
# -------------------------------------
# Connect
# -------------------------------------
$conconf_path="$HOME/_config_00_connect.sh"
# ------------
if [ -f "$conconf_path" ]; then
  . "$conconf_path"
fi
# ----------------- instance
if [ -z "${instanceid+UNDEF}" ]; then
  set -eu
  echo 
  instances=$(aws connect list-instances | jq -r '.InstanceSummaryList[].InstanceAlias')
  instances_num=$(echo $instances | wc --w)
  if [ $instances_num != 0 ]; then
    echo Please, select an amazon connect instance.
    select instance in ${instances}
    do break ; done
  fi
  if [ $instances_num == 0 ]; then
    echo This account does not have an available amazon connect instance.
    echo 
    echo please make it a unique name with alphanumericals and "-",
    echo  Because it is used for the URL of the server. 
    read -p "Enter Instance Alias:" instance
    # --
    echo Start aws connect create-instance $instance
    aws connect create-instance \
      --identity-management-type CONNECT_MANAGED \
      --no-inbound-calls-enabled \
      --outbound-calls-enabled \
      --instance-alias ${instance}
    any_instance="false"
    while [ "${any_instance}" != "true" ]; do
      echo sleep 30
      sleep 30
      any_instance=$(aws connect list-instances | jq -r \
        '.InstanceSummaryList | any( .InstanceAlias == "'${instance}'" )')
      echo now creat instance ${instance} status: ${any_instance}
    done
  fi
  instanceid=$(aws connect list-instances | jq -r \
    '.InstanceSummaryList[]|select ( .InstanceAlias == "'${instance}'" ).Id')
  { set +eu; } 2>/dev/null
fi
echo instanceid $instanceid
# ----------------- queue
if [ -z "${queueid+UNDEF}" -o -z "${queuename+UNDEF}"  ]; then
  set -eu
  echo 
  queues=$(aws connect list-queues --instance-id ${instanceid} | jq '.QueueSummaryList[].Name')
  queues_num=$(echo $queues | wc --w)
  if [ $queues_num == 0 ]; then
    echo This instance does not have an available queue.
    exit
  fi
  echo Please, select a queue in instance $instance.
  select queue in ${queues}
  do break ; done 
  queueid=$(aws connect list-queues --instance-id ${instanceid} | jq -r \
    '.QueueSummaryList[]|select ( .Name == '${queue}' ).Id')
  queue=$(echo ${queue}| tr -d \")
  { set +eu; } 2>/dev/null
fi
echo queueid $queueid
echo queuename $queue
# ----------------- outbound
if [ -z "${phonenumber+UNDEF}" ]; then
  set -eu
  echo 
  outboundid=$(aws connect describe-queue --instance-id ${instanceid} \
    --queue-id ${queueid} | jq -r .Queue.OutboundCallerConfig.OutboundCallerIdNumberId )
  if [ $outboundid != "null" ]; then
    phonenumber=$(aws connect list-phone-numbers --instance-id ${instanceid} \
      | jq -r '.PhoneNumberSummaryList[]|select ( .Id == "'${outboundid}'" ).PhoneNumber' )
  fi
  { set +eu; } 2>/dev/null
fi
if [ ! -z "${phonenumber+UNDEF}" ]; then
  echo phonenumber $phonenumber
fi
# ----------------- flow 
if [ -z "${flowid+UNDEF}" -o -z "${flowname+UNDEF}" ]; then
  set -eu
  echo 
  flows=$(aws connect list-contact-flows --instance-id ${instanceid} \
  | jq '.ContactFlowSummaryList[] |select( .Name | test("^(Default |Sample )") | not ).Name')
  flows_num=$(echo $flows | wc --w)
  if [ $flows_num != 0 ]; then
    echo Please, select a Contact Flow in instance $instance.
    select flow in ${flows} "[Create a new flow]"
    do break ; done 
    if [ "$flow" == "[Create a new flow]" ]; then
      flows_num=0
    fi
  fi
  if [ $flows_num == 0 ]; then
    echo This instance does not have an available queue.
    content=$(cat connect/shub-alert-flow-01.json)
    read -p "Enter Flow Name [shub-alert-flow-01]:" flow
    if [ -z ${flow} ]; then
      flow=shub-alert-flow-01
    fi
    echo Start aws connect contact-flow $flow
    aws connect create-contact-flow \
      --type CONTACT_FLOW \
      --instance-id ${instanceid} \
      --name "${flow}" \
      --content "${content}"
    any_flow="false"
    while [ "${any_flow}" != "true" ]; do
      echo sleep 30
      sleep 30
      any_flow=$(aws connect list-contact-flows --instance-id ${instanceid} | jq -r \
        '.ContactFlowSummaryList | any( .Name == "'${flow}'" )')
      echo now create flow ${flow} status: ${any_flow}
    done
    flow="\"${flow}\""
  fi
  flowid=$(aws connect list-contact-flows --instance-id ${instanceid} | jq -r \
    '.ContactFlowSummaryList[]|select ( .Name == '${flow}' ).Id')
  flow=$(echo ${flow}| tr -d \")
  { set +eu; } 2>/dev/null
fi
echo flowid $flowid
echo flowname $flow
# -------------------------------------
if [ ! -f "$conconf_path" ]; then
  export instanceid=${instanceid}
  export queueid=${queueid}
  export queuename=${queue}
  if [ ! -z "${phonenumber+UNDEF}" ]; then
    export phonenumber=${phonenumber}
  else
    export phonenumber=""
  fi
  export flowid=${flowid}
  export flowname=${flow}
  # --
cat - << EOS > "$conconf_path"
export instanceid=\"${instanceid}\"
export queueid=\"${queueid}\"
export queuename=\"${queue}\"
export phonenumber=\"${phonenumber}\"
export flowid=\"${flowid}\"
export flowname=\"${flow}\"
EOS
fi
# -------------------------------------
IFS=$PRE_IFS
