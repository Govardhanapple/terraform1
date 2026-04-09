.tfvars
---------------------------------------------------

virtual_network_name   = "tf-vnet"
subent                 = "tf-subnet"
network_interface      = "tf-nic"
ip_configuration       = "My-ip"
virtual_machine        = "tf-machine"
public_ip              = "tf-publicip"
network_security_group = "tf-nsg"
nsg_rule = [
  {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  },
  {
    name                       = "test80"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
]
------------------------------------------------------------------------------
variable.tf

variable "virtual_network_name" {
  type        = string
  description = "this my vnet"
}
variable "subent" {
  type        = string
  description = "this my vnet-subnet"
}
variable "network_interface" {
  type        = string
  description = "this my vm nic"
}
variable "ip_configuration" {
  type        = string
  description = "this my Ip address"
}
variable "virtual_machine" {
  type        = string
  description = "my-vm"
}
variable "public_ip" {
  type        = string
  description = "my public ip "
}
variable "network_security_group" {
  type        = string
  description = "my nsg rules"
}
variable "nsg_rule" {
  description = "its my NSg_security_rule-dynamic"
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
}
--------------------------------------------------------------------------------------------
Mina.tf
----------------------------------------------------------------------------------------------
locals {
  resource_group = "my-frist-rg"
  location       = "west Europe"
}
resource "azurerm_resource_group" "RG" {
  name     = local.resource_group
  location = local.location
}
resource "azurerm_virtual_network" "tf-network" {
  name                = var.virtual_network_name
  location            = local.location
  resource_group_name = local.resource_group
  address_space       = ["10.0.0.0/16"]
  depends_on          = [azurerm_resource_group.RG]
}
resource "azurerm_subnet" "tf-subnet" {
  name                 = var.subent
  resource_group_name  = local.resource_group
  virtual_network_name = azurerm_virtual_network.tf-network.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on           = [azurerm_virtual_network.tf-network]
}
resource "azurerm_network_interface" "tf-nic" {
  name                = var.network_interface
  location            = local.location
  resource_group_name = local.resource_group
  depends_on          = [azurerm_virtual_network.tf-network, azurerm_subnet.tf-subnet, azurerm_public_ip.tf-ip]

  ip_configuration {
    name                          = var.ip_configuration
    subnet_id                     = azurerm_subnet.tf-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tf-ip.id
  }
}
resource "azurerm_linux_virtual_machine" "Td-vm" {
  name                  = var.virtual_machine
  resource_group_name   = local.resource_group
  location              = local.location
  size                  = "Standard_D2s_v3"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.tf-nic.id]
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("${path.module}/id_rsa.pub")
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  depends_on = [azurerm_network_interface.tf-nic, azurerm_resource_group.RG]
}
resource "azurerm_public_ip" "tf-ip" {
  name                = var.ip_configuration
  resource_group_name = local.resource_group
  location            = local.location
  allocation_method   = "Static"
  depends_on          = [azurerm_resource_group.RG]
}
resource "azurerm_network_security_group" "NSG" {
  name                = var.network_security_group
  location            = local.location
  resource_group_name = local.resource_group
  depends_on          = [azurerm_resource_group.RG]
  dynamic "security_rule" {
    for_each = var.nsg_rule
    content {
      name                       = security_rule.value["name"]
      priority                   = security_rule.value["priority"]
      direction                  = security_rule.value["direction"]
      access                     = security_rule.value["access"]
      protocol                   = security_rule.value["protocol"]
      source_port_range          = security_rule.value["source_port_range"]
      destination_port_range     = security_rule.value["destination_port_range"]
      source_address_prefix      = security_rule.value["source_address_prefix"]
      destination_address_prefix = security_rule.value["destination_address_prefix"]
    }
  }

}
resource "azurerm_subnet_network_security_group_association" "NSG-SUB" {
  subnet_id                 = azurerm_subnet.tf-subnet.id
  network_security_group_id = azurerm_network_security_group.NSG.id
  depends_on                = [azurerm_virtual_network.tf-network]
}
output "public_ip" {
  value = azurerm_linux_virtual_machine.Td-vm.public_ip_address
}
output "virtual_machine_name" {
  value = azurerm_linux_virtual_machine.Td-vm.name
}
output "virtual-network-privateIp" {
  value = azurerm_network_interface.tf-nic.private_ip_address
}
