#! /bin/bash
# bash <(curl -s -o- https://raw.githubusercontent.com/h141/aws-notice/main/auto-setup.sh)

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
{ set +eu; } 2>/dev/null
# ------------
if [ "$1" == "--test" ]; then
  sh "${BASEDIR}/_test/auto-test.sh"
  exit
fi
# ------------
set -eu
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