# Configure the Microsoft Azure Provider
provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x. 
    # If you're using version 1.x, the "features" block is not allowed.
    version = "~>2.0"
    features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "plexurerg" {
    name     = var.resource_group_name
    location = var.location

    tags = {
        environment = var.env_tag
    }
}

# Create virtual network
resource "azurerm_virtual_network" "plexurenetwork" {
    name                = "${var.resource_group_name}.vnet"
    address_space       = ["10.0.0.0/16"]
    location            = azurerm_resource_group.plexurerg.location
    resource_group_name = azurerm_resource_group.plexurerg.name

    tags = {
        environment = var.env_tag
    }
}

# Create subnet
resource "azurerm_subnet" "plexuresubnet" {
    name                 = "${var.resource_group_name}.subnet"
    resource_group_name  = azurerm_resource_group.plexurerg.name
    virtual_network_name = azurerm_virtual_network.plexurenetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "plexurepublicip" {
    name                         = "${var.resource_group_name}.public.ip"
    location                     = azurerm_resource_group.plexurerg.location
    resource_group_name          = azurerm_resource_group.plexurerg.name
    allocation_method            = "Static"

    tags = {
        environment = var.env_tag
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "plexurensg" {
    name                = "${var.resource_group_name}.nsg"
    location            = azurerm_resource_group.plexurerg.location
    resource_group_name = azurerm_resource_group.plexurerg.name
    
        security_rule {
        name                       = "webService"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = var.env_tag
    }
}

# Create network interface
resource "azurerm_network_interface" "plexurenic" {
    name                      = "${var.resource_group_name}.vm.nic"
    location                  = azurerm_resource_group.plexurerg.location
    resource_group_name       = azurerm_resource_group.plexurerg.name

    ip_configuration {
        name                          = "${var.resource_group_name}.nic.ip"
        subnet_id                     = azurerm_subnet.plexuresubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.plexurepublicip.id
    }

    tags = {
        environment = var.env_tag
    }
}

# Associate nsg and nic
resource "azurerm_network_interface_security_group_association" "plexurensginc" {
    network_interface_id      = azurerm_network_interface.plexurenic.id
    network_security_group_id = azurerm_network_security_group.plexurensg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.plexurerg.name
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.plexurerg.name
    location                    = azurerm_resource_group.plexurerg.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = var.env_tag
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "plexure_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = "${tls_private_key.plexure_ssh.private_key_pem}" }

# Create virtual machine
resource "azurerm_linux_virtual_machine" "plexurevm" {
    name                  = var.server_name
    location              = azurerm_resource_group.plexurerg.location
    resource_group_name   = azurerm_resource_group.plexurerg.name
    network_interface_ids = [azurerm_network_interface.plexurenic.id]
    size                  = var.vm_size

    os_disk {
        name              = "${var.server_name}.os.disk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    computer_name  = var.computer_name
    admin_username = var.admin_user
    disable_password_authentication = true
        
    admin_ssh_key {
        username       = var.admin_user
        public_key     = tls_private_key.plexure_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = var.env_tag
        function = var.func_tag
    }
}

# create load balancer
resource "azurerm_public_ip" "plexurelbip" {
  name                = "${var.resource_group_name}.nlb.p.ip"
  location            = azurerm_resource_group.plexurerg.location
  resource_group_name = azurerm_resource_group.plexurerg.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "plexurelb" {
  name                = "${var.resource_group_name}.nlb"
  location            = azurerm_resource_group.plexurerg.location
  resource_group_name = azurerm_resource_group.plexurerg.name

  frontend_ip_configuration {
    name                 = "${var.resource_group_name}.f.ip"
    public_ip_address_id = azurerm_public_ip.plexurelbip.id
  }
}

resource "azurerm_lb_backend_address_pool" "plexurelbpool" {
  resource_group_name = azurerm_resource_group.plexurerg.name
  loadbalancer_id     = azurerm_lb.plexurelb.id
  name                = "${var.resource_group_name}.nlb.pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "plexurelbbackassociation" {
  network_interface_id    = azurerm_network_interface.plexurenic.id
  ip_configuration_name   = "${var.resource_group_name}.nic.ip"
  backend_address_pool_id = azurerm_lb_backend_address_pool.plexurelbpool.id
}

resource "azurerm_lb_probe" "plexurelbprobe" {
  resource_group_name = azurerm_resource_group.plexurerg.name
  loadbalancer_id     = azurerm_lb.plexurelb.id
  name                = "${var.resource_group_name}.nlb.probe"
  protocol            = "Tcp"
  port                = 80
}

resource "azurerm_lb_rule" "plexurelbrule" {
  resource_group_name            = azurerm_resource_group.plexurerg.name
  loadbalancer_id                = azurerm_lb.plexurelb.id
  name                           = "${var.resource_group_name}.nlb.rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "${var.resource_group_name}.f.ip"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.plexurelbpool.id
  probe_id                       = azurerm_lb_probe.plexurelbprobe.id
}

resource "azurerm_virtual_machine_extension" "plexureapache" {
  name                 = "${var.resource_group_name}.apache"
  virtual_machine_id   = azurerm_linux_virtual_machine.plexurevm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

    settings = <<SETTINGS
    {
        "fileUris": ["https://raw.githubusercontent.com/nz999999/WebServer/master/2.1%20Terraform/install_apache.sh"],
        "commandToExecute": "sh install_apache.sh"
    }
    SETTINGS
}
