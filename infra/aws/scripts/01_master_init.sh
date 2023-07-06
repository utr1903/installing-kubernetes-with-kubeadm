#!/bin/bash

### Update & upgrade
apt update
echo Y | apt upgrade
###

### Forwarding IPv4 and letting iptables see bridged traffic
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
###

### Install containerd

# Switch to a temporary directory
mkdir /home/ubuntu/tmp
cd /home/ubuntu/tmp

# Get & extract containerd tar
wget -O "containerd.tar.gz" "https://github.com/containerd/containerd/releases/download/v1.7.2/containerd-1.7.2-linux-amd64.tar.gz"
tar Cxzvf "/usr/local" "containerd.tar.gz"

# Put containerd service config
mkdir -p "/usr/local/lib/systemd/system/"
wget -O "/usr/local/lib/systemd/system/containerd.service" "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"

# Enable containerd service
systemctl daemon-reload
systemctl enable --now containerd
###

### Install runc
wget -O "runc.amd64" https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64
install -m 755 "runc.amd64" "/usr/local/sbin/runc"
###

### Install CNI
wget -O "cni-plugins.tgz" "https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz"
mkdir -p "/opt/cni/bin"
tar Cxzvf "/opt/cni/bin" "cni-plugins.tgz"
###

### Update containerd config.toml
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml.orig
sed -e 's/            SystemdCgroup = false/            SystemdCgroup = true/g' /etc/containerd/config.toml.orig >> /etc/containerd/config.toml
rm /etc/containerd/config.toml.orig
systemctl restart containerd
###

### Install kube*
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

# Download the Google Cloud public signing key
mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

# Add the Kubernetes apt repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

# Update apt package index, install kubelet, kubeadm and kubectl, and pin their version
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
###

### Create cluster
kubeadm init --pod-network-cidr=192.168.0.0/16

# Put kube config
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
###

### Install Calico network add-on

# Install Tigera Calico operator and CRDs
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

# Install Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
