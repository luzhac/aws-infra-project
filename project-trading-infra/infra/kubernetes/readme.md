This project builds a self-managed Kubernetes cluster on AWS EC2 with a control plane, worker nodes, EFS storage, and IAM profiles.  
 
graph TD
    subgraph VPC_10.0.0.0/16
        IGW[Internet Gateway]
        subgraph Public_Subnets
            PUB_A[Public Subnet A\n10.0.1.0/24]
            PUB_C[Public Subnet C\n10.0.2.0/24]
        end
        subgraph Private_Subnets
            PRIV_A[Private Subnet A\n10.0.11.0/24]
            PRIV_C[Private Subnet C\n10.0.12.0/24]
        end
        PUB_A -->|connect| IGW
        PUB_C -->|connect| IGW

        NAT[NAT Gateway\nElastic IP]
        PUB_A --> NAT

        ALB[Application Load Balancer\nHTTP :80]
        PUB_A --> ALB
        PUB_C --> ALB

        PRIV_A -->|outbound via nat| NAT
        PRIV_C -->|outbound via nat| NAT

        Master[EC2 Master\n(private)]
        App[EC2 App Node\n(private)]
        Monitor[EC2 Monitor Node\n(private)]

        EFS[Amazon EFS\n(shared storage)]
        PRIV_A --> Master
        PRIV_C --> App
        PRIV_A --> Monitor
        Master -->|NFS 2049| EFS
        App -->|NFS 2049| EFS
        Monitor -->|NFS 2049| EFS

        ALB --> Master
        ALB --> App
        ALB --> Monitor

        SG_Cluster[Security Group: cluster-sg]
        SG_EFS[Security Group: efs-sg]
        SG_ALB[Security Group: alb-sg]

        Master --> SG_Cluster
        App --> SG_Cluster
        Monitor --> SG_Cluster
        EFS --> SG_EFS
        ALB --> SG_ALB

        SG_Cluster --- SG_EFS
    end
