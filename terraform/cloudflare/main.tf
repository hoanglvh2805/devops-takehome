terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token (placeholder for validate-only runs)"
  default     = "validate-only-token"
  sensitive   = true
}

variable "zone_id" {
  type        = string
  description = "Cloudflare zone ID for example.com"
  default     = "00000000000000000000000000000000"
}

variable "account_id" {
  type        = string
  description = "Cloudflare account ID"
  default     = "00000000000000000000000000000000"
}

import {
  to = cloudflare_dns_record.quote_api_legacy
  id = "${var.zone_id}/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}

resource "cloudflare_dns_record" "quote_api" {
  zone_id = var.zone_id
  name    = "quote-api"
  content = "origin.example.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = "Quote API — proxied through Cloudflare"
}

resource "cloudflare_dns_record" "quote_api_legacy" {
  zone_id = var.zone_id
  name    = "legacy-quote-api"
  content = "legacy-origin.example.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = "Manually created record adopted via import block"
}

resource "cloudflare_ruleset" "quote_api_cache" {
  zone_id     = var.zone_id
  name        = "quote_api_cache_rules"
  description = "Bypass cache for API paths; cache static assets aggressively"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules = [
    {
      action = "set_cache_settings"
      action_parameters = {
        cache = false
      }
      expression  = "(http.host eq \"quote-api.example.com\" and starts_with(http.request.uri.path, \"/api/\"))"
      description = "Bypass cache for /api/*"
      enabled     = true
      ref         = "bypass_api_cache"
    },
    {
      action = "set_cache_settings"
      action_parameters = {
        cache = true
        edge_ttl = {
          mode    = "override_origin"
          default = 86400
        }
        browser_ttl = {
          mode    = "override_origin"
          default = 3600
        }
      }
      expression  = "(http.host eq \"quote-api.example.com\" and http.request.uri.path matches \"^/(static|assets)/.*$\")"
      description = "Aggressive cache for static assets"
      enabled     = true
      ref         = "cache_static_assets"
    },
  ]
}
