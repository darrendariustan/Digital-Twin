# Production environment overrides
# No API key needed — Bedrock authenticates via the Lambda execution role's IAM permissions.

project_name = "twin"
environment  = "prod"

# Amazon Bedrock model for production
bedrock_model = "us.amazon.nova-lite-v1:0"

# Higher limits for production traffic
lambda_timeout           = 120
api_throttle_burst_limit = 50
api_throttle_rate_limit  = 25

# Set to true and provide root_domain if you have a custom domain in Route53
use_custom_domain = true
root_domain       = "darren-digitaltwin.click"
