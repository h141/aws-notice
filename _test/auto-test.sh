TESTDIR=$(cd $(dirname $0); pwd)
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
  echo ========================================
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
# --
cd ${TESTDIR}
if [ "_$test_type" == "_" -o "$test_type" == "all" ];then
  for tmp_type in siem sns board connect ;do
    func_name="${funcs[$tmp_type]}"
    prefix_name="${prefixs[$tmp_type]}"
    for testfile in ${prefix_name}_*.json ;do
      echo "testfile ${testfile}"
      echo "-----"
      # test_lambda_func "${func_name}" "${testfile}"
      # read -p "next test?" tmp
    done
    org_env_file="org_${func_name}.json"
    aws lambda get-function-configuration --function-name "${func_name}" | \
      jq -r .Environment >"${org_env_file}"
    for envtestfile in env_${prefix_name}_*.json ;do
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
    echo ========================================
  done
else
  func_name="${funcs[$test_type]}"
  prefix_name="${prefixs[$test_type]}"
  if [ "_$test_no" == "_" -a "_$func_name" != "_" -a "_$prefix_name" != "_" ];then
    for testfile in ${prefix_name}_*.json ;do
      test_lambda_func "${func_name}" "${testfile}"
      read -p "next test?" tmp
    done
  elif [ "_$test_no" != "_" -a "_$func_name" != "_" -a "_$prefix_name" != "_" ];then
    test_lambda_func "${func_name}" "${prefix_name}_${test_no}.json"
    read -p "next test?" tmp
  else
    echo arg error
  fi
fi
