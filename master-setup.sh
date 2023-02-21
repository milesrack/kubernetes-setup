#!/bin/bash

# Set the hostname
sudo hostnamectl hostname master

# Enable bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Disable swap
sudo swapoff -a
sudo sed -i -E 's/(^\/swap.*)/# \1/' /etc/fstab

# Install dependencies
sudo apt install apt-transport-https ca-certificates curl gnupg lsb-release git -y

# Install containderd
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install containerd.io -y
sudo systemctl enable containerd --now
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# Install kubernetes packages
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Find IP address
ip_arr=($(hostname -I))
ip=${ip_arr[0]}

# Start the cluster (save join command this outputs)
sudo kubeadm init --apiserver-advertise-address=$ip --apiserver-cert-extra-sans=$ip --pod-network-cidr=10.10.0.0/16 --node-name $(hostname)

# Allow us to interact with cluster API
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Set systemd as the cgroup driver
echo "cgroupDriver: systemd" >> $HOME/.kube/config

# Enable networking
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml

# Enable metrics
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml

# Restart the service
sudo systemctl restart kubelet

# Output join command
echo -n "sudo "; kubeadm token create --print-join-command
