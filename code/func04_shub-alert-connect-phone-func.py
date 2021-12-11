import os
import sys
import json
import boto3

# SSM parameter store KEY
SSM_KEY_PREFIX = 'CPN_'
SSM_KEY_BASE_DEFAULT = 'default'

# boto3 client
stepfunctions_client = boto3.client('stepfunctions')
ssm_client = boto3.client('ssm')

# Limit
MAX_CALLTIMES = 10
MAX_WAITSECONDS = 1200

def lambda_handler(event, context):
    print("-event---------------------")
    print(event)
    print("-context---------------------")
    print(context)
    print("-START---------------------")
    fnc_exception = None
    # env context
    env_region = os.environ.get( 'AWS_REGION' )
    env_statemachine = os.environ.get( 'STATEMACHINE' )
    env_calltimes = os.environ.get( 'CALLTIMES' )
    env_waitseconds = os.environ.get( 'WAITSECONDS' )
    jp_message = os.environ.get( 'MESSAGE' )
    # --
    cont_accountid = context.invoked_function_arn.split(':')[4];
    statemachinearn = f"arn:aws:states:{env_region}:{cont_accountid}:stateMachine:{env_statemachine}"
    calltimes = int( env_calltimes )
    waitseconds = int( env_waitseconds )
    # event
    findings = event.get('detail',{})[ 'findings' ]    # Mandatory Check
    # ----
    if calltimes > MAX_CALLTIMES :
        raise Exception( "Exception Env CALLTIMES over MAX_CALLTIMES" )
    if waitseconds > MAX_WAITSECONDS :
        raise Exception( "Exception Env WAITSECONDS over MAX_WAITSECONDS" )
    # --- for (findings) --- 
    for finding in findings :
        try:
            aws_accountid = finding.get('AwsAccountId')
            en_message =  finding.get('Title','')
            # ssm parameter store
            ssm_default_key = SSM_KEY_PREFIX + SSM_KEY_BASE_DEFAULT 
            ssm_account_key = '' if not aws_accountid else SSM_KEY_PREFIX + aws_accountid
            phonenumbers_text = ssm_get_value( ssm_default_key, ssm_account_key )
            # main
            if phonenumbers_text :
                phonenumbers = phonenumbers_text.split(',')
                phonesets = [ { 'phonenumber': pn, 'contactid': None }  for pn in phonenumbers ]
                sf_input_json = {
                    'jp_message': jp_message,
                    'en_message': en_message,
                    'phonesets': phonesets,
                    'calltimes': calltimes,
                    'waitseconds': waitseconds
                }
                stepfunction_input_text = json.dumps( sf_input_json )
                print( f"stepfunction_input_text: {stepfunction_input_text}" )
                response = stepfunctions_client.start_execution(
                    stateMachineArn = statemachinearn,
                    input = stepfunction_input_text
                )
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
