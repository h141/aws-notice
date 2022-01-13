Require
    git
    jq
    aws (version 2)



"# aws-notice"
install/update 
bash <(curl -s -o- https://raw.githubusercontent.com/h141/aws-notice/main/auto-setup.sh)

test
bash <(curl -s -o- https://raw.githubusercontent.com/h141/aws-notice/main/auto-setup.sh) --test
