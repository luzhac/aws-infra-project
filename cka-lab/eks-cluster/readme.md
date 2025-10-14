sudo kubeadm init --pod-network-cidr=10.244.0.0/16   

# control plane
ls -l /etc/kubernetes/admin.conf

     #Create the Kubernetes config folder for your user
	#Copy cluster admin config into your user’s config file
            #Change ownership so your user can access it
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

kubectl get nodes


curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash



# nodes
sudo kubeadm join 10.20.1.190:6443 --token beb1y7.4a1zg4mkduu7yzm1 \
        --discovery-token-ca-cert-hash sha256:35a8b3bd1a93adafc40fe8dc76f7340be9ac72a02cb87e40fb2f154b833e4081
