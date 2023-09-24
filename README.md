# About

[![Lint](https://github.com/rgl/terraform-vsphere-k0s/actions/workflows/lint.yml/badge.svg)](https://github.com/rgl/terraform-vsphere-k0s/actions/workflows/lint.yml)

An example [k0s Kubernetes](https://github.com/k0sproject/k0s) cluster in vSphere Debian Virtual Machines using terraform.

# Usage (Ubuntu 22.04 host)

Create and install the [base Debian 12 vagrant box](https://github.com/rgl/debian-vagrant).

Install Terraform:

```bash
wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
unzip terraform_1.5.7_linux_amd64.zip
sudo install terraform /usr/local/bin
rm terraform terraform_*_linux_amd64.zip
```

Save your environment details as a script that sets the terraform variables from environment variables, e.g.:

```bash
cat >secrets.sh <<'EOF'
export TF_VAR_prefix='k0s'
export TF_VAR_vsphere_user='administrator@vsphere.local'
export TF_VAR_vsphere_password='password'
export TF_VAR_vsphere_server='vsphere.local'
export TF_VAR_vsphere_datacenter='Datacenter'
export TF_VAR_vsphere_compute_cluster='Cluster'
export TF_VAR_vsphere_datastore='Datastore'
export TF_VAR_vsphere_network='VM Network'
export TF_VAR_vsphere_folder='k0s'
export TF_VAR_vsphere_k0s_template='vagrant-templates/debian-12-amd64'
export GOVC_INSECURE='1'
export GOVC_URL="https://$TF_VAR_vsphere_server/sdk"
export GOVC_USERNAME="$TF_VAR_vsphere_user"
export GOVC_PASSWORD="$TF_VAR_vsphere_password"
EOF
```

**NB** You could also add these variables definitions into the `terraform.tfvars` file, but I find the environment variables more versatile as they can also be used from other tools, like govc.

Create the infrastructure:

```bash
rm -f ~/.ssh/known_hosts*
terraform init
TF_LOG=TRACE TF_LOG_PATH=terraform-plan.log terraform plan -out=tfplan
TF_LOG=TRACE TF_LOG_PATH=terraform-apply.log time terraform apply tfplan
```

Show information about kubernetes:

```bash
terraform output --raw kubeconfig >kubeconfig.yml
export KUBECONFIG="$PWD/kubeconfig.yml"
kubectl version --output yaml
kubectl cluster-info
kubectl get nodes -o wide
kubectl api-versions
kubectl api-resources -o wide
kubectl get namespaces
kubectl get all --all-namespaces -o wide
kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp
kubectl get charts --all-namespaces # aka charts.helm.k0sproject.io
```

Destroy the infrastructure:

```bash
time terraform destroy -auto-approve
```
