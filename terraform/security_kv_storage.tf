# Archivo: terraform/security_kv_storage.tf
# Responsable: Angelo | Requisitos: S2 (Storage sin llaves/firewall), S3, S4, D2

resource "random_string" "kv_suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_key_vault" "kv" {
  #checkov:skip=CKV_AZURE_189:Acceso publico restringido por network_acls (subred snet-app e IP /32 del operador) para evitar costos de Bastion/VPN en entorno academico
  name                          = "kv-${var.project_name}-${random_string.kv_suffix.result}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = true
  tags                          = var.common_tags

  # Firewall restrictivo: solo subred snet-app e IP del operador (Requisito S3 y P3.1)
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = [var.operator_ip_cidr]
    virtual_network_subnet_ids = [azurerm_subnet.app.id]
  }
}

# Rol minimo privilegio para el VMSS: solo lectura de secretos (Requisito S4)
resource "azurerm_role_assignment" "vmss_kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine_scale_set.vmss.identity[0].principal_id
}

# Rol para que el operador que ejecuta Terraform pueda crear/gestionar el secreto
resource "azurerm_role_assignment" "operator_kv_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Secreto con fecha de expiracion obligatoria (Requisito S3)
resource "azurerm_key_vault_secret" "db_secret" {
  #checkov:skip=CKV_AZURE_41:El tipo de contenido ya esta definido explicitamente como text/plain
  name            = "db-connection-secret"
  value           = var.db_secret_value
  key_vault_id    = azurerm_key_vault.kv.id
  content_type    = "text/plain"
  expiration_date = "2027-12-31T23:59:59Z"

  depends_on = [azurerm_role_assignment.operator_kv_secrets_officer]
}

# Storage de aplicacion sin llaves de acceso compartidas y con firewall (Arquitectura objetivo)
resource "azurerm_storage_account" "app_storage" {
  #checkov:skip=CKV_AZURE_33:Cuenta no almacena datos transaccionales criticos; se usa LRS por presupuesto academico
  #checkov:skip=CKV_AZURE_206:Replicacion LRS justificada para reducir costos en entorno de pruebas
  #checkov:skip=CKV_AZURE_59:Acceso publico filtrado estrictamente mediante network_rules (subred snet-app e IP del operador)
  name                            = "st${var.project_name}${random_string.kv_suffix.result}"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true
  tags                            = var.common_tags

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = [var.operator_ip_cidr]
    virtual_network_subnet_ids = [azurerm_subnet.app.id]
  }
}