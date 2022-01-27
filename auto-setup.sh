#! /bin/bash
# bash <(curl -s -o- https://raw.githubusercontent.com/h141/aws-notice/main/auto-setup.sh)
opt1="$1"
# -------------------------------------
echo CHECK required
echo CHECK git
which git >/dev/null
if [ $? -ne 0 ]; then
  sudo yum install git -y
fi
echo CHECK jq
which jq >/dev/null
if [ $? -ne 0 ]; then
  sudo yum install jq -y
fi
echo CHECK aws version
aws --version | grep "^aws-cli/1\."
if [ $? -eq 0 ]; then
  sudo rm -rf /usr/local/aws
  sudo rm /usr/bin/aws
  sudo rm /usr/bin/aws_completer
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  hash -r
fi
echo SET environment variables for REGION
if [ -z ${AWS_REGION} ]; then
  read -p "Enter AWS_REGION [ap-northeast-1]:" region
  region="${region:=ap-northeast-1}"
  export AWS_REGION=${region}
  export AWS_DEFAULT_REGION=${region}
fi
echo cd HOMEDIR
cd ~
# -------------------------------------
PYTHONIOENCODING=UTF-8
set -eu
BASEDIR="$HOME/aws-notice"
cd $HOME || exit
if [ -d "$BASEDIR" ]; then
  echo "git rebase to get latest commit"
  cd "$BASEDIR" || exit
  git fetch >/dev/null 2>&1
  git checkout main >/dev/null  2>&1
  git pull --rebase >/dev/null 2>&1
else
  echo "git clone siem source code"
  git clone https://github.com/h141/aws-notice.git >/dev/null 2>&1
  cd "$BASEDIR" || exit
  git checkout main >/dev/null  2>&1
fi
# ------------
if [ "_${opt1}" == "_--test" ]; then
  sh "${BASEDIR}/_test/auto-test.sh" "$@"
  exit
fi
# ------------
conconf_path="$HOME/_config_04_lambda.sh"
if [ ! -f "$conconf_path" ]; then
  cp $BASEDIR/_config.sh "$conconf_path"
  vi "$conconf_path"
  exit
fi
{ set +eu; } 2>/dev/null
# -------------------------------------
echo
echo START 00_sns_infra_alert.sh
. 00_sns_infra_alert.sh
echo END
echo
echo START 00_create_vpc.sh
. 00_create_vpc.sh
echo END
echo
echo START 01_connect.sh
. 01_connect.sh
echo END
echo
echo START 02_iam.sh
. 02_iam.sh
echo END
echo
echo START 03_network.sh
. 03_network.sh
echo END
echo
echo START 04_lambda.sh
. 04_lambda.sh
echo END
# -------------------------------------