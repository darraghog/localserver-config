variable "zone_id" {
  description = "Zone ID of thelearningcto.com (dashboard: zone Overview, right sidebar)."
  type        = string
}

variable "account_id" {
  description = "Cloudflare account ID. Access (Zero Trust) is account-scoped, not zone-scoped."
  type        = string
}

variable "domain" {
  description = "Apex hostname of the public site."
  type        = string
  default     = "thelearningcto.com"
}

variable "access_admin_policy_id" {
  description = "Id of the existing reusable Access policy that allows only the admin email(s) (\"Allow emails: 8/30/2026\"). Shared with the WARP app, so referenced, not managed."
  type        = string
  default     = "30721c31-6c52-4990-b940-1c1a5fb967bd"
}

variable "access_allowed_idps" {
  description = "Identity provider ids offered on the Access login page (Google and One-time PIN today)."
  type        = list(string)
  default     = ["e217c143-8f07-4644-9494-8562001bb354", "996003d6-29e1-4eac-af2b-78ffdeec736c"]
}

variable "access_session_duration" {
  description = "How long an Access login lasts."
  type        = string
  default     = "24h"
}

variable "waf_php_action" {
  description = "Action for the stray-.php rule. Use \"log\" first to watch for false positives, then \"block\"."
  type        = string
  default     = "block"

  validation {
    condition     = contains(["log", "block", "managed_challenge", "js_challenge", "challenge"], var.waf_php_action)
    error_message = "waf_php_action must be one of log, block, managed_challenge, js_challenge, challenge."
  }
}

variable "probe_egress_ips" {
  description = "Public egress IPs of beeblebox (the uptime probe). Each gets an IP Access Rule \"allow\". Dynamic on Verizon FIOS: re-apply when it changes."
  type        = list(string)
  default     = []
}
