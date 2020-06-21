
# Node Distribution
kubectl describe nodes | grep -e "Name:" -e "failure-domain.beta.kubernetes.io/zone"

# mythicalakszone.sh
This script creates the following resources:
Resource Group. If it already exists, the creation continues without error.
VNET & SUBNET. If it already exists, the creation continues without error.
PublicIP if one is given as input, uses it else create a new Public IP for Load Balancer.       On reruns it does not error if public ip already exists
Container Registry.
AKS Cluster with:
3 Zones
Managed Identity
Load Balancer Outbound IP
AutoScaler

az aks create --resource-group mythicalakszone_RG --name mythicalakszone --generate-ssh-keys --node-count 3 --min-count 3 --max-count 9 --network-policy calico --network-plugin azure --vnet-subnet-id /subscriptions/881ac365-d417-4791-b2a9-48789acbb88d/resourceGroups/mythicalakszone_RG/providers/Microsoft.Network/virtualNetworks/mythicalakszone-vnet/subnets/mythicalakszone-snet --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.0.0.10 --service-cidr 10.0.0.0/16 --location eastus --enable-cluster-autoscaler --dns-name-prefix paddyinc --nodepool-name nodepool1 --vm-set-type VirtualMachineScaleSets --attach-acr mythicalakszone --load-balancer-sku standard --load-balancer-outbound-ips /subscriptions/881ac365-d417-4791-b2a9-48789acbb88d/resourceGroups/mythicalakszone_RG/providers/Microsoft.Network/publicIPAddresses/mythicalakszone-pip --enable-managed-identity --zones 1 2 3 --enable-addons ingress-appgw --appgw-name aksappgateway --appgw-subnet-prefix 10.201.5.0/22

