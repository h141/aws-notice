TESTDIR=$(cd $(dirname $0); pwd)
# =====================================================
cd ${TESTDIR}
# --
echo ========================================
cd ${TESTDIR}/_ssm/
prfix_ssm=ssm
for ssmfile in ${prfix_ssm}_*.txt ;do
  ssm_name=$(echo ${ssmfile} | sed "s/${prfix_ssm}_//g" | sed "s/.txt//g")
  ssm_value=$(cat ${ssmfile} | tr -d "\r" | tr -d "\n")
  echo create ${ssm_name}
  echo aws ssm put-parameter --type String --name "${ssm_name}" --value "${ssm_value}"
  aws ssm put-parameter --type String  --name "${ssm_name}" --value "${ssm_value}"
done
cd ${TESTDIR}
# =====================================================
TMPFILE=$(mktemp)
SNSNAME=$(aws ssm get-parameter --name SNS_default | jq -r .Parameter.Value)
AWSID=$(aws sts get-caller-identity|jq -r .Account)
# =====================================================
# --
function test_lambda_func () {
  funcname=$1
  filepath=$2
  org_env_file="${TESTDIR}/org_env_${funcname}.json"
  aws lambda get-function-configuration --function-name "${funcname}" | \
    jq -r .Environment >"${org_env_file}"
  # --
  envfilepath=$(echo ${filepath}| sed 's/\.json/_env\.json/g')
  if [ -f ${envfilepath} ]; then
    echo "update environment ${envfilepath}"
    echo "-----"
    cat ${envfilepath}
    echo
    echo "-----"
    #aws lambda update-function-configuration --function-name "${func_name}" \
    #  --environment "$(cat ${envfilepath})" >/dev/null
  fi
  json=$(eval echo $(cat ${filepath}| sed 's/\\/\\\\/g'| sed 's/"/\\"/g'| tr -d "\n"))
  echo test ${funcname} ${filepath}
  date=$(TZ=JST-9 date)
  echo DATE: ${date}
  echo -input json------------------------
  echo ${json}
  echo -cmd------------------------
  json64=$(echo ${json}|base64|tr -d "\n")
  # aws lambda invoke --function-name ${funcname} --payload "${json64}" "${TMPFILE}"
  echo -outfile------------------------
  cat "${TMPFILE}"
  echo
  echo ========================================
  aws lambda update-function-configuration --function-name "${funcname}" \
    --environment "$(cat ${org_env_file})"
  echo ${status_alarm}
  # wait status change
  status_alarm="_"
  while [ $status_alarm != "OK" ]; do
    echo sleep 20 now status ${status_alarm} 
    sleep 20
    status_alarm=$( aws cloudwatch describe-alarms --alarm-names cwalarm-for-${funcname}-errors \
      | jq -r .MetricAlarms[].StateValue)
  done
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
  cd ${TESTDIR}/${tmp_type}/
  func_name="${funcs[$tmp_type]}"
  for inputfile in input_[0-9][0-9].json ;do
    echo "inputfile ${inputfile}"
    echo "-----"
    test_lambda_func "${func_name}" "${inputfile}"
  done
  echo "environment ${func_name}"
  echo "-----"
  aws lambda get-function-configuration --function-name "${func_name}"
}
echo ========================================
if [ "_$test_type" == "_" -o "$test_type" == "all" ];then
  for tmp_type in siem sns board connect ;do
    test_type_lambda_funcs ${tmp_type}
  done
else
  func_name="${funcs[$test_type]}"
  if [ "_$test_no" == "_" -a "_$func_name" != "_" ];then
    test_type_lambda_funcs ${test_type}
  elif [ "_$test_no" != "_" -a "_$func_name" != "_" ];then
    test_lambda_func "${func_name}" "${test_type}/index_${test_no}.json"
    read -p "next test?" tmp
  else
    echo arg error
  fi
fi