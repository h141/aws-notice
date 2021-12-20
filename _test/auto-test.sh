TESTDIR=$(cd $(dirname $0); pwd)
# =====================================================
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
  json=$(eval echo $(cat ${filepath}| sed 's/\\/\\\\/g'| sed 's/"/\\"/g'| tr -d "\n"))
  echo test ${funcname} ${filepath}
  date=$(TZ=JST-9 date)
  echo DATE: ${date}
  echo -input json------------------------
  echo ${json}
  echo -cmd------------------------
  json64=$(echo ${json}|base64|tr -d "\n")
  aws lambda invoke --function-name ${funcname} --payload "${json64}" "${TMPFILE}"
  echo -outfile------------------------
  cat "${TMPFILE}"
  echo
  echo ========================================
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
declare -A prefixs=(
  ["siem"]="siem"
  ["sns"]="securityhub"
  ["board"]="securityhub"
  ["connect"]="securityhub"
)
function test_type_lambda_funcs () {
  tmp_type=$1
  func_name="${funcs[$tmp_type]}"
  prefix_name="${prefixs[$tmp_type]}"
  for testfile in ${prefix_name}_*.json ;do
    echo "testfile ${testfile}"
    echo "-----"
    test_lambda_func "${func_name}" "${testfile}"
    read -p "next test?" tmp
  done
  org_env_file="org_env_${func_name}.json"
  aws lambda get-function-configuration --function-name "${func_name}" | \
    jq -r .Environment >"${org_env_file}"
  testfile=${prefix_name}_02.json
  for envtestfile in env_${tmp_type}_*.json ;do
    echo "update environment ${envtestfile}"
    echo "-----"
    cat ${envtestfile}
    echo
    echo "-----"
    aws lambda update-function-configuration --function-name "${func_name}" \
      --environment "$(cat ${envtestfile})" >/dev/null
    test_lambda_func "${func_name}" "${testfile}"
    read -p "next test?" tmp
    echo ========================================
  done
  echo "update environment ${org_env_file}"
  echo "-----"
  aws lambda update-function-configuration --function-name "${func_name}" \
    --environment "$(cat ${org_env_file})"
  echo "-----"
  aws lambda get-function-configuration --function-name "${func_name}"
  read -p "next test?" tmp
}
# --
cd ${TESTDIR}
echo ========================================
prfix_ssm=ssm
for ssmfile in ${prfix_ssm}_*.txt ;do
  ssm_name=$(echo ${ssmfile} | sed "s/${prfix_ssm}_//g" | sed "s/.txt//g")
  ssm_value=$(cat ${ssmfile} | tr -d "\r" | tr -d "\n")
  echo create ${ssm_name}
  echo aws ssm put-parameter --name "${ssm_name}" --value "${ssm_value}"
  aws ssm put-parameter --name "${ssm_name}" --value "${ssm_value}"
done
exit
echo ========================================
if [ "_$test_type" == "_" -o "$test_type" == "all" ];then
  for tmp_type in siem sns board connect ;do
    test_type_lambda_funcs ${tmp_type}
  done
else
  func_name="${funcs[$test_type]}"
  prefix_name="${prefixs[$test_type]}"
  if [ "_$test_no" == "_" -a "_$func_name" != "_" -a "_$prefix_name" != "_" ];then
    test_type_lambda_funcs ${test_type}
  elif [ "_$test_no" != "_" -a "_$func_name" != "_" -a "_$prefix_name" != "_" ];then
    test_lambda_func "${func_name}" "${prefix_name}_${test_no}.json"
    read -p "next test?" tmp
  else
    echo arg error
  fi
fi
