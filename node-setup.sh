#!/bin/bash

# Set the hostname (node1, node2, node2...)
# sudo hostnamectl hostname node1

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

# Replace with whatever you got from kubeadm init
sudo kubeadm join 192.168.122.48:6443 --token hvs9aq.knfdh6tcjl14util --discovery-token-ca-cert-hash sha256:18988c12c612ee639561a31d18682246e62e60e1ac0d4fe370eb150d7114f00d
