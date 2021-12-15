BASEDIR="$HOME/aws-notice"
cd "$BASEDIR" || exit
git fetch >/dev/null 2>&1
git checkout main >/dev/null  2>&1
git pull --rebase >/dev/null 2>&1
# --
test01="aws lambda invoke --function-name shub-siem2securityhub-func"
cd $(dirname $0)
json=$(cat securityhub_01.json|tr -d '\r'|tr -d '\n')
${test01} --payload "'"${json}"'"