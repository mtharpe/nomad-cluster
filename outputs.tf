////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Repo:           allstate/nomad
//  File Name:      outputs.tf
//  Author:         Patrick Gryzan
//  Company:        Hashicorp
//  Date:           April 2020
//  Description:    This is the input variables file for the terraform project
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

output "outputs" {
    value                           = {
        consul                      = "http://${google_compute_instance.hashistack_server[0].network_interface.0.access_config.0.nat_ip}:8500"
        nomad                       = "http://${google_compute_instance.hashistack_server[0].network_interface.0.access_config.0.nat_ip}:4646"
        ssh_hashistack_server       = "ssh -o stricthostkeychecking=no -i ${ var.ssh.private_key } ${ var.ssh.username }@${ google_compute_instance.hashistack_server[0].network_interface.0.access_config.0.nat_ip } -y"
    }
}