TESTDIR=$(cd $(dirname $0); pwd)
cd ${TESTDIR}
# --
test01="aws lambda invoke --function-name shub-siem2securityhub-func"
cd ${TESTDIR}
SNSNAME=$(aws ssm get-parameter --name SNS_default | jq -r .Parameter.Value)
AWSID=$(aws sts get-caller-identity|jq -r .Account)
tmpfile=$(mktemp)
# =====================================================
echo siem test
for testfile in siem_*.json ;do
  date=$(TZ=JST-9 date)
  json=$(eval echo $(cat ${testfile}| sed 's/\\/\\\\"/g'| sed 's/"/\\"/g'| tr -d "\n"))
  echo test ${testfile}
  echo DATE: ${date}
  echo -input json------------------------
  echo ${json}
  echo -cmd------------------------
  json64=$(echo ${json}|base64|tr -d "\n")
  ${test01} --payload "${json64}" "${tmpfile}"
  echo -outfile------------------------
  cat "${tmpfile}"
  echo
  echo ========================================
  read -p "next test?" tmp
done
