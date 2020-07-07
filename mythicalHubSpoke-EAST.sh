echo "adapted from the article:"
echo "https://medium.com/@denniszielke/fully-private-aks-clusters-without-any-public-ips-finally-7f5688411184"
# here enter your subscription id 
SUBSCRIPTION_ID=$(az account show --query id -o tsv) 
# here enter the resources group name of your aks cluster
KUBE_GROUP="EAST_MythicalAKSNoPIP_RG" 
# here enter the name of your kubernetes resource
KUBE_NAME="eastmythicalaksnopip" 
# here enter the datacenter location
LOCATION="eastus" 
# here the name of the resource group for the vnet and hub resources
VNET_GROUP="EAST_MythicalAKSNoPIP_NETWORK_RG" 
# here enter the name of your vnet
KUBE_VNET_NAME="east-mythical-spoke-vnet" 
# here enter the name of your ingress subnet
KUBE_ING_SUBNET_NAME="east-ingress-snet" 
# here enter the name of your aks subnet 
KUBE_AGENT_SUBNET_NAME="east-aks-snet"  
HUB_VNET_NAME="eastmythical-hub-vnet"  
# this you cannot change
HUB_FW_SUBNET_NAME="AzureFirewallSubnet"  
HUB_JUMP_SUBNET_NAME="eastjumpbox-snet" 
# here enter the name of your azure firewall resource
FW_NAME="eastmythicalfw"  
# azure firewall force tunneling route name
FW_ROUTE_NAME="${FW_NAME}_fw_r"  
# our new user defined route to force all traffic to the azure firewall
FW_ROUTE_TABLE_NAME="${FW_NAME}_fw_rt"  
KUBE_VERSION="1.16.8" # here enter the kubernetes version of your aks

az account set --subscription $SUBSCRIPTION_ID
az group create -n $KUBE_GROUP -l $LOCATION
az group create -n $VNET_GROUP -l $LOCATION
az network vnet create -g $VNET_GROUP -n $HUB_VNET_NAME --address-prefixes 10.0.0.0/22
az network vnet create -g $VNET_GROUP -n $KUBE_VNET_NAME --address-prefixes 10.0.4.0/22
az network vnet subnet create -g $VNET_GROUP --vnet-name $HUB_VNET_NAME -n $HUB_FW_SUBNET_NAME --address-prefix 10.0.0.0/24
az network vnet subnet create -g $VNET_GROUP --vnet-name $HUB_VNET_NAME -n $HUB_JUMP_SUBNET_NAME --address-prefix 10.0.1.0/24
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24
az network vnet peering create -g $VNET_GROUP -n HubToSpoke1 --vnet-name $HUB_VNET_NAME --remote-vnet $KUBE_VNET_NAME --allow-vnet-access
az network vnet peering create -g $VNET_GROUP -n Spoke1ToHub --vnet-name $KUBE_VNET_NAME --remote-vnet $HUB_VNET_NAME --allow-vnet-access

az extension add --name azure-firewall
az network public-ip create -g $VNET_GROUP -n $FW_NAME --sku Standard
az network firewall create --name $FW_NAME --resource-group $VNET_GROUP --location $LOCATION
az network firewall ip-config create --firewall-name $FW_NAME --name $FW_NAME --public-ip-address $FW_NAME --resource-group $VNET_GROUP --vnet-name $HUB_VNET_NAME
FW_PRIVATE_IP=$(az network firewall show -g $VNET_GROUP -n $FW_NAME --query "ipConfigurations[0].privateIpAddress" -o tsv)
az monitor log-analytics workspace create --resource-group $VNET_GROUP --workspace-name $FW_NAME --location $LOCATION

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
az network route-table create -g $VNET_GROUP --name $FW_ROUTE_TABLE_NAME
az network route-table route create --resource-group $VNET_GROUP --name $FW_ROUTE_NAME --route-table-name $FW_ROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP --subscription $SUBSCRIPTION_ID
az network vnet subnet update --route-table $FW_ROUTE_TABLE_NAME --ids $KUBE_AGENT_SUBNET_ID
az network route-table route list --resource-group $VNET_GROUP --route-table-name $FW_ROUTE_TABLE_NAME

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "time" --destination-addresses "*"  --destination-ports 123 --name "allow network" --protocols "UDP" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "aks node time sync rule" --priority 101
az network firewall network-rule create --firewall-name $FW_NAME --collection-name "dns" --destination-addresses "*"  --destination-ports 53 --name "allow network" --protocols "UDP" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "aks node dns rule" --priority 102
az network firewall network-rule create --firewall-name $FW_NAME --collection-name "servicetags" --destination-addresses "AzureContainerRegistry" "MicrosoftContainerRegistry" "AzureActiveDirectory" "AzureMonitor" --destination-ports "*" --name "allow service tags" --protocols "Any" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "allow service tags" --priority 110






az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "aksimages" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $VNET_GROUP --action "Allow" --target-fqdns "mcr.microsoft.com" "*.data.mcr.microsoft.com" "acs-mirror.azureedge.net" --priority 101
az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "osupdates" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $VNET_GROUP --action "Allow" --target-fqdns "download.opensuse.org" "security.ubuntu.com" "packages.microsoft.com" "azure.archive.ubuntu.com" "snapcraft.io"  --priority 102


SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME -o json | jq -r '.appId')
SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
sleep 5 # wait for service principal to propagate
az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $VNET_GROUP

#Internal Load Balancer
az aks create   --resource-group $KUBE_GROUP \
                --name $KUBE_NAME \
                --generate-ssh-keys \
                --node-count 1 \
                --min-count 1 \
                --max-count 3 \
                --enable-cluster-autoscaler \
                --network-policy calico \
                --network-plugin azure \
                --load-balancer-sku basic \
                --vm-set-type VirtualMachineScaleSets \
                --vnet-subnet-id $KUBE_AGENT_SUBNET_ID \
                --docker-bridge-address 172.17.0.1/16 \
                --dns-service-ip 10.2.0.10 \
                --service-cidr 10.2.0.0/24 \
                --service-principal $SERVICE_PRINCIPAL_ID \
                --client-secret $SERVICE_PRINCIPAL_SECRET \
                --kubernetes-version $KUBE_VERSION \
                --nodepool-name nodepool1 