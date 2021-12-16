TESTDIR=$(cd $(dirname $0); pwd)
cd ${TESTDIR}
# --
test01="aws lambda invoke --function-name shub-siem2securityhub-func"
cd ${TESTDIR}
SNSNAME=$(aws ssm get-parameter --name SNS_default | jq -r .Parameter.Value)
AWSID=$(aws sts get-caller-identity|jq -r .Account)
tmpfile=$(mktemp)
echo siem test
for testfile in siem_*.json ;do
  json=$(cat ${testfile}|sed 's/${AWSID}/'${AWSID}'/g'|sed 's/${SNSNAME}/'${SNSNAME}'/g')
  echo test ${testfile}
  echo -input json------------------------
  echo ${json}
  echo -cmd------------------------
  json64=$(echo ${json}|base64|tr -d "\n")
  ${test01} --payload "${json}" "${tmpfile}"
  echo -outfile------------------------
  cat "${tmpfile}"
  echo
  echo -------------------------
  read -p "next test?" tmp
done
