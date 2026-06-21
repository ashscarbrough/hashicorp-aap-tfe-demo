import json
import os
import urllib.request
import urllib.error
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info("Received HCP Packer webhook payload")
    logger.info(json.dumps(event))

    workspace_id     = os.environ["TFE_WORKSPACE_ID"]
    tfe_token        = os.environ["TFE_TOKEN"]
    tfe_url          = "https://app.terraform.io"
    channel_filter   = os.environ.get("PACKER_CHANNEL_FILTER", "production")

    # Parse the incoming HCP Packer event
    try:
        body = json.loads(event.get("body", "{}"))
        event_action = body.get("event_action", "unknown")
        logger.info(f"HCP Packer event action: {event_action}")
    except Exception as e:
        logger.warning(f"Could not parse body: {e}")
        body = {}
        event_action = "unknown"

    # Extract channel name from event_payload.channel.name
    channel_name = body.get("event_payload", {}).get("channel", {}).get("name", "")
    logger.info(f"HCP Packer channel: '{channel_name}' (filter: '{channel_filter}')")

    # Only proceed for the configured channel
    if channel_name != channel_filter:
        logger.info(f"Skipping run — channel '{channel_name}' does not match filter '{channel_filter}'")
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": f"Skipped — channel '{channel_name}' is not '{channel_filter}'"
            })
        }

    # Build the HCP Terraform run payload
    run_payload = json.dumps({
        "data": {
            "attributes": {
                "message": f"Triggered by HCP Packer webhook — event: {event_action}",
                "auto-apply": True
            },
            "type": "runs",
            "relationships": {
                "workspace": {
                    "data": {
                        "type": "workspaces",
                        "id": workspace_id
                    }
                }
            }
        }
    }).encode("utf-8")

    # Trigger the HCP Terraform run
    req = urllib.request.Request(
        url=f"{tfe_url}/api/v2/runs",
        data=run_payload,
        headers={
            "Authorization": f"Bearer {tfe_token}",
            "Content-Type": "application/vnd.api+json"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req) as response:
            response_body = json.loads(response.read().decode("utf-8"))
            run_id = response_body.get("data", {}).get("id", "unknown")
            logger.info(f"Successfully triggered HCP Terraform run: {run_id}")

            return {
                "statusCode": 200,
                "body": json.dumps({
                    "message": "Terraform run triggered successfully",
                    "run_id": run_id
                })
            }

    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        logger.error(f"Failed to trigger Terraform run: {e.code} {error_body}")

        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": "Failed to trigger Terraform run",
                "error": error_body
            })
        }