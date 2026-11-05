variable "region" {
  default = "ap-southeast-2"
}

variable "cognito_domain_prefix" {
  description = "Prefix for the Cognito hosted UI domain (must be globally unique)"
  default     = "magento-admin"
}

variable "callback_urls" {
  description = "Allowed callback URLs for the app client"
  type        = list(string)
  default     = ["http://localhost/admin/adminsso/callback"]
}

variable "kb_bucket" {
  description = "S3 bucket for Bedrock knowledge base"
  default     = "magento-kb"
}

variable "search_table" {
  description = "DynamoDB table for search query logs"
  default     = "magento-search-logs"
}

variable "lambda_zip" {
  description = "Path to the Lambda deployment zip"
  default     = "./lambda/lambda.zip"
}
