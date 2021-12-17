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
  func_name="${funcs[siem]}"
  prefix_name="${prefixs[siem]}"
  for testfile in ${prefix_name}_*.json ;do
    test_lambda_func "${func_name}" "${testfile}"
    read -p "next test?" tmp
  done
  # -- To.DO
elif [ "_$test_no" == "_" ];then
  func_name="${funcs[$test_type]}"
  prefix_name="${prefixs[$test_type]}"
  for testfile in ${prefix_name}_*.json ;do
    test_lambda_func "${func_name}" "${testfile}"
    read -p "next test?" tmp
  done
else
  func_name="${funcs[$test_type]}"
  prefix_name="${prefixs[$test_type]}"
  test_lambda_func "${func_name}" "${prefix_name}_${test_no}.json"
  read -p "next test?" tmp
fi
