TESTDIR=$(cd $(dirname $0); pwd)
cd ${TESTDIR}
# --
test01="aws lambda invoke --function-name shub-siem2securityhub-func"
cd ${TESTDIR}
AWSID=$(aws sts get-caller-identity|jq -r .Account)
tmpfile=$(mktemp)
echo siem test
for testfile in siem_*.json ;do
  echo test ${testfile}
  echo -input json------------------------
  cat ${testfile}|sed 's/${AWSID}/'${AWSID}'/g'
  echo -cmd------------------------
  json=$(cat ${testfile}|sed 's/${AWSID}/'${AWSID}'/g'|base64|tr -d "\n")
  ${test01} --payload "${json}" "${tmpfile}"
  echo -outfile------------------------
  cat "${tmpfile}"
  echo
  echo -------------------------
  read -p "next test?" tmp
done
