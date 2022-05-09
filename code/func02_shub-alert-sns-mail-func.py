import sys
import os
import boto3
import json

# SSM parameter store KEY
SSM_KEY_PREFIX = 'SNS_'
SSM_KEY_BASE_DEFAULT = 'default'

# boto3 client
sns_client = boto3.client("sns")
ssm_client = boto3.client("ssm")

def lambda_handler(event, context):
    print("-event---------------------")
    print(event)
    print("-context---------------------")
    print(context)
    print("-START---------------------")
    fnc_exception = None
    # env context
    env_accountname = os.environ.get( 'ACCOUNTNAME', '-' )
    env_region = os.environ.get( 'AWS_REGION' )
    # -
    subject = f"AWS Security Alert ({env_accountname})"
    cont_accountid = context.invoked_function_arn.split(':')[4];
    # event
    findings = event.get('detail',{})[ 'findings' ]    # Mandatory Check
    time = event.get('time','')
    trigger_sns_topic_arn = event.get('SNSTopicArn','')
    # --- for (findings) --- 
    for finding in findings:
        try:
            aws_accountid = finding.get('AwsAccountId','')
            # ssm parameter store
            ssm_default_key = SSM_KEY_PREFIX + SSM_KEY_BASE_DEFAULT 
            ssm_account_key = None if not aws_accountid else SSM_KEY_PREFIX + aws_accountid
            sns_topic_name = ssm_get_value( ssm_default_key, ssm_account_key )
            # main
            if sns_topic_name :
                sns_topic_arn = f"arn:aws:sns:{env_region}:{cont_accountid}:{sns_topic_name}"
                if sns_topic_arn != trigger_sns_topic_arn :
                    message = parse_finding( env_accountname, time, finding )
                    sns_client.publish(
                        TopicArn=sns_topic_arn,
                        Subject= subject,
                        Message=message
                    )
                else :
                    print( f"SNS Loop on SSM {aws_accountid}" )
            else :
                print( f"SSM {aws_accountid} is disable." )
        except Exception as e :
            print( e , file=sys.stderr )
            fnc_exception = e
    # --- end for (findings) ---
    if fnc_exception :
        print( "-exception---------------------" )
        print( fnc_exception )
        raise fnc_exception
    return


def parse_finding( accountname, time, finding ):
    productname = finding.get('ProductFields',{}).get('aws/securityhub/ProductName','')
    severitylevel = finding.get('Severity',{}).get('Label','')
    awsaccountid = finding.get('AwsAccountId','')
    title = finding.get('Title','')
    description = finding.get('Description','')
    resources = finding.get('Resources',[])
    remdiation_txt = finding.get('Remediation',{}).get('Recommendation',{}).get('Text','')
    remdiation_url = finding.get('Remediation',{}).get('Recommendation',{}).get('Url','')
    # ---
    texts = [
        # Top
        f"■ AWS Security Alert ({accountname})",
        f"- Time :: {time}",
        f"",
        # Overvie
        f" ■ Finding  from {productname}",
        f" - Severity :: {severitylevel}",
        f" - Account ID :: {awsaccountid}",
        f" - Title :: {title}",
        f" - Resources (ARN) ::"
    ]
    # Resources
    for resource in resources:
        resourceid = resource.get('Id','')
        texts.append( f"    {resourceid}" )
    # Description
    texts.append( " - Description ::  -- " )
    texts.append( description )
    # Remediation Recommendation
    texts.append( " ■ Remediation Recommendation" )
    texts.append( remdiation_txt )
    texts.append( remdiation_url )
    return "\n".join(texts)

def ssm_get_value( ssm_default_key, ssm_account_key ):
    default_value = None
    account_value = None
    ssm_keys = [ ssm_default_key, ssm_account_key ] if ssm_account_key else [ ssm_default_key ]
    # get ssm parameter store
    response = ssm_client.get_parameters( Names = ssm_keys )
    # DEBUG
    if response[ 'InvalidParameters' ] :
        print( 'Info: InvalidParameters:' , response[ 'InvalidParameters' ] )
    params = response.get('Parameters',[])
    for param in params:
        if ( 'Name', ssm_default_key ) in  param.items() :
            default_value = param.get('Value')
        elif  ( 'Name', ssm_account_key ) in  param.items() :
            account_value = param.get('Value')
    # --- end for (params) ---
    if default_value is None :
        print( 'ERROR: SSM Parameter Store named ' , ssm_default_key , ' does not exist.' )
        raise  ValueError( "Default SSM Parameter  does not exist" )
    # ---
    account_value = account_value.strip() if account_value else default_value.strip() 
    if account_value == 'disable': account_value = None  
    return account_value
