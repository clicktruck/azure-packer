locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  image_version = formatdate("YYYY.M.D", timestamp())
}

variable "client_id" {
  type    = string
  default = ""
}

variable "client_secret" {
  type    = string
  default = ""
}

variable "subscription_id" {
  type    = string
  default = ""
}

variable "tenant_id" {
  type    = string
  default = ""
}

variable "resource_group" {
  type    = string
  default = "cloudmonk"
}

variable "image_name" {
  type    = string
  default = "K8sToolsetImage"
}

variable "init_script" {
  type    = string
  default = "init.sh"
}

variable "vm_size" {
  type    = string
  default = "Standard_D4s_v4"
}

variable "cloud_environment_name" {
  type    = string
  default = "Public"
}

# source blocks are generated from your builders; a source can be referenced in
# build blocks. A build block runs provisioner and post-processors on a
# source. Read the documentation for source blocks here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/source
source "azure-arm" "k8s-toolset" {
  client_id                          = var.client_id
  client_secret                      = var.client_secret
  subscription_id                    = var.subscription_id
  tenant_id                          = var.tenant_id

  cloud_environment_name             = var.cloud_environment_name     # One of Public, China, Germany, or USGovernment. Defaults to Public. Long forms such as USGovernmentCloud and AzureUSGovernmentCloud are also supported.

  build_resource_group_name          = var.resource_group

  shared_image_gallery_destination {
    image_name                       = var.image_name
    image_version                    = local.image_version
    resource_group                   = var.resource_group
    gallery_name                     = "toolsetvms"     # Shared Image Gallery must already exist in resource group
    replication_regions              = [ "eastus", "westus2", "centralus", "westcentralus" ]
  }

  managed_image_resource_group_name  = var.resource_group
  managed_image_name                 = "${var.image_name}${local.timestamp}"
  managed_image_storage_account_type = "Premium_LRS"

  os_type                            = "Linux"
  os_disk_size_gb                    = 60

  image_publisher                    = "Canonical"                    # e.g., az vm image list-publishers --location westus2 -o table
  image_offer                        = "0001-com-ubuntu-server-jammy" # e.g., az vm image list-offers --location westus2 --publisher Canonical -o table
  image_sku                          = "22_04-lts-gen2"               # e.g., az vm image list-skus --location westus2 --publisher Canonical --offer 0001-com-ubuntu-server-jammy -o table
  image_version                      = "latest"

  vm_size                            = var.vm_size                    # e.g., az vm list-sizes --location westus -o table

  keep_os_disk                       = "true"

  ssh_username                       = "ubuntu"
}

# a build block invokes sources and runs provisioning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/build

build {

  name = "standard"

  sources = [
    "source.azure-arm.k8s-toolset"
  ]

  provisioner "file" {
    source      = "install-krew-and-plugins.sh"
    destination = "/home/ubuntu/install-krew-and-plugins.sh"
  }

  provisioner "file" {
    source      = "inventory.sh"
    destination = "/home/ubuntu/inventory.sh"
  }

  provisioner "file" {
    source      = "kind-load-cafile.sh"
    destination = "/home/ubuntu/kind-load-cafile.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /home/ubuntu/inventory.sh",
      "chmod +x /home/ubuntu/kind-load-cafile.sh",
      "chmod +x /home/ubuntu/install-krew-and-plugins.sh"
    ]
  }

  provisioner "shell" {
    script = var.init_script
    # @see https://www.packer.io/docs/provisioners/shell#sudo-example
    execute_command = "echo 'packer' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
  }

  post-processor "checksum" {
    checksum_types = ["md5", "sha512"]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}