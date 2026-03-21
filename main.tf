# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

# VNet
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-k8s-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/8"]
}

# Subnet AKS
resource "azurerm_subnet" "aks" {
  name                 = "subnet-aks"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.0.0/16"]
}

# Subnet Private Endpoints
resource "azurerm_subnet" "private" {
  name                 = "subnet-private"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.3.0.0/16"]
}

# NSG
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-k8s-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Asociación NSG a AKS
resource "azurerm_subnet_network_security_group_association" "aks_nsg" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

##########################################
## CORRECTO HASTA AQUÍ#############
##########################################

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-lab"

  private_cluster_enabled = true

  default_node_pool {
    name           = "nodepool1"
    node_count     = 1
    vm_size        = "Standard_B2ps_v2"
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
  }

  role_based_access_control_enabled = true
}

###################################
##### CORRECTO HASTA AQUÍ"""""
###################################

resource "azurerm_container_registry" "acr" {
  name                = "carlos69lamejor"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

######################################
##### HASTA ACA TODO OK ""
######################################

resource "azurerm_api_management" "apim" {
  name                = "apim-lab-public"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "carlos69lamejor"
  publisher_email     = "admin@example.com"
  sku_name            = "Developer_1"  # developer para pruebas
} 

#### USAR ESTO CUANDO SOLO QUIERO QUE SEA PUBLICO ####

#########################################
######## TODO OK HASTA ACÁ##########
########################################

resource "azurerm_sql_server" "sql_server" {
  name                         = "sql-carlos69lm"
  resource_group_name           = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "azureuser"
  administrator_login_password = "ContraseñaSegura123!" # usar secreto real en producción
}

resource "azurerm_sql_database" "db_app2" {
  name                = "db-app2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  server_name         = azurerm_sql_server.sql_server.name

  requested_service_objective_name = "S0"
}



resource "azurerm_sql_firewall_rule" "aks_access" {
  name                = "AllowAKS"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_sql_server.sql_server.name
  start_ip_address    = "10.224.0.0"
  end_ip_address      = "10.224.255.255"
}

#############################################################
#######################HASTA ACA TODO FUNCIONA"###########
#########################################################

# #########################################
# # 1️⃣ Subnet y NSG para APIM interno
# #########################################

# resource "azurerm_network_security_group" "apim_nsg" {
#   name                = "apim-nsg"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
# }

# resource "azurerm_subnet" "apim_subnet" {
#   name                 = "apim-subnet"
#   resource_group_name  = azurerm_resource_group.rg.name
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   address_prefixes     = ["10.224.100.0/27"]
# }

# resource "azurerm_subnet_network_security_group_association" "apim_nsg_assoc" {
#   subnet_id                 = azurerm_subnet.apim_subnet.id
#   network_security_group_id = azurerm_network_security_group.apim_nsg.id
# }

# #########################################
# # 2️⃣ APIM Interno
# #########################################

# resource "azurerm_api_management" "apim" {
#   name                = "apim-lab-internal"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   publisher_name      = "carlos69lamejor"
#   publisher_email     = "admin@example.com"
#   sku_name            = "Developer_1"

#   virtual_network_type = "Internal"

#   virtual_network_configuration {
#     subnet_id = azurerm_subnet.apim_subnet.id
#   }
# }

# #########################################
# # 3️⃣ Private DNS interno para AKS
# #########################################

# resource "azurerm_private_dns_zone" "aks" {
#   name                = "aks.internal"
#   resource_group_name = azurerm_resource_group.rg.name
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
#   name                  = "dns-link"
#   resource_group_name   = azurerm_resource_group.rg.name
#   virtual_network_id    = azurerm_virtual_network.vnet.id
#   private_dns_zone_name = azurerm_private_dns_zone.aks.name
#   registration_enabled  = false
# }

# # NOTA: Los registros A deben apuntar a IPs válidas, no al private_fqdn de AKS
# # Opcional: usar el ClusterIP de los servicios de Kubernetes si quieres que APIM resuelva nombres internos

# resource "azurerm_private_dns_a_record" "app1" {
#   name                = "app1"
#   zone_name           = azurerm_private_dns_zone.aks.name
#   resource_group_name = azurerm_resource_group.rg.name
#   ttl                 = 300
#   records             = ["10.0.30.150"]  # ClusterIP de app1-service
# }

# resource "azurerm_private_dns_a_record" "app2" {
#   name                = "app2"
#   zone_name           = azurerm_private_dns_zone.aks.name
#   resource_group_name = azurerm_resource_group.rg.name
#   ttl                 = 300
#   records             = ["10.0.197.90"]  # ClusterIP de app2-service
# }

# #########################################
# # 4️⃣ APIM APIs para app1 y app2
# #########################################

# resource "azurerm_api_management_api" "app1" {
#   name                = "app1-api"
#   resource_group_name = azurerm_resource_group.rg.name
#   api_management_name = azurerm_api_management.apim.name
#   revision            = "1"
#   display_name        = "App1 API"
#   path                = "app1"
#   protocols            = ["https"]
#   service_url         = "http://app1.aks.internal:80"
# }

# resource "azurerm_api_management_api" "app2" {
#   name                = "app2-api"
#   resource_group_name = azurerm_resource_group.rg.name
#   api_management_name = azurerm_api_management.apim.name
#   revision            = "1"
#   display_name        = "App2 API"
#   path                = "app2"
#   protocols           = ["https"]
#   service_url         = "http://app2.aks.internal:80"
# }

