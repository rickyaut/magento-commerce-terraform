terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_cognito_user_pool" "magento" {
  name = "MAGENTO_USER_POOL"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_user_pool_domain" "magento" {
  domain       = var.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.magento.id
}

resource "aws_cognito_user_pool_client" "magento" {
  name         = "magento-admin"
  user_pool_id = aws_cognito_user_pool.magento.id

  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email"]
  supported_identity_providers         = ["COGNITO"]

  callback_urls = ["http://localhost/adminsso/callback"]

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}

# ── S3 bucket ─────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "kb" {
  bucket        = var.kb_bucket
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "kb" {
  bucket = aws_s3_bucket.kb.id
  versioning_configuration { status = "Enabled" }
}

# test/ folder placeholder
resource "aws_s3_object" "test_folder" {
  bucket  = aws_s3_bucket.kb.id
  key     = "test/"
  content = ""
}

# products/ folder placeholder
resource "aws_s3_object" "products_folder" {
  bucket  = aws_s3_bucket.kb.id
  key     = "products/"
  content = ""
}

# ── IAM role for Bedrock KB ───────────────────────────────────────────────────

resource "aws_iam_role" "kb" {
  name = "AmazonBedrockExecutionRoleForKnowledgeBase-magento"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "kb_s3" {
  role = aws_iam_role.kb.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.kb.arn
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.kb.arn}/*"
      },
    ]
  })
}

data "aws_caller_identity" "current" {}

# ── Bedrock Knowledge Base (MANAGED — no OpenSearch needed) ──────────────────

resource "aws_bedrockagent_knowledge_base" "products" {
  name     = "magento-products"
  role_arn = aws_iam_role.kb.arn

  knowledge_base_configuration {
    type = "MANAGED"
    managed_knowledge_base_configuration {
      embedding_model_type = "MANAGED"
    }
  }
}

resource "aws_bedrockagent_data_source" "products" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.products.id
  name              = "magento-products-s3"

  lifecycle {
    ignore_changes = [
      data_source_configuration[0].managed_knowledge_base_connector_configuration[0].connector_parameters,
      data_source_configuration[0].managed_knowledge_base_connector_configuration[0].media_extraction_configuration,
    ]
  }

  data_source_configuration {
    type = "MANAGED_KNOWLEDGE_BASE_CONNECTOR"
    managed_knowledge_base_connector_configuration {
      connector_parameters = jsonencode({
        type    = "S3"
        version = "1"
        aclEnabled = false
        connectionConfiguration = {
          bucketArn            = aws_s3_bucket.kb.arn
          bucketName           = aws_s3_bucket.kb.bucket
          bucketOwnerAccountId = data.aws_caller_identity.current.account_id
        }
        filterConfiguration = {
          inclusionPrefixes      = ["products/"]
          maxFileSizeInMegaBytes = "500"
        }
      })
      media_extraction_configuration {
        image_extraction_configuration {
          image_extraction_status = "DISABLED"
        }
      }
    }
  }
}

# ── DynamoDB (search query log) ───────────────────────────────────────────────

resource "aws_dynamodb_table" "search_logs" {
  name         = var.search_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
}

# ── IAM role for Lambda ───────────────────────────────────────────────────────

resource "aws_iam_role" "lambda_search" {
  name = "magento-search-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_search" {
  role = aws_iam_role.lambda_search.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.kb.arn, "${aws_s3_bucket.kb.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:Retrieve", "bedrock:RetrieveAndGenerate"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:StartIngestionJob", "bedrock:GetIngestionJob"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:Query", "dynamodb:GetItem"]
        Resource = aws_dynamodb_table.search_logs.arn
      },
    ]
  })
}

# ── Lambda function ───────────────────────────────────────────────────────────

resource "null_resource" "lambda_build" {
  triggers = {
    src_hash = sha256(join("", [for f in fileset("${path.module}/lambda", "*.py") : filesha256("${path.module}/lambda/${f}")]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      pip3 install -q --platform manylinux2014_x86_64 --only-binary=:all: \
        -r ${path.module}/lambda/requirements.txt -t ${path.module}/lambda/package
      cp ${path.module}/lambda/*.py ${path.module}/lambda/package/
      cd ${path.module}/lambda/package && zip -qr ${path.module}/lambda/lambda.zip .
      rm -rf ${path.module}/lambda/package
    EOT
  }
}

resource "aws_lambda_function" "search" {
  depends_on       = [null_resource.lambda_build]
  function_name    = "magento-product-search"
  filename         = var.lambda_zip
  source_code_hash = filebase64sha256(var.lambda_zip)
  role             = aws_iam_role.lambda_search.arn
  handler          = "app.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      REGION = var.region
      BUCKET = var.kb_bucket
      KB_ID  = aws_bedrockagent_knowledge_base.products.id
      DS_ID  = aws_bedrockagent_data_source.products.data_source_id
      TABLE  = var.search_table
    }
  }
}

resource "aws_lambda_function_url" "search" {
  function_name      = aws_lambda_function.search.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["content-type"]
  }
}
