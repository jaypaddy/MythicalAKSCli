
# Node Distribution
kubectl describe nodes | grep -e "Name:" -e "failure-domain.beta.kubernetes.io/zone"

# mythicalakszone.sh
![Image description](./MythicalAKSZone.png)
This script creates the following resources:
- Resource Group. If it already exists, the creation continues without error.
- VNET & SUBNET. If it already exists, the creation continues without error.
- Container Registry.
- AKS Cluster with:
- 3 Zones
- Managed Identity
- Load Balancer Outbound IP
- Load Balancer Ingress IP
- AutoScaler

# mythicalakszoneAGIC.sh
- In addition to mythicalakszone.sh, adds  App Gateway Ingress controller to AKS

