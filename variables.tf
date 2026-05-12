###############################################################
# variables.tf - PNETLab sur Infomaniak Public Cloud
###############################################################

variable "auth_url" {
  description = "URL d'authentification Keystone Infomaniak"
  type        = string
  default     = "https://api.pub1.infomaniak.cloud/identity/v3"
}

variable "project_name" {
  description = "Nom du projet OpenStack (ex: PCP-LPGJL2D)"
  type        = string
}

variable "username" {
  description = "Nom d'utilisateur OpenStack (ex: PCU-LPGJL2D)"
  type        = string
}

variable "password" {
  description = "Mot de passe OpenStack"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Région Infomaniak"
  type        = string
  default     = "dc4-a"
}

variable "pnetlab_image_path" {
  description = "Chemin local vers l'image QCOW2 de PNETLab"
  type        = string
  default     = "/mnt/c/Users/alexa/Downloads/pnetlab.qcow2"
}

variable "flavor_id" {
  description = "ID du flavor Infomaniak (8 vCPU / 32 Go RAM)"
  type        = string
  # a8-ram32-disk50-perf1 : 8 vCPU, 32 Go RAM, 50 Go disque
  default     = "3a4c0e4f-b272-4aa0-959a-eb4088c87b6d"
}

variable "external_network_id" {
  description = "ID du réseau externe Infomaniak"
  type        = string
  default     = "34a684b8-2889-4950-b08e-c33b3954a307"
}

variable "floating_ip_pool" {
  description = "Pool d'IP flottantes Infomaniak"
  type        = string
  default     = "ext-floating1"
}

variable "availability_zone" {
  description = "Zone de disponibilité"
  type        = string
  default     = "dc4-a-02"
}

variable "admin_cidr" {
  description = "CIDR autorisé à accéder à PNETLab"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé publique SSH"
  type        = string
  default     = "~/.ssh/id_rsa_pnetlab.pub"
}

variable "pnetlab_admin_password" {
  description = "Mot de passe admin interface web PNETLab"
  type        = string
  sensitive   = true
  default     = "PnetLab@2025!"
}
