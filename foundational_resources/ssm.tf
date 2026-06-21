# --- SSM Session Manager preferences document ---
# This is an account-level document — applies to all SSM sessions in the region.
# Tells SSM where to ship session transcripts.
resource "aws_ssm_document" "session_manager_prefs" {
  name            = "SSM-SessionManagerRunShell"  # this exact name is required
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session Manager preferences — log to S3 and CloudWatch"
    sessionType   = "Standard_Stream"
    inputs = {
      s3BucketName                = var.ssm_s3_bucket_storage
      s3KeyPrefix                 = "session-logs"
      s3EncryptionEnabled         = true
      cloudWatchLogGroupName      = "/ssm/session-logs"
      cloudWatchEncryptionEnabled = false
      cloudWatchStreamingEnabled  = true   # streams live during session
      idleSessionTimeout          = "60"
      runAsEnabled                = false
      shellProfile = {
        linux = "exec > >(tee /var/log/ssm-session.log) 2>&1"
      }
    }
  })
}
