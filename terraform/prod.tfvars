# Production environment overrides
# openai_api_key is NOT set here — it is injected at deploy time via
# the OPENAI_API_KEY environment variable (GitHub Actions secret / local env).

project_name = "twin"
environment  = "prod"

# Use a more capable model in production
openai_model = "gpt-4o"

# Higher limits for production traffic
lambda_timeout           = 120
api_throttle_burst_limit = 50
api_throttle_rate_limit  = 25

# Set to true and provide root_domain if you have a custom domain in Route53
use_custom_domain = false
root_domain       = ""
