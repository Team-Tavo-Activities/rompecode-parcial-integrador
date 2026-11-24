variable "project_name" {
  description = "Nombre base del proyecto para estandarizar recursos"
  type        = string
  default     = "caribeshop"
}

variable "environment" {
  description = "Ambiente de despliegue (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Región principal de Azure"
  type        = string
  default     = "eastus2"
}

variable "admin_username" {
  description = "Usuario administrador SSH para las máquinas virtuales Linux"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "Llave pública SSH (id_ed25519.pub o id_rsa.pub) para acceso seguro"
  type        = string
  sensitive   = true
}

variable "my_public_ip" {
  description = "IP pública autorizada (formato CIDR /32) para administración SSH y Key Vault"
  type        = string
  sensitive   = true
}

variable "db_admin_username" {
  description = "Usuario administrador de PostgreSQL Flexible Server"
  type        = string
  default     = "caribeadmin"
}

variable "db_admin_password" {
  description = "Contraseña segura del administrador de PostgreSQL (se almacena en Key Vault)"
  type        = string
  sensitive   = true
}
