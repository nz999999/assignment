variable "resource_group_name" {
  type        = string
  description = "The name of the resource group under which the resources will be created"
  default     = "Plexure_Web_RG"
}

variable "location" {
    type        = string
    description = "The location of the resource will be created"
    default     = "EastUS"
}

variable "env_tag" {
    type        = string
    description = "The tag of the resource will be created"
    default     = "Plexure"
}

variable "func_tag" {
    type        = string
    description = "The tag of the resource will be created"
    default     = "Web Server"
}

variable "vm_size" {
    type        = string
    description = "The size of the VM will be created"
    default     = "Standard_DS1_v2"
}

variable "server_name" {
    type        = string
    default     = "web_server_0001"
}

variable "computer_name" {
    type        = string
    default     = "webserver0001"
}

variable "admin_user" {
    type        = string
    default     = "azureuser"
}


