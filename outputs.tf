###############################################################
# outputs.tf - PNETLab sur Infomaniak Public Cloud
###############################################################

output "pnetlab_floating_ip" {
  description = "IP publique pour accéder à PNETLab"
  value       = openstack_networking_floatingip_v2.pnetlab_fip.address
}

output "pnetlab_web_url" {
  description = "URL de l'interface web PNETLab"
  value       = "http://${openstack_networking_floatingip_v2.pnetlab_fip.address}"
}

output "pnetlab_ssh_command" {
  description = "Commande SSH pour se connecter à la VM"
  value       = "ssh -i ~/.ssh/id_rsa root@${openstack_networking_floatingip_v2.pnetlab_fip.address}"
}

output "pnetlab_instance_id" {
  description = "ID de l'instance OpenStack"
  value       = openstack_compute_instance_v2.pnetlab.id
}

output "pnetlab_private_ip" {
  description = "IP privée de la VM"
  value       = openstack_compute_instance_v2.pnetlab.access_ip_v4
}

output "image_id" {
  description = "ID de l'image PNETLab uploadée"
  value       = openstack_images_image_v2.pnetlab.id
}
