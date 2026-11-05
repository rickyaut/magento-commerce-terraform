# Magento Commerce Terraform

AWS infrastructure for the Magento AI platform — Cognito admin SSO, Bedrock Knowledge Base for semantic product search, and a Lambda search API.

## Architecture

```
Magento Admin ──save product──► Lambda /ingest ──► S3 (products/) ──► Bedrock KB sync
                                                                              │
Magento Storefront ──search──► Lambda /search ◄──── Bedrock KB retrieve ◄───┘
                                     │
                               DynamoDB (query log)
                                     │
Magento Admin ──────────────► Lambda /insights (word cloud, recent searches)
```

## Resources

| Resource | Name | Description |
|---|---|---|
| Cognito User Pool | `MAGENTO_USER_POOL` | Admin SSO |
| Cognito Domain | `magento-admin` | Hosted UI |
| S3 Bucket | `magento-kb` | Product document store |
| Bedrock Knowledge Base | `magento-products` | MANAGED KB with semantic search |
| Bedrock Data Source | `magento-products-s3` | S3 connector for KB |
| DynamoDB | `magento-search-logs` | Search query log |
| Lambda | `magento-product-search` | Search/ingest/insights API |
| Lambda URL | — | Public HTTPS endpoint |

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured (`ap-southeast-2`)
- Python 3 + pip3 (for Lambda build)
- AWS provider `~> 6.0`

## Deploy

```bash
terraform init
terraform apply
```

The Lambda zip is built automatically via `null_resource.lambda_build` when any `.py` file changes.

To build manually first:

```bash
pip3 install -r lambda/requirements.txt -t lambda/package
cp lambda/*.py lambda/package/
cd lambda/package && zip -r ../lambda.zip . && cd ../..
```

## Variables

| Variable | Default | Description |
|---|---|---|
| `region` | `ap-southeast-2` | AWS region |
| `cognito_domain_prefix` | `magento-admin` | Cognito hosted UI domain prefix (must be globally unique) |
| `kb_bucket` | `magento-kb` | S3 bucket name for the knowledge base |
| `search_table` | `magento-search-logs` | DynamoDB table name |
| `lambda_zip` | `./lambda/lambda.zip` | Path to Lambda deployment zip |

## Outputs

| Output | Description |
|---|---|
| `cognito_user_pool_id` | Cognito User Pool ID |
| `cognito_domain` | Full Cognito hosted UI domain |
| `cognito_client_id` | App client ID |
| `cognito_client_secret` | App client secret (sensitive) |
| `kb_id` | Bedrock Knowledge Base ID |
| `ds_id` | Bedrock Data Source ID |
| `kb_bucket` | S3 bucket name |
| `lambda_url` | Lambda function URL |

## Lambda API

Set `SEARCH_LAMBDA_URL` in Magento's `.env` to the `lambda_url` output value.

| Method | Path | Description |
|---|---|---|
| `POST` | `/ingest` | Ingest a product into S3 and trigger KB sync |
| `DELETE` | `/ingest` | Remove a product from S3 and trigger KB sync |
| `POST` | `/search` | Semantic product search via Bedrock KB |
| `GET` | `/insights/cloud` | Word cloud of top search terms |
| `GET` | `/insights/recent` | Recent search queries |

### Ingest payload

```json
{
  "sku": "24-MB01",
  "name": "Joust Duffle Bag",
  "price": "34.00",
  "status": "1",
  "description": "...",
  "short_description": "...",
  "url_key": "joust-duffle-bag",
  "image": "/m/b/mb01-blue-0.jpg",
  "categories": ["3", "4"]
}
```

### Search payload

```json
{ "query": "waterproof bag", "top_k": 10 }
```

## Magento integration

The `Oaklayton_ProductSearch` module in `magento-commerce-magento`:
- Fires `ProductSaveObserver` on product save → POST `/ingest`
- Fires `ProductDeleteObserver` on product delete → DELETE `/ingest`
- Intercepts storefront search → redirects to semantic search results page
- Admin menu: **Catalog → Search Insights**
