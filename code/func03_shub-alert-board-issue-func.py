import sys
import os
import boto3
import json

# SSM parameter store KEY
SSM_KEY_PREFIX = 'ADB_'
SSM_KEY_BASE_DEFAULT = 'default'

# boto3 client
ssm_client = boto3.client("ssm")
lambda_client = boto3.client("lambda")


def lambda_handler(event, context):
    print("-event---------------------")
    print(event)
    print("-context---------------------")
    print(context)
    print("-START---------------------")
    fnc_exception = None
    # env context
    env_accountname = os.environ.get( 'ACCOUNTNAME', '-' )
    env_adb_sub_fnc = os.environ.get( 'ADB_SUB_FNC' )
    # event
    findings = event.get('detail',{})[ 'findings' ]    # Mandatory Check
    time = event.get('time','')
    # --- for (findings) --- 
    for finding in findings :
        try:
            aws_accountid = finding.get('AwsAccountId','')
            # ssm parameter store
            ssm_default_key = SSM_KEY_PREFIX + SSM_KEY_BASE_DEFAULT 
            ssm_account_key = '' if not aws_accountid else SSM_KEY_PREFIX + aws_accountid
            adb_params_json_txt = ssm_get_value( ssm_default_key, ssm_account_key )
            # main
            if adb_params_json_txt :
                adb_params = json.loads( adb_params_json_txt )
                payload_aws_board_issue = {
                    'accountname': env_accountname,
                    'adb_params': adb_params,
                    'time': time,
                    'finding': finding
                }
                payloadtext = json.dumps( payload_aws_board_issue )
                print( f"payloadtext: {payloadtext}" )
                response = lambda_client.invoke(
                    FunctionName = env_adb_sub_fnc, 
                    InvocationType = 'Event', 
                    Payload = payloadtext )
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
