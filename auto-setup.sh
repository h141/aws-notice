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
# ------------
if [ ! -f "$HOME/_config.sh" ]; then
  cp $BASEDIR/_config.sh $HOME/_config.sh
  echo
  echo Edit $HOME/_config.sh And Restart this script 
  vi $HOME/_config.sh
  exit
fi
{ set +eu; } 2>/dev/null
# -------------------------------------
echo
echo START 00_connect.sh
. 00_connect.sh
echo END
echo
echo START 01_iam.sh
. 01_iam.sh
echo END
echo
echo START 02_network.sh
. 02_network.sh
echo END
echo
echo START 03_lambda.sh
. 03_lambda.sh
echo END
# -------------------------------------