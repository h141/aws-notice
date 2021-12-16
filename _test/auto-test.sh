TESTDIR=$(cd $(dirname $0); pwd)
cd ${TESTDIR}
# --
test01="aws lambda invoke --function-name shub-siem2securityhub-func"
cd ${TESTDIR}

tmpfile=$(mktemp)
echo siem test
for testfile in siem_*.json ;do
  echo test ${testfile}
  echo -input json------------------------
  cat ${testfile}
  echo -cmd------------------------
  json=$(cat ${testfile}|base64|tr -d "\n")
  ${test01} --payload "${json}" "${tmpfile}"
  echo -outfile------------------------
  cat "${tmpfile}"
  echo -------------------------
  read -p "next test?" tmp
done