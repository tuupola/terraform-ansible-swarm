variable "linode_token" {
  description = "Linode personal access token"
  type        = string
  sensitive   = true
}

variable "authorized_keys" {
  description = "Authorized SSH public keys"
  type        = list(string)
  sensitive   = true
}

variable "root_pass" {
  description = "Initial root password"
  type        = string
  sensitive   = true
}