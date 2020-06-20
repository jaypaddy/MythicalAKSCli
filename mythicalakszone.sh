# Create an AKS Cluster
echo "Welcome to AKS Deployment"
echo "-Multi Zone"
echo "-Azure CNI"
echo "-Standard LoadBalancer with User Assigned PublicIP"

NAME="mythicalakszone"
CLUSTER_RESOURCE_GROUP=$NAME"_RG" \
CLUSTER_NAME=$NAME \
LOCATION="eastus" \
VNET_NAME=$NAME"-vnet" \
VNET_ADDRESS_SPACE="10.201.0.0/16" \
CLUSTER_SUBNET_NAME=$NAME"-snet" \
CLUSTER_SUBNET_RANGE="10.201.0.0/22" \
CLUSTER_SUBNET_RESOURCE_ID="" \
SERVICE_CIDR="10.0.0.0/16" \
DOCKER_BRIDGE="172.17.0.1/16" \
DNSSERVICE_IP="10.0.0.10" \
NETWORK_RESOURCE_GROUP=$CLUSTER_RESOURCE_GROUP \
NODE_ACCOUNT="jaypaddy" \
ACR_NAME=$NAME \
DNS_NAME_PREFIX="paddyinc" \
NODEPOOL_NAME="nodepool1" \
CLUSTER_AZURE_SUB_ID="881ac365-d417-4791-b2a9-48789acbb88d" \
LOAD_BALANCER_PUBLIC_IP_RESOURCE_ID="" \
LOAD_BALANCER_PUBLIC_IP_NAME="mythicalakszone-pip"

echo "login to your User Authentication AAD Tenant"
# Login as Azure AD Admin
az login  
echo "Press to continue..."
read input

# Create an Azure resource group
echo "Creating AKS Cluster Resource Group - ${CLUSTER_RESOURCE_GROUP}"
az group create --name $CLUSTER_RESOURCE_GROUP --location eastus
echo "Press to continue..."
read input

#Create a VNET with Cluster Subnet
echo "Creating VNET-SUBNET  - ${VNET_NAME}-${CLUSTER_SUBNET_NAME}"
az network vnet create -g $NETWORK_RESOURCE_GROUP   \
                       -n $VNET_NAME                \
                       --address-prefix $VNET_ADDRESS_SPACE \
                       --subnet-name $CLUSTER_SUBNET_NAME \
                       --subnet-prefix $CLUSTER_SUBNET_RANGE
if [ $? -ne 0 ]
then
    echo "Error. Please delete the Resource Group ${NETWORK_RESOURCE_GROUP} & ${CLUSTER_RESOURCE_GROUP}"
    exit
fi
# Get the Cluster Subnet ID
echo "Get Subnet ID"
CLUSTER_SUBNET_ID=$(az network vnet subnet show --resource-group $NETWORK_RESOURCE_GROUP --vnet-name $VNET_NAME -n $CLUSTER_SUBNET_NAME  --query "id" --output tsv)
read input

if [ -z "$LOAD_BALANCER_OUTBOUND_IP_RESOURCE_ID" ]
then
    # Create a Standard Zone Redundant Public IP for Load Balancer Outbound Communication
    echo "Creating LoadBalancer Public IP"
    az network public-ip create   -g $NETWORK_RESOURCE_GROUP \
                                -n $LOAD_BALANCER_PUBLIC_IP_NAME \
                                --sku Standard 
    if [ $? -ne 0 ]
    then
        echo "Error. Please delete the Resource Group ${NETWORK_RESOURCE_GROUP} & ${CLUSTER_RESOURCE_GROUP}"
        exit
    fi
    LOAD_BALANCER_PUBLIC_IP_RESOURCE_ID=$(az network public-ip show -g $NETWORK_RESOURCE_GROUP  -n $LOAD_BALANCER_PUBLIC_IP_NAME --query "id" --output tsv)
fi
echo "Using ${LOAD_BALANCER_PUBLIC_IP_RESOURCE_ID}"
read input

echo "Create Azure Container Registry"
az acr create -n $ACR_NAME -g $CLUSTER_RESOURCE_GROUP --sku Standard

echo "Deploy AKS"
# Deploy AKS Cluster
az aks create \
  --resource-group $CLUSTER_RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --generate-ssh-keys \
  --node-count 3 \
  --min-count 3 \
  --max-count 9 \
  --network-policy calico \
  --network-plugin azure \
  --vnet-subnet-id $CLUSTER_SUBNET_ID \
  --docker-bridge-address $DOCKER_BRIDGE \
  --dns-service-ip $DNSSERVICE_IP \
  --service-cidr $SERVICE_CIDR \
  --location $LOCATION \
  --enable-cluster-autoscaler \
  --dns-name-prefix $DNS_NAME_PREFIX \
  --nodepool-name $NODEPOOL_NAME \
  --vm-set-type VirtualMachineScaleSets \
  --attach-acr $ACR_NAME \
  --load-balancer-sku standard \
  --load-balancer-outbound-ips $LOAD_BALANCER_PUBLIC_IP_RESOURCE_ID \
  --enable-managed-identity

echo "Script Ended - Cluster Deployment Done"

