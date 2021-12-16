TESTDIR=$(cd $(dirname $0); pwd)
BASEDIR="$HOME/aws-notice"
cd "$BASEDIR" || exit
git fetch >/dev/null 2>&1
git checkout main >/dev/null  2>&1
git pull --rebase >/dev/null 2>&1
# --
test01="aws lambda invoke --function-name shub-siem2securityhub-func"

testname="siem_01"
cd ${TESTDIR}
json=$(cat ${testname}.json|tr -d '\r'|tr -d '\n')
echo ${test01} --payload "${json}" "$HOME/test_${testname}.log"

testname="siem_02"
cd ${TESTDIR}
json=$(cat ${testname}.json|tr -d '\r'|tr -d '\n')
echo ${test01} --payload "${json}" "$HOME/test_${testname}.log"