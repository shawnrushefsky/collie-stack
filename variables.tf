variable "stack_name" {
  default = "collie-search"
}

variable "index_cache_ttl" {
  default = 60
  description = "Max time in seconds that an index should stay cached for queries"
}