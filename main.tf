terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.72.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

#------------------begin azure configuration -----------#

resource "azurerm_resource_group" "az-waf-rg" {
  name     = "az-waf-rg0"
  location = "West Us"
}

resource "azurerm_network_security_group" "az-waf-nsg" {
  name                = "az-waf-nsg0"
  location            = azurerm_resource_group.az-waf-rg.location
  resource_group_name = azurerm_resource_group.az-waf-rg.name

  security_rule {
    name                       = "inbound-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "inbound-http"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "az-waf-vnet" {
  name                = "az-waf-vnet0"
  location            = azurerm_resource_group.az-waf-rg.location
  resource_group_name = azurerm_resource_group.az-waf-rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "az-waf-sub" {
  name                 = "az-waf-sub-0"
  resource_group_name  = azurerm_resource_group.az-waf-rg.name
  virtual_network_name = azurerm_virtual_network.az-waf-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "az-waf-sub-nsg-a" {
  subnet_id                 = azurerm_subnet.az-waf-sub.id
  network_security_group_id = azurerm_network_security_group.az-waf-nsg.id
}

#----------------------configuration for back-end machine 1---------------#

resource "azurerm_network_interface" "az-waf-net-int" {
  name                = "server-nic"
  location            = azurerm_resource_group.az-waf-rg.location
  resource_group_name = azurerm_resource_group.az-waf-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.az-waf-sub.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.200"
  }
}

resource "azurerm_network_interface_security_group_association" "az-waf-nsg-int-a" {
  network_interface_id      = azurerm_network_interface.az-waf-net-int.id
  network_security_group_id = azurerm_network_security_group.az-waf-nsg.id
}

resource "azurerm_linux_virtual_machine" "az-waf-vm" {
  name                = "az-waf-vm-1"
  resource_group_name = azurerm_resource_group.az-waf-rg.name
  location            = azurerm_resource_group.az-waf-rg.location
  size                = "Standard_B1s"
  admin_username      = "wildes"
  network_interface_ids = [
    azurerm_network_interface.az-waf-net-int.id,
  ]

  custom_data = filebase64("azure-user-data.sh")

  admin_ssh_key {
    username   = "wildes"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

#--------------------------configuration for back-end machine 2 ---------------#

resource "azurerm_network_interface" "az-waf-net-int-2" {
  name                = "server-nic2"
  location            = azurerm_resource_group.az-waf-rg.location
  resource_group_name = azurerm_resource_group.az-waf-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.az-waf-sub.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.201"
  }
}

resource "azurerm_network_interface_security_group_association" "az-waf-nsg-int-a-2" {
  network_interface_id      = azurerm_network_interface.az-waf-net-int-2.id
  network_security_group_id = azurerm_network_security_group.az-waf-nsg.id
}

resource "azurerm_linux_virtual_machine" "az-waf-vm-2" {
  name                = "az-waf-vm-2"
  resource_group_name = azurerm_resource_group.az-waf-rg.name
  location            = azurerm_resource_group.az-waf-rg.location
  size                = "Standard_B1s"
  admin_username      = "wildes"
  network_interface_ids = [
    azurerm_network_interface.az-waf-net-int-2.id,
  ]

  custom_data = filebase64("azure-user-data.sh")

  admin_ssh_key {
    username   = "wildes"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

#-----------------------Load balancer config--------------------------------#

resource "azurerm_public_ip" "az-waf-lb-pip" {
  name                = "az-waf-pip0"
  location            = azurerm_resource_group.az-waf-rg.location
  resource_group_name = azurerm_resource_group.az-waf-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "az-waf-lb" {
  name                = "az-waf-lb0"
  location            = azurerm_resource_group.az-waf-rg.location
  resource_group_name = azurerm_resource_group.az-waf-rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "front-end-public-ip"
    public_ip_address_id = azurerm_public_ip.az-waf-lb-pip.id
  }
  depends_on = [
    azurerm_public_ip.az-waf-lb-pip
  ]
}

#-------------------------lb rules----------------------------------#

resource "azurerm_lb_rule" "az-waf-lb-rule0" {
  loadbalancer_id                = azurerm_lb.az-waf-lb.id
  name                           = "ssh-lb-rule"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = "front-end-public-ip"
  probe_id                       = azurerm_lb_probe.az-waf-lb-probe-ssh.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.az-waf-lb-bap.id]
  depends_on = [
    azurerm_lb.az-waf-lb,
    azurerm_lb_probe.az-waf-lb-probe-ssh
  ]
}


resource "azurerm_lb_rule" "az-waf-lb-rule1" {
  loadbalancer_id                = azurerm_lb.az-waf-lb.id
  name                           = "http-lb-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  probe_id                       = azurerm_lb_probe.az-waf-lb-probe-http.id
  frontend_ip_configuration_name = "front-end-public-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.az-waf-lb-bap.id]
  depends_on = [
    azurerm_lb.az-waf-lb,
    azurerm_lb_probe.az-waf-lb-probe-http
  ]

}

#------------------------probes--------------------------------------#

resource "azurerm_lb_probe" "az-waf-lb-probe-ssh" {
  loadbalancer_id = azurerm_lb.az-waf-lb.id
  name            = "ssh-running-probe"
  port            = 22
  protocol        = "Tcp"
}

resource "azurerm_lb_probe" "az-waf-lb-probe-http" {
  loadbalancer_id = azurerm_lb.az-waf-lb.id
  name            = "http-running-probe"
  port            = 80
  protocol        = "Tcp"
}

#-------------------------backend pool------------------------------#

resource "azurerm_lb_backend_address_pool" "az-waf-lb-bap" {
  loadbalancer_id = azurerm_lb.az-waf-lb.id
  name            = "backend-address-pool"
}

#back-end address pool association for back-end machine 1
resource "azurerm_network_interface_backend_address_pool_association" "az-waf-bap-a" {
  network_interface_id    = azurerm_network_interface.az-waf-net-int.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.az-waf-lb-bap.id
}
#back-end address poool association for back-end machine 2
resource "azurerm_network_interface_backend_address_pool_association" "az-waf-bap-a-2" {
  network_interface_id    = azurerm_network_interface.az-waf-net-int-2.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.az-waf-lb-bap.id
}


#-----------------Outbound NAT gateway, for internet access--------------------------------#

resource "azurerm_public_ip" "az-waf-nat-gw-pip" {
  name                = "nat-gateway-publicIP"
  location            = azurerm_resource_group.az-waf-rg.location
  resource_group_name = azurerm_resource_group.az-waf-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "az-waf-nat-gw" {
  name                = "az-waf-nat-gw0"
  location            = azurerm_resource_group.az-waf-rg.location
  resource_group_name = azurerm_resource_group.az-waf-rg.name
}

resource "azurerm_nat_gateway_public_ip_association" "az-waf-nat-gw-pip-a" {
  nat_gateway_id       = azurerm_nat_gateway.az-waf-nat-gw.id
  public_ip_address_id = azurerm_public_ip.az-waf-nat-gw-pip.id
}

resource "azurerm_subnet_nat_gateway_association" "az-waf-nat-gw-a" {
  subnet_id      = azurerm_subnet.az-waf-sub.id
  nat_gateway_id = azurerm_nat_gateway.az-waf-nat-gw.id
}
