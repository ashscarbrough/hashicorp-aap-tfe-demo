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

    workspace_id = os.environ["TFE_WORKSPACE_ID"]
    tfe_token    = os.environ["TFE_TOKEN"]
    tfe_url      = "https://app.terraform.io"

    # Parse the incoming HCP Packer event
    try:
        body = json.loads(event.get("body", "{}"))
        event_action = body.get("event", {}).get("action", "unknown")
        logger.info(f"HCP Packer event action: {event_action}")
    except Exception as e:
        logger.warning(f"Could not parse body: {e}")
        body = {}

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