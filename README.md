# collie-stack
This is a terraform module to deploy the Collie search engine.

## Deploy

```terraform
module "collie_search" {
  source = "git@github.com:shawnrushefsky/collie-stack"

  stack_name = "collie"
}

output "endpoint" {
  value = module.collie_search.endpoint
}
```