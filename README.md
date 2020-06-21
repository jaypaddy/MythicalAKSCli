
# Node Distribution
kubectl describe nodes | grep -e "Name:" -e "failure-domain.beta.kubernetes.io/zone"

# mythicalakszone.sh
This script creates the following resources:
- Resource Group. If it already exists, the creation continues without error.
- VNET & SUBNET. If it already exists, the creation continues without error.
- PublicIP if one is given as input, uses it else create a new Public IP for Load Balancer.       On reruns it does not error if public ip already exists
- Container Registry.
- AKS Cluster with:
- 3 Zones
- Managed Identity
- Load Balancer Outbound IP
- AutoScaler

# mythicalakszoneAGIC.sh
- In addition to mythicalakszone.sh, adds  App Gateway Ingress controller to AKS



