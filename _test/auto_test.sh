test01="aws lambda invoke --function-name shub-siem2securityhub-func"
cd $(dirname $0)
json=$(cat securityhub_01.json|tr -d "\n" )
${test01} --payload "'"${json}"'"