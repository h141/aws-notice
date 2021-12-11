import sys
import os
import boto3
import json
import re

# 00:convert Keys in SIEM Mail Message
def handler( func, *args ):
    return func( *args )

def put_awsaccountid( fd, value ):
    fd['AwsAccountId'] = value
    return fd

def put_severity( fd, value ):
    severity_int=int(value)
    if severity_int >= 90 : 
        fd['Severity'] = { 'Label': 'CRITICAL' }
    elif severity_int >= 70 : 
        fd['Severity'] = { 'Label': 'HIGH' }
    elif severity_int >= 40 : 
        fd['Severity'] = { 'Label': 'MEDIUM' }
    elif severity_int >= 1 : 
        fd['Severity'] = { 'Label': 'LOW' }
    else : 
        fd['Severity'] = { 'Label': 'INFORMATIONAL' }
    return fd

def put_productname( fd, value ):
    fd['ProductFields'] = { 'aws/securityhub/ProductName': value }
    return fd

def put_resources( fd, value ):
    if not 'Resources' in fd :
        fd['Resources']=[]
    fd['Resources'].append({'Id': value})
    return fd
#
SIEM_KEY_FNC_DICT = {
    'AwsAccountId': put_awsaccountid,
    'Severity': put_severity,
    'ProductName': put_productname,
    'Resources': put_resources
}

# boto3 client
lambda_client = boto3.client("lambda")

NOTICE_LIST =[ 'SNS', 'ADB',  'CPN' ] 
def lambda_handler(event, context):
    print("-event---------------------")
    print(event)
    print("-context---------------------")
    print(context)
    print("-START---------------------")
    fnc_exception = None
    # ---
    # 00: convert
    sh_event = convert_event(event)
    print("convert RESULT :")
    print( sh_event )
    # 01: Lambda
    if sh_event:
        severity_label = sh_event['detail']['findings'][0]['Severity']['Label']    # Mandatory Check
        print( f"severity_label : {severity_label}" )
        payloadtext = json.dumps( sh_event )
        for notice in NOTICE_LIST :
            # env context
            env_fnc = os.environ[ f"{notice}_FNC" ]    # Mandatory Check 
            env_severity_labels = os.environ[ f"{notice}_SEVERITY" ].split(',') # Mandatory Check
            print( f"CHECK {notice} severity_label" )
            if severity_label in env_severity_labels :
                print( f"lambda function invoke ({env_fnc})" )
                try:
                    response = lambda_client.invoke(
                        FunctionName=env_fnc, 
                        InvocationType='Event', 
                        Payload= payloadtext )
                except Exception as e :
                    print( e , file=sys.stderr )
                    fnc_exception = e
        # --- end for (notice) ---
    else :
        print( "convert RESULT is None" )
    #  Exception
    if fnc_exception :
        print( "-exception---------------------" )
        print( fnc_exception )
        raise fnc_exception
    return

def convert_event(event):
    records = event.get( 'Records', [] )
    record_sns = records[0].get('Sns',{}) if records else {}
    #
    snsmessage = record_sns.get('Message','')
    snstitle = record_sns.get('Subject','')
    snstimestamp = record_sns.get('Timestamp','')
    snstopicarn = record_sns.get('TopicArn','')
    #
    siem_keys=SIEM_KEY_FNC_DICT.keys()
    finding = {
        'Title': snstitle,
        'Description': snsmessage,
        'Severity': { 'Label': 'INFORMATIONAL' }
    }
    for snsline in snsmessage.splitlines():
        m = re.match(r'^-(.+):(.+)$', snsline )
        if m :
            siem_key, value = m.groups()[0].strip(), m.groups()[1].strip()
        else :
            siem_key, value = '', ''
        if siem_key in siem_keys :
            handler( SIEM_KEY_FNC_DICT[siem_key], finding, value )
    # --- end for (snsline) ---
    securityhub_event = {
        'time': snstimestamp,
        'SNSTopicArn': snstopicarn,
        'detail': {
            'findings': [ finding ]
        }
    }
    return securityhub_event
