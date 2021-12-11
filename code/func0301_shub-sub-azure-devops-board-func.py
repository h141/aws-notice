import sys
import os

## --- Azure DevOps SDK --- ##
from azure.devops.connection import Connection
from msrest.authentication import BasicAuthentication
from azure.devops.v6_0.work_item_tracking.models import JsonPatchOperation
from azure.devops.v6_0.dashboard.models import TeamContext

# const
MESSAGE_PATH_DICT = {
    'task': "/fields/System.Description",
    'bug': "/fields/Microsoft.VSTS.TCM.SystemInfo"
}
DEFAULT_TYPE = 'bug'
DEFAULT_TAGS = 'aws; alarm;'


def lambda_handler(event, context):
    print("-event---------------------")
    print(event)
    print("-context---------------------")
    print(context)
    print("-START---------------------")
    fnc_exception = None
    # env context
    env_pat = os.environ.get( 'PAT', '' )
    env_organization = os.environ.get( 'ORGANIZATION', '' )
    # event
    accountname = event.get('accountname','-')
    adb_params = event['adb_params']    # Mandatory Check
    time = event.get('time','')
    finding = event[ 'finding' ]                  # Mandatory Check
    # ---
    default_title = f"AWS Security Alert ({accountname})"
    # ssm json param (mandatory)
    ssm_adb_project = adb_params[ 'project' ]        # Mandatory Check
    ssm_adb_team = adb_params[ 'team' ]              # Mandatory Check
    # ssm json param (optional)
    ssm_adb_title = adb_params.get( 'title',default_title )
    ssm_adb_type = adb_params.get( 'type', DEFAULT_TYPE )
    ssm_adb_tags = adb_params.get( 'tags', DEFAULT_TAGS )
    ssm_adb_parentid = adb_params.get( 'parentid' )
    # ---
    # connect to Azure DevOps Board Site
    organization_url = f'https://dev.azure.com/{env_organization}'
    credentials = BasicAuthentication( '', env_pat )
    connection = Connection( base_url=organization_url, creds=credentials )
    work_client = connection.clients.get_work_client()
    wit_client = connection.clients.get_work_item_tracking_client()
    # ---
    # main
    aws_accountid = finding.get('AwsAccountId','')
    title = f"{ssm_adb_title}_{aws_accountid}"
    ## ---------------------------------------
    current_iterationpath = get_current_iterationpath( work_client, ssm_adb_project, ssm_adb_team )
    message_path = MESSAGE_PATH_DICT[ ssm_adb_type ]  # Mandatory Check
    message_txt = parse_finding( accountname, time, finding )
    message_txt = message_txt.replace( "\n", "<br>" )
    relation_dict = get_relation_dict( wit_client, ssm_adb_parentid )
    ## ---------------------------------------
    print( f"/fields/System.Title  title: {title}" )
    print( f"fields/System.Tags  ssm_adb_tags: {ssm_adb_tags}" )
    print( f"/fields/System.IterationPath  current_iterationpath: {current_iterationpath}" )
    print( f"{message_path}  message_txt: {message_txt}" )
    jpo_documents = [
        JsonPatchOperation( from_=None, op="add", path="/fields/System.Title", value=title ),
        JsonPatchOperation( from_=None, op="add", path="/fields/System.Tags", value=ssm_adb_tags ),
        JsonPatchOperation( from_=None, op="add", path="/fields/System.IterationPath", value=current_iterationpath ),
        JsonPatchOperation( from_=None, op="add", path=message_path, value=message_txt )
    ]
    if relation_dict :
        print( f"/relations/- relation_dict: {relation_dict}" )
        jpo_documents.append( JsonPatchOperation( from_=None, op="add", path="/relations/-", value=relation_dict ) )
    ## ---------------------------------------
    wit_client.create_work_item( project = ssm_adb_project,  type = ssm_adb_type, document = jpo_documents )
    ## ---------------------------------------
    if fnc_exception :
        print( "-exception---------------------" )
        print( fnc_exception )
        raise fnc_exception
    return


def get_current_iterationpath( work_client, project, team ):
    team_context = TeamContext( project=project, team=team )
    [ current_iteration ] = work_client.get_team_iterations( team_context, timeframe="Current")
    return current_iteration.path

def get_relation_dict( wit_client, parentid ):
    if not parentid :
        return None
    else:
        relation_types = wit_client.get_relation_types()
        for relation_type in relation_types :
            if relation_type.name.lower() == 'parent':
                parent_reference_name = relation_type.reference_name
        # --end for ---------
        parent_work_item_url = wit_client.get_work_item( parentid ).url
        return  { 'rel': parent_reference_name, 'url': parent_work_item_url }

def parse_finding( accountname, time, finding ):
    productname = finding.get('ProductFields',{}).get('aws/securityhub/ProductName','')
    severitylevel = finding.get('Severity',{}).get('Label','')
    awsaccountid = finding.get('AwsAccountId','')
    title = finding.get('Title','')
    description = finding.get('Description','')
    resources = finding.get('Resources',[])
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
    return "\n".join(texts)
