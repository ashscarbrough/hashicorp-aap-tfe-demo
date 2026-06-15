import json
import os
import urllib.request
import boto3

def lambda_handler(event, context):
    aap_host    = os.environ["AAP_HOST"]
    aap_token   = os.environ["AAP_TOKEN"]
    template_id = os.environ["AAP_JOB_TEMPLATE_ID"]
    inventory_source_id = os.environ["AAP_INVENTORY_SOURCE_ID"]

    # Get the new instance details from the event
    instance_id = event["detail"]["EC2InstanceId"]
    asg_name    = event["detail"]["AutoScalingGroupName"]
    lifecycle_token = event["detail"]["LifecycleActionToken"]
    lifecycle_hook  = event["detail"]["LifecycleHookName"]

    print(f"New instance launched: {instance_id} in ASG: {asg_name}")

    # Get instance public IP from EC2 API
    ec2 = boto3.client("ec2", region_name=os.environ["AWS_REGION"])
    response = ec2.describe_instances(InstanceIds=[instance_id])
    public_ip = response["Reservations"][0]["Instances"][0].get(
        "PublicIpAddress", ""
    )

    # Trigger AAP inventory sync first
    sync_payload = json.dumps({}).encode("utf-8")
    sync_req = urllib.request.Request(
        url=f"{aap_host}/api/controller/v2/inventory_sources/{inventory_source_id}/update/",
        data=sync_payload,
        headers={
            "Authorization": f"Bearer {aap_token}",
            "Content-Type": "application/json"
        },
        method="POST"
    )

    with urllib.request.urlopen(sync_req) as sync_resp:
        sync_data = json.loads(sync_resp.read().decode("utf-8"))
        print(f"Inventory sync started: {sync_data.get('id')}")

    # Trigger AAP job
    job_payload = json.dumps({
        "extra_vars": json.dumps({
            "target_host": public_ip,
            "instance_id": instance_id
        })
    }).encode("utf-8")

    job_req = urllib.request.Request(
        url=f"{aap_host}/api/controller/v2/job_templates/{template_id}/launch/",
        data=job_payload,
        headers={
            "Authorization": f"Bearer {aap_token}",
            "Content-Type": "application/json"
        },
        method="POST"
    )

    with urllib.request.urlopen(job_req) as job_resp:
        job_data = json.loads(job_resp.read().decode("utf-8"))
        job_id = job_data.get("id")
        print(f"AAP job triggered: {job_id}")

    # Complete the lifecycle hook — allows instance to join ASG
    asg_client = boto3.client("autoscaling", region_name=os.environ["AWS_REGION"])
    asg_client.complete_lifecycle_action(
        LifecycleHookName=lifecycle_hook,
        AutoScalingGroupName=asg_name,
        LifecycleActionToken=lifecycle_token,
        LifecycleActionResult="CONTINUE"
    )

    return {"statusCode": 200, "body": f"AAP job {job_id} triggered for {instance_id}"}