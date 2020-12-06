# https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/
kubectl apply -f https://k8s.io/examples/service/load-balancer-example.yaml


kubectl get services lb-svc


# append manually patch ext ip
kubectl patch svc <svc-name> -n <namespace> -p '{"spec": {"type": "LoadBalancer", "externalIPs":["172.31.71.218"]}}'
# eg:
kubectl patch svc lb-svc -p '{"spec": {"type": "LoadBalancer", "externalIPs":["10.0.0.100"]}}'

