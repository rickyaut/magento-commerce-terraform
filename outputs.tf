output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.magento.id
}

output "cognito_domain" {
  value = "${aws_cognito_user_pool_domain.magento.domain}.auth.${var.region}.amazoncognito.com"
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.magento.id
}

output "cognito_client_secret" {
  value     = aws_cognito_user_pool_client.magento.client_secret
  sensitive = true
}

output "kb_id" {
  value = aws_bedrockagent_knowledge_base.products.id
}

output "ds_id" {
  value = aws_bedrockagent_data_source.products.data_source_id
}

output "lambda_url" {
  value = aws_lambda_function_url.search.function_url
}

output "kb_bucket" {
  value = aws_s3_bucket.kb.bucket
}
