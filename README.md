# Nomad Cluster
This is an example of how to spin up a Nomad Cluster with Consul Networking. The example can easily be ported to physical servers or other public clouds. The magic all happens in the **templates > hashistack-init.sh** file.

## Using Physical Servers

### Preparation
* [Environment Prerequisites](https://nomadproject.io/docs/install/production/requirements/)
* [Deployment Guide](https://nomadproject.io/docs/install/production/deployment-guide/)
* Ports that need to be open
  - Nomad 4646, 4647, 4648
  - Consul 8300, 8301, 8302, 8500, 8600
  - DNS 53
* Have all of you Nomad Server IPs. These may be seperate from your clients.

### Internet Available
No Modifications to the hashistack-init.sh file

Copy the hashistack-init.sh file to the /tmp directory of the target RHEL 7 server.

### Air Gapped
Comment out the following lines in the hashistack-init.sh file:
```bash
31 #sudo yum update -y
32 #sudo yum install unzip -y
33 #sudo yum install java -y
```
```bash
42 #curl --silent --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
```
```bash
120 #curl --silent --remote-name https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip
```

Manually install unzip and java on the target servers.

Download the binaries for [Consul](https://www.consul.io/downloads.html) and [Nomad](https://nomadproject.io/downloads/), keeping the naming scheme above.

Copy the binaries and hashistack-init.sh file to the /tmp directory of the target RHEL 7 server.

### Installation
Make the script executable by running
```bash
chmod +x /tmp/hashistack-init.sh
```
Run the script with these mandatory options:
* -d - The name of the data center
* -c - The Consul version
* -n - The Nomad version
* -a - The type of agent. Either "client" or "server"
* -r - A list of Nomad server ip strings. Example : '\"1.1.1.1\", \"2.2.2.2\", \"3.3.3.3\"'
* -s - The Nomad server integer count

Server Example :
```bash
sudo /tmp/hashistack-init.sh -d 'demo' -c '1.7.2' -n '0.11.0' -a 'server' -r '\"1.1.1.1\", \"2.2.2.2\", \"3.3.3.3\"' -s 3"
```

Client Example :
```bash
sudo /tmp/hashistack-init.sh -d 'demo' -c '1.7.2' -n '0.11.0' -a 'client' -r '\"1.1.1.1\", \"2.2.2.2\", \"3.3.3.3\"' -s 3"
```

Pull up the UI:
* Consul - http://server-ip:8500
* Nomad - http://server-ip:4646

## Using Google Cloud Platform and Terraform

**Before you begin, please make sure you have an SSH key pair that allows you to SSH into the environment virtual machines. You will need the private key to perform some setup via Terraform.**

* To get started, clone the repo to your local drive and create a copy of the **terraform.tfvars.example** file named **terraform.tfvars**. 
* Fill in your GCP and SSH credentials.
* Run
  ```bash
  terraform init
  ```
  to initialize Terraform
* Run
  ```bash
  terraform apply -auto-approve
  ```
  to spin up F5 BIP-IP and Hashistack virtual machines. When complete, you should see the output commands

  ![alt text](https://github.com/pgryzan/f5-certificate-rotation/blob/master/images/Terraform%20Outputs.png "Terraform Output Commands")
  The Big-IP vm takes about 3 to 5 minutes to complete initialization. If you need to reference the Terraform outputs commands, you can always see them again by running
  ```bash
  terraform output
  ```
* Open the outputs **big_ip_adsress** url in the browser and login using the F5 credentials located in the variable.tf file. Set the Partition in the upper right hand corner to **Demo** and navigate to **Local Traffic > Virtual Servers > Virtual Server List.** You see something that looks like:

  ![alt text](https://github.com/pgryzan/f5-certificate-rotation/blob/master/images/F5%20VIP.png "F5 VIP")
* Now your ready to SSH into the Hashistack vm. Run the outputs **ssh_hashistack** command to login into the vm and **change the directory to /tmp**. This is where all of the certificate rotation action is happening.
* Take a look at the **certs.tmpl** file. This is the template that Consul Template uses to create the **certs.json** file. The certs.json file is uploaded to the F5 VM to rotate the certificate.
* Take a look at the **certs.json** file. Notice the we've already setup the Vault PKI Engine to rotate the certificates every 60 seconds. You can watch the remarks timestamp update by running:
  ```bash
  cat certs.json
  ```

  ![alt text](https://github.com/pgryzan/f5-certificate-rotation/blob/master/images/Generated%20Certs.png "Vault Generated Certificates")
* Finnaly, run the **update_cert** command on the Hashistack vm. You should see a completion output

  ![alt text](https://github.com/pgryzan/f5-certificate-rotation/blob/master/images/Cert%20Rotation%20Success.png "Certificate Success")
* If you wanted to have Consul Template automatically upload the certificate to the F5 VIP, then uncomment the **command** variable in the **/etc/consul-template.d/consul-template.hcl** file and restart the server using
  ```bash
  sudo service consul-template restart
  ```