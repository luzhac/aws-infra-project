This project builds a self-managed Kubernetes cluster on AWS EC2 with a control plane, worker nodes, EFS storage, and IAM profiles.  

ROUTE53->ALB->TARGET_GROUP->K8S_INGRESS(nodeport)->K8S_SERVICE(no nodeport):->K8S_POD
 
                         ┌──────────────────────────────┐
                         │        Internet Users        │
                         └──────────────┬───────────────┘
                                        │  HTTP:80
                                        ▼
                     ┌────────────────────────────────────┐
                     │     AWS Application Load Balancer  │
                     │  (Internet-facing, Scheme: public) │
                     │  DNS: k8s-XXXX.elb.amazonaws.com   │
                     └──────────────┬───────────────┬─────┘
                                    │               │
                     forwards HTTP→ │               │
                                    ▼               ▼
               ┌──────────────────────────┐  ┌──────────────────────────┐
               │  Target Group: k8s-tg    │  │  Health Check: HTTP /    │
               │  Protocol: HTTP Port:30080│ │  Interval 15s Timeout 5s │
               │  Type: instance          │  │  Healthy≥2 Unhealthy≥2   │
               └──────────────┬───────────┘  └──────────────────────────┘
                              │
               Registers all EC2 nodes (Master + Workers)
                              │  port 30080
                              ▼
        ┌──────────────────────────────────────────────────────────┐
        │                 VPC 10.0.0.0/16                          │
        │  ┌───────────────────────────────┬────────────────────┐  │
        │  │     Public Subnets (a,c)     │  Private Subnets (a,c)│
        │  │   ALB + NAT Gateway here    │  EC2 Nodes here       │
        │  └──────────────┬───────────────┴──────────────┬───────┘
        │                 │                              │
        │      ┌──────────┴──────────┐          ┌────────┴────────┐
        │      │  Master Node       │          │ Worker Nodes     │
        │      │  kube-api : 6443   │          │  kubelet, pods   │
        │      │  containerd + CNI  │          │  NodePort 30080  │
        │      └──────────┬──────────┘          └────────┬────────┘
        │                 │   Pod Network (Flannel VXLAN 10.244.0.0/16)
        │                 └──────────────────────────────┬───────────┘
        │                                                │
        │                     ┌───────────────────────────▼──────────┐
        │                     │          Kubernetes Pods             │
        │                     │    (nginx deployment :80 TCP)        │
        │                     └──────────────────────────────────────┘
        └────────────────────────────────────────────────────────────┘

