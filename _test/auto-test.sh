TESTDIR=$(cd $(dirname $0); pwd)
# =====================================================
cd ${TESTDIR}
# --
echo ========================================
echo SSM setup
cd ${TESTDIR}/_ssm/
prfix_ssm=ssm
for ssmfile in ${prfix_ssm}_*.txt ;do
  ssm_name=$(echo ${ssmfile} | sed "s/${prfix_ssm}_//g" | sed "s/.txt//g")
  aws ssm get-parameter --name ${ssm_name} >/dev/null 2>&1
  if [ "$?" != "0" ]; then
    ssm_value=$(cat ${ssmfile} | tr -d "\r" | tr -d "\n")
    echo create ${ssm_name}
    aws ssm put-parameter --type String  --name "${ssm_name}" --value "${ssm_value}"
  fi
done
cd ${TESTDIR}
# =====================================================
TMPFILE=$(mktemp)
SNSNAME=$(aws ssm get-parameter --name SNS_default | jq -r .Parameter.Value)
AWSID=$(aws sts get-caller-identity|jq -r .Account)
# =====================================================
# --
function test_lambda_func () {
  func_name=$1
  filepath=$2
  # --
  envfilepath=$(echo ${filepath}| sed 's/\.json/_env\.json/g')
  if [ -f ${envfilepath} ]; then
    echo "update environment ${envfilepath}"
    echo "-----"
    cat ${envfilepath}
    echo
    echo "-----"
    aws lambda update-function-configuration --function-name "${func_name}" \
      --environment "$(cat ${envfilepath})" >/dev/null
    # aws lambda publish-version --function-name "${func_name}" >/dev/null
    echo sleep 60
    sleep 60
  fi
  json=$(eval echo $(cat ${filepath}| sed 's/\\/\\\\/g'| sed 's/"/\\"/g'| tr -d "\n"))
  echo test ${func_name} ${filepath}
  date=$(TZ=JST-9 date)
  echo DATE: ${date}
  echo -input json------------------------
  echo ${json}
  echo -cmd------------------------
  json64=$(echo ${json}|base64|tr -d "\n")
  aws lambda invoke --function-name ${func_name} --payload "${json64}" "${TMPFILE}"
  echo -outfile------------------------
  cat "${TMPFILE}"
  echo
  echo ========================================
  # wait status change
  cat "${TMPFILE}"|grep errorMessage >/dev/null
  if [ "$?" == "0" ]; then
    echo sleep 180 
    sleep 180
    while [ $status_alarm != "OK" ]; do
      echo wait alert sleep 60 now status ${status_alarm} 
      sleep 60
      status_alarm=$( aws cloudwatch describe-alarms --alarm-names cwalarm-for-${func_name}-errors \
        | jq -r .MetricAlarms[].StateValue)
    done
  else
    status_alarm="_" 
    while [ $status_alarm != "OK" ]; do
      echo sleep 30 now status ${status_alarm} 
      sleep 30
      status_alarm=$( aws cloudwatch describe-alarms --alarm-names cwalarm-for-${func_name}-errors \
        | jq -r .MetricAlarms[].StateValue)
    done
  fi
  if [ -f ${envfilepath} ]; then
    echo reload environment
    org_env_file="${TESTDIR}/org_env_${func_name}.json"
    aws lambda update-function-configuration --function-name "${func_name}" \
      --environment "$(cat ${org_env_file})" >/dev/null
    # aws lambda publish-version --function-name "${func_name}" >/dev/null
    echo sleep 60
    sleep 60
  fi
}
# --
test_type=$2
test_no=$3
declare -A funcs=(
  ["siem"]="shub-siem2securityhub-func"
  ["sns"]="shub-alert-sns-mail-func"
  ["board"]="shub-alert-board-issue-func"
  ["connect"]="shub-alert-connect-phone-func"
)
function test_type_lambda_funcs () {
  tmp_type=$1
  # --
  func_name="${funcs[$tmp_type]}"
  # --
  cd ${TESTDIR}/$tmp_type/
  for inputfile in input_[0-9][0-9].json ;do
    echo "inputfile ${inputfile}"
    echo "-----"
    test_lambda_func "${func_name}" "${TESTDIR}/$tmp_type/${inputfile}"
  done
  echo "environment ${func_name}"
  echo "-----"
  aws lambda get-function-configuration --function-name "${func_name}"
  # ---
  echo sleep 90
  sleep 90
}
echo ========================================
for tmp_type in siem sns board connect ;do
  func_name="${funcs[$tmp_type]}"
  org_env_file="${TESTDIR}/org_env_${func_name}.json"
  aws lambda get-function-configuration --function-name "${func_name}" | \
    jq -r .Environment >"${org_env_file}"
done
# ---
if [ "_$test_type" == "_" -o "$test_type" == "all" ];then
  for tmp_type in siem sns board connect ;do
    cd ${TESTDIR}/$tmp_type/
    test_type_lambda_funcs ${tmp_type}
  done
else
  cd ${TESTDIR}/$test_type/
  func_name="${funcs[$test_type]}"
  if [ "_$test_no" == "_" -a "_$func_name" != "_" ];then
    test_type_lambda_funcs ${test_type}
  elif [ "_$test_no" != "_" -a "_$func_name" != "_" ];then
    test_lambda_func "${func_name}" "${TESTDIR}/$test_type/input_${test_no}.json"
    read -p "next test?" tmp
  else
    echo arg error
  fi
fi