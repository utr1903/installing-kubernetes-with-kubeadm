# Installing Kubernetes with `kubeadm`

This repo is dedicated to show how to install Kubernetes on self-managed machines with kubeadm on different cloud providers.

The official documentation can be found [here](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)!

## Prerequisites

Not much :)

- Terraform
- AWS account

## Setting up cloud resources

Steps to create the necessary resources for each cloud provider is separately documented:

- [AWS](/infra/aws/README.md)

You _almost_ do not need to do anything manually, everything is already set up. You can simply run the Terraform deployment and your cluster environment will be provisioned automatically.

## Setting up VMs for Kubernetes

As mentioned above, the Terraform deployment does the job for you. Yet, the goal of the repo is to show how a Kubernetes cluster is set up from scratch on lovely Linux machines. So let's go through what the official Kubernetes documentation says.

### Installing container runtime

Obviously, since Kubernetes is a container orchestration tool, we need to install a container runtime onto our hosts. We will be using `containerd` for that purposes instead of widely known `Docker` since:
_Dockershim has been removed from the Kubernetes project as of release 1.24._ Here is the [FAQ](https://kubernetes.io/blog/2022/02/17/dockershim-faq/) for more!

We will be deploying Ubuntu 20.04 machines. So, let's update the machine fist:

```bash
apt update
echo Y | apt upgrade
```

Next, we need to forward IPv4 and letting iptables see bridged traffic. We persist the configuration so that it does not get lost after a possible reboot and we apply our changes right afterwards without rebooting:

```bash
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
```

We have to download some installation packages, so we create a working directory:

```bash
mkdir /home/ubuntu/tmp
cd /home/ubuntu/tmp
```

Let's download the [containerd](https://github.com/containerd/containerd) (`v1.7.2`) packages and unpack them into `/usr/local/lib/systemd/system/`. Finally, we can reload the daemon and enable the container service.

```bash
wget -O "containerd.tar.gz" "https://github.com/containerd/containerd/releases/download/v1.7.2/containerd-1.7.2-linux-amd64.tar.gz"
tar Cxzvf "/usr/local" "containerd.tar.gz"

mkdir -p "/usr/local/lib/systemd/system/"
wget -O "/usr/local/lib/systemd/system/containerd.service" "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"

systemctl daemon-reload
systemctl enable --now containerd
```

Next, we can install the [runc](https://github.com/opencontainers/runc) (`v1.1.7`):

```bash
wget -O "runc.amd64" https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64
install -m 755 "runc.amd64" "/usr/local/sbin/runc"
```

Now, we need a [CNI plugin](https://github.com/containernetworking/plugins). Here is the [definition](https://www.tigera.io/learn/guides/kubernetes-networking/kubernetes-cni/) of it from Calico:

_Container Network Interface (CNI) is a framework for dynamically configuring networking resources. It uses a group of libraries and specifications written in Go. The plugin specification defines an interface for configuring the network, provisioning IP addresses, and maintaining connectivity with multiple hosts._

Here, we download and unpack the package:

```bash
wget -O "cni-plugins.tgz" "https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz"
mkdir -p "/opt/cni/bin"
tar Cxzvf "/opt/cni/bin" "cni-plugins.tgz"
```

Lastly, we need to state to the containerd to use `systemd` for cgroup. To do that, we will create a default config file per the CLI, enable the systemd cgroup and restart the service:

```bash
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml.orig
sed -e 's/            SystemdCgroup = false/            SystemdCgroup = true/g' /etc/containerd/config.toml.orig >> /etc/containerd/config.toml
rm /etc/containerd/config.toml.orig
systemctl restart containerd
```

### Installing kubeadm, kubelet & kubectl

- `kubeadm` is a tool built to provide kubeadm init and kubeadm join as best-practice "fast paths" for creating Kubernetes clusters. It performs the actions necessary to get a minimum viable cluster up and running. By design, it cares only about bootstrapping, not about provisioning machines. Likewise, installing various nice-to-have addons, like the Kubernetes Dashboard, monitoring solutions, and cloud-specific addons, is not in scope [reference](https://kubernetes.io/docs/reference/setup-tools/kubeadm/).
- `kubelet` is the primary "node agent" that runs on each node. It can register the node with the apiserver using one of: the hostname; a flag to override the hostname; or specific logic for a cloud provider [reference](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/#synopsis).
- `kubectl` is a command line tool for communicating with a Kubernetes cluster's control plane, using the Kubernetes API [reference](https://kubernetes.io/docs/reference/kubectl/).

```bash
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
```

### Master nodes

We will be provisioning the Kubernetes cluster per `kubeadm` and will be having our master nodes specifically for our Kubernetes related workloads.

But before we create a cluster, we need to structure our network which means that we need to pick a networking provider. In this repo, we will be using [Calico](https://docs.tigera.io/calico/latest/about/). According to its [documentation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart#create-a-single-host-kubernetes-cluster), it is recommended to use `192.168.0.0/16` as a pod networking CIDR range which is also the reason, why we have chosen this for our virtual network in our cloud environments:

We haven't installed any other container runtime on our machines, so our cluster will automatically pick the containerd socket to communicate with our virtual container environment. However, we will still define precisely which socket to use.

Refer to the [official documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#initializing-your-control-plane-node) for any questions!

```bash
MASTER_NODE_IP=<Need to check after node deployment>
POD_NETWORK_CIDR="10.244.0.0/16"

kubeadm init \
  --apiserver-advertise-address=$MASTER_NODE_IP \
  --pod-network-cidr=$POD_NETWORK_CIDR \
  --cri-socket=unix:///var/run/containerd/containerd.sock
```

To make use of the `kubectl` for non-root users:

```bash
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

After `kubeadm` is finished, you can check your cluster per getting the nodes and the pods:

```bash
kubectl get node
kubectl get pod -A
```

You will see that your node will be stuck in `NotReady` status and your coredns pods will stuck in `Pending` status. The reason is that you haven't deployed your container network add-on yet.

Install the Weave Network Addon [link](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/):

```bash
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```

After the installation is complete, you need to define the `$POD_NETWORK_CIDR` for the Weave pods. In order to do that, edit the Weave daemonset:

```bash
kubectl edit ds -n kube-system <weave-daemonset-name>
```

and add an additional variable as:

```
IPALLOC_RANGE=$POD_NETWORK_CIDR
```

After you save the config and the Weave pods will restart, your node and coredns pods will be `Ready`!

### Worker nodes

Your master node is now ready. Now, it's time to join the worker nodes. This is the part where our automation unfortunately ends... You have your master node and thereby, control plane ready. You have your worker nodes pre-installed with container runtime and kube\* tools. But the workers do not know where the master is and how to connect to it.
