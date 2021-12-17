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
echo 1: $1
echo 2: $2
echo 3: $3

exit


cd ${TESTDIR}
for testfile in siem_*.json ;do
  test_lambda_func "shub-siem2securityhub-func" "${testfile}"
  read -p "next test?" tmp
done
