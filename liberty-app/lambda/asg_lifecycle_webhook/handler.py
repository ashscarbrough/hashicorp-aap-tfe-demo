import json
import os
import urllib.request
import urllib.error
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

AAP_HOSTNAME  = os.environ["AAP_HOSTNAME"]
AAP_TOKEN     = os.environ["AAP_TOKEN"]
JOB_TEMPLATE_ID = os.environ["AAP_JOB_TEMPLATE_ID"]
INVENTORY_ID  = os.environ["AAP_INVENTORY_ID"]
AWS_REGION    = os.environ.get("AWS_REGION", "us-east-1")


def lambda_handler(event, context):
    logger.info("Received ASG lifecycle event")
    logger.info(json.dumps(event))

    # ── Extract instance ID from the lifecycle event ──────────────────────────
    # EventBridge ASG lifecycle events nest the detail differently depending
    # on whether this is a lifecycle hook event or an EC2 launch event
    detail = event.get("detail", {})

    instance_id = (
        detail.get("EC2InstanceId")          # lifecycle hook event
        or detail.get("instance-id")         # EC2 state change event
        or detail.get("instanceId")          # some EventBridge formats
    )

    if not instance_id:
        logger.error("Could not extract instance ID from event")
        logger.error(json.dumps(event))
        return {"statusCode": 400, "body": "No instance ID found in event"}

    logger.info(f"Target instance: {instance_id}")

    # ── Lifecycle hook details (if present) ───────────────────────────────────
    # Used to send CONTINUE signal back to ASG after AAP job completes
    lifecycle_hook_name   = detail.get("LifecycleHookName")
    asg_name              = detail.get("AutoScalingGroupName")
    lifecycle_action_token = detail.get("LifecycleActionToken")

# Wait for SSM registration before triggering AAP
    logger.info(f"Waiting for SSM registration on {instance_id}...")
    if not wait_for_ssm(instance_id):
        logger.error("SSM registration timeout -- sending ABANDON")
        if lifecycle_hook_name and asg_name and lifecycle_action_token:
            send_lifecycle_action(
                asg_name, lifecycle_hook_name,
                instance_id, lifecycle_action_token,
                action="ABANDON"
            )
        return {"statusCode": 500, "body": "SSM registration timeout"}

    # ── Trigger AAP job template ──────────────────────────────────────────────
    try:
        run_id = trigger_aap_job(instance_id)
        logger.info(f"AAP job triggered successfully: {run_id}")
    except Exception as e:
        logger.error(f"Failed to trigger AAP job: {e}")
        # Send ABANDON if we have lifecycle hook details so ASG terminates
        # the instance rather than leaving it stuck in Pending:Wait
        if lifecycle_hook_name and asg_name and lifecycle_action_token:
            send_lifecycle_action(
                asg_name, lifecycle_hook_name,
                instance_id, lifecycle_action_token,
                action="ABANDON"
            )
        return {"statusCode": 500, "body": f"Failed to trigger AAP job: {e}"}

    # ── Poll AAP job until complete ───────────────────────────────────────────
    try:
        success = poll_aap_job(run_id)
    except Exception as e:
        logger.error(f"Error polling AAP job {run_id}: {e}")
        success = False

    # ── Send lifecycle action back to ASG ─────────────────────────────────────
    if lifecycle_hook_name and asg_name and lifecycle_action_token:
        action = "CONTINUE" if success else "ABANDON"
        logger.info(f"Sending lifecycle action: {action}")
        try:
            send_lifecycle_action(
                asg_name, lifecycle_hook_name,
                instance_id, lifecycle_action_token,
                action=action
            )
        except Exception as e:
            logger.error(f"Failed to send lifecycle action: {e}")

    if success:
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "AAP runtime config job completed successfully",
                "instance_id": instance_id,
                "job_id": run_id
            })
        }
    else:
        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": "AAP runtime config job failed",
                "instance_id": instance_id,
                "job_id": run_id
            })
        }


def trigger_aap_job(instance_id):
    payload = json.dumps({
        "inventory": int(os.environ["AAP_INVENTORY_ID"]),
        "extra_vars": json.dumps({
            "ssm_instance_id":            instance_id,
            "aws_region":                 os.environ.get("AWS_REGION", "us-east-1"),
            "ansible_python_interpreter": "/usr/bin/python3",
            "liberty_server_name":        "liberty-app"
        })
    }).encode("utf-8")

    req = urllib.request.Request(
        url=f"{AAP_HOSTNAME}/api/controller/v2/job_templates/{JOB_TEMPLATE_ID}/launch/",
        data=payload,
        headers={
            "Authorization": f"Bearer {AAP_TOKEN}",
            "Content-Type":  "application/json"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            job_id = body.get("id")
            if not job_id:
                raise ValueError(f"No job ID in AAP response: {body}")
            logger.info(f"AAP job launched with ID: {job_id}")
            return job_id
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        logger.error(f"AAP API error {e.code}: {error_body}")
        raise


def poll_aap_job(job_id, max_attempts=40, interval=15):
    """Poll AAP job status until complete. 40 x 15s = 10 minute max."""
    import time

    for attempt in range(1, max_attempts + 1):
        req = urllib.request.Request(
            url=f"{AAP_HOSTNAME}/api/controller/v2/jobs/{job_id}/",
            headers={
                "Authorization": f"Bearer {AAP_TOKEN}",
                "Content-Type":  "application/json"
            },
            method="GET"
        )

        try:
            with urllib.request.urlopen(req) as resp:
                body = json.loads(resp.read().decode("utf-8"))
                status = body.get("status", "unknown")
                logger.info(f"Attempt {attempt}/{max_attempts} — AAP job {job_id} status: {status}")

                if status == "successful":
                    logger.info(f"AAP job {job_id} completed successfully")
                    return True
                elif status in ("failed", "error", "canceled"):
                    logger.error(f"AAP job {job_id} ended with status: {status}")
                    return False
                # pending / waiting / running -- keep polling

        except urllib.error.HTTPError as e:
            logger.warning(f"HTTP error polling job {job_id}: {e.code} -- retrying")

        time.sleep(interval)

    logger.error(f"AAP job {job_id} did not complete within timeout")
    return False


def send_lifecycle_action(asg_name, hook_name, instance_id, action_token, action):
    """Send CONTINUE or ABANDON back to the ASG lifecycle hook via AWS API."""
    import urllib.parse

    # Use boto3 if available (Lambda has it), otherwise fall back to urllib
    try:
        import boto3
        client = boto3.client("autoscaling", region_name=AWS_REGION)
        client.complete_lifecycle_action(
            LifecycleHookName=hook_name,
            AutoScalingGroupName=asg_name,
            LifecycleActionToken=action_token,
            LifecycleActionResult=action,
            InstanceId=instance_id
        )
        logger.info(f"Lifecycle action {action} sent for instance {instance_id}")
    except Exception as e:
        logger.error(f"Failed to complete lifecycle action: {e}")
        raise

def wait_for_ssm(instance_id, max_attempts=20, interval=15):
    """Wait for instance to register with SSM before triggering AAP."""
    import boto3, time
    ssm = boto3.client("ssm", region_name=os.environ.get("AWS_REGION", "us-east-1"))
    
    for attempt in range(1, max_attempts + 1):
        try:
            resp = ssm.describe_instance_information(
                Filters=[{"Key": "InstanceIds", "Values": [instance_id]}]
            )
            instances = resp.get("InstanceInformationList", [])
            if instances and instances[0].get("PingStatus") == "Online":
                logger.info(f"Instance {instance_id} is SSM-Online after {attempt} attempts")
                return True
        except Exception as e:
            logger.warning(f"SSM check attempt {attempt} error: {e}")
        
        logger.info(f"SSM wait attempt {attempt}/{max_attempts} — not yet online")
        time.sleep(interval)
    
    logger.error(f"Instance {instance_id} did not register with SSM within timeout")
    return False