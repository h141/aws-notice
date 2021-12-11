import os
import sys
import json
import boto3

# boto3 client
connect_client = boto3.client('connect')

def lambda_handler(event, context):
    print("-event---------------------")
    print(event)
    print("-START-sub-----------------")
    fnc_exception = None
    # env context
    env_instanceid = os.environ.get( 'INSTANCEID' )
    env_queueid = os.environ.get( 'QUEUEID' )
    env_contactflowid = os.environ.get( 'CONTACTFLOWID' )
    env_sourcephonenumber = os.environ.get( 'SOURCEPHONENUMBER' )
    # event
    jp_message = event.get( 'jp_message', 'ダミーメッセージ' )
    en_message = event.get( 'en_message', 'dummy message' )
    phonesets = event[ 'phonesets' ]     # Mandatory Check
    calltimes   = event[ 'calltimes' ]    # Mandatory Check
    waitseconds = event[ 'waitseconds' ]    # Mandatory Check
    # --- for (phonesets) ---
    new_phonesets=[]
    for phoneset in phonesets :
        try:
            phonenumber = phoneset.get('phonenumber','')
            if env_sourcephonenumber :
                responce = connect_client.start_outbound_voice_contact(
                    DestinationPhoneNumber = phonenumber,
                    InstanceId = env_instanceid,
                    QueueId = env_queueid,
                    ContactFlowId = env_contactflowid,
                    SourcePhoneNumber = env_sourcephonenumber,
                    Attributes = {
                        'jp_message': jp_message,
                        'en_message': en_message,
                        'isAccepted': "fales"
                    }
                )
            else :
                responce = connect_client.start_outbound_voice_contact(
                    DestinationPhoneNumber = phonenumber,
                    InstanceId = env_instanceid,
                    QueueId = env_queueid,
                    ContactFlowId = env_contactflowid,
                    Attributes = {
                        'jp_message': jp_message,
                        'en_message': en_message,
                        'isAccepted': "fales"
                    }
                )
            contactid = responce.get( 'ContactId' )
            new_phonesets.append( {
                'phonenumber': phonenumber,
                'contactid': contactid
            })
        except Exception as e :
            print( e , file=sys.stderr )
            fnc_exception = e
    # --- end for (phonesets) ---
    if fnc_exception :
        print( "-exception---------------------" )
        print( fnc_exception )
        raise fnc_exception
    return {
        'jp_message': jp_message,
        'en_message': en_message,
        'phonesets': new_phonesets,
        'calltimes': calltimes,
        'waitseconds': waitseconds,
        'instanceid': env_instanceid
    }
