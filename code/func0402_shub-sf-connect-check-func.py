import os
import sys
import json
import boto3

# boto3 client
connect_client = boto3.client('connect')

def lambda_handler(event, context):
    print("-event---------------------")
    print(event)
    fnc_exception = None
    # event
    jp_message = event.get('jp_message','')
    en_message = event.get('en_message','')
    phonesets = event[ 'phonesets' ]      # Mandatory Check
    calltimes = event[ 'calltimes' ]      # Mandatory Check
    waitseconds = event[ 'waitseconds' ]    # Mandatory Check
    instanceid = event[ 'instanceid' ]    # Mandatory Check
    # --- for (phonesets) ---
    new_phonesets=[]
    for phoneset in phonesets :
        try:
            contactid = phoneset.get('contactid','')
            attributes = connect_client.get_contact_attributes(
                InstanceId = instanceid,
                InitialContactId = contactid
            )
            isAccepted = attributes.get('Attributes',{}).get('isAccepted','')
            if isAccepted != 'true' :
                phoneset[ 'contactid' ] = None
                new_phonesets.append( phoneset )
        except Exception as e :
            print( e , file=sys.stderr )
            fnc_exception = e
    # --- end for (phonesets) ---
    calltimes = 0 if len( new_phonesets ) == 0 else int( calltimes ) - 1
    if fnc_exception :
        print( "-exception---------------------" )
        print( fnc_exception )
        raise fnc_exception
    return {
        'jp_message': jp_message,
        'en_message': en_message,
        "phonesets": new_phonesets,
        "calltimes": calltimes,
        'waitseconds': waitseconds
    }
