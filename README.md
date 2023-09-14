# azure-lb-setup-2vms
Terraform code for building a site in azure with 2 backend VMs load-balanced complete with security rules and scripts.
Be sure to edit the azure-user-data.sh file in order to add your personal public ssh key if you'd like to SSH to the VMs.
To use this, clone the repo:
git clone https://github.com/Tpy0/azure-lb-setup-2vms

You'll have to authenticate with azure using 'az' azure cli tools - install this with your preferred package manager, brew, pacman (azure-cli), etc.

Authenticate:
$ az login

Then fire up terraform inside the repo directory:
$ cd azure-lb-setup-2vms
$ terraform init
$ terraform plan -out main.tfplan
$ terraform apply

This will take a short stint while it builds your infrastructure..Once it's done you can easily use the portal to find the public IP of the load balancer to use for web/ssh. This can be done with outputs as well (soon to come).

use a browser and point to the IP:
http://ipaddress_of_load_balancer

or use curl:
$ curl http://ipaddress_of_load_balancer

also, if you've correctly entered your key in the script file:
$ ssh alarm@ipaddress_of_load_balancer

Once your done, you can destroy the infrastructure with:
$ terraform destroy

[Currently the code needs some work with depends-on, so you might have to give it a minute between failures and try again in order to delete the resources. This is an issue with some things being deleted before they should be. More to come..]
