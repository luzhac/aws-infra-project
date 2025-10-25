Pod & Event Debug Commands

1️⃣ Check pod list and status

kubectl get pods -n <ns> -o wide


2️⃣ Describe pod (see Events and reasons)

kubectl describe pod <pod-name> -n <ns>


3️⃣ Get recent events in namespace

kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp


4️⃣ Check logs of running container

kubectl logs <pod-name> -n <ns>


5️⃣ Check logs of specific container in a pod

kubectl logs <pod-name> -c <container-name> -n <ns>


6️⃣ Show previous (crashed) container logs

kubectl logs <pod-name> -n <ns> --previous


7️⃣ Exec into pod shell

kubectl exec -it <pod-name> -n <ns> -- /bin/sh


8️⃣ Check node status

kubectl get nodes -o wide


9️⃣ Check kubelet service logs on node (SSH required)

journalctl -u kubelet -f


🔟 Check container runtime logs (on node)

crictl ps
crictl logs <container-id>