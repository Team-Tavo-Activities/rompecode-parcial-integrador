resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                            = "vmss-${var.project_name}-app"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  sku                             = var.vmss_sku
  instances                       = 2
  zones                           = var.vmss_zones
  zone_balance                    = false
  overprovision                   = false
  admin_username                  = "azureuser"
  disable_password_authentication = true
  upgrade_mode                    = "Manual"
  custom_data                     = base64encode(templatefile("${path.module}/../app/cloud-init.yaml", { key_vault_name = azurerm_key_vault.kv.name }))
  health_probe_id                 = azurerm_lb_probe.app.id
  identity {
    type = "SystemAssigned"
  }
  admin_ssh_key {
    username   = "azureuser"
    public_key = var.vmss_admin_public_key
  }
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT10M"
    action       = "Replace"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  os_disk {
    storage_account_type = "StandardSSD_LRS"
    caching              = "ReadWrite"
  }
  network_interface {
    name    = "nic-app"
    primary = true
    ip_configuration {
      name                                   = "ip-app"
      primary                                = true
      subnet_id                              = azurerm_subnet.app.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.app.id]
    }
  }
  tags = var.common_tags
  lifecycle {
    ignore_changes = [instances]
  }
  depends_on = [
    azurerm_subnet_network_security_group_association.app,
    azurerm_lb_outbound_rule.agent
  ]
}

variable "vmss_admin_public_key" {
  description = "Public SSH key required by Azure. The NSG denies inbound SSH."
  type        = string
}

variable "vmss_sku" {
  description = "Linux VM SKU available in the chosen region and zones."
  type        = string
  default     = "Standard_B2as_v2"
}

variable "vmss_zones" {
  description = "Availability zones supported by the deployment region and SKU."
  type        = list(string)
  default     = ["2", "3"]

  validation {
    condition     = length(distinct(var.vmss_zones)) >= 2 && alltrue([for zone in var.vmss_zones : contains(["1", "2", "3"], zone)])
    error_message = "Use at least two distinct supported availability zones."
  }
}

variable "vmss_calibration_mode" {
  description = "Temporarily pins the scale set to one VM during the P1 capacity baseline."
  type        = bool
  default     = false
}

resource "azurerm_monitor_autoscale_setting" "app" {
  name                = "autoscale-${var.project_name}-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vmss.id
  tags                = var.common_tags

  profile {
    name = var.vmss_calibration_mode ? "one-instance" : "normal"

    capacity {
      minimum = var.vmss_calibration_mode ? 1 : 2
      default = var.vmss_calibration_mode ? 1 : 2
      maximum = var.vmss_calibration_mode ? 1 : 3
    }

    dynamic "rule" {
      for_each = var.vmss_calibration_mode ? {} : {
        Increase = { operator = "GreaterThan", threshold = 55 }
        Decrease = { operator = "LessThan", threshold = 25 }
      }

      content {
        metric_trigger {
          metric_name        = "Percentage CPU"
          metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
          time_grain         = "PT1M"
          statistic          = "Average"
          time_window        = "PT5M"
          time_aggregation   = "Average"
          operator           = rule.value.operator
          threshold          = rule.value.threshold
        }

        scale_action {
          direction = rule.key
          type      = "ChangeCount"
          value     = 1
          cooldown  = "PT5M"
        }
      }
    }
  }
}