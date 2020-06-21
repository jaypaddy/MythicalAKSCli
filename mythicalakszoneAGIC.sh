# Create an AKS Cluster
echo "This script creates the following resources:"
echo "Resource Group. If it already exists, the creation continues without error."
echo "VNET & SUBNET. If it already exists, the creation continues without error."
echo "PublicIP if one is given as input, uses it else create a new Public IP for Load Balancer.\
On reruns it does not error if public ip already exists"
echo "Container Registry."
echo "AKS Cluster with Application Gateway Ingress controller:"
echo "3 Zones"
echo "Managed Identity"
echo "Load Balancer Outbound IP"
echo "Autoscale"

NAME="mythicalakszone" 
CLUSTER_RESOURCE_GROUP=$NAME"_RG" 
CLUSTER_NAME=$NAME 
LOCATION="eastus" 
VNET_NAME=$NAME"-vnet" 
VNET_ADDRESS_SPACE="10.201.0.0/16" 
CLUSTER_SUBNET_NAME=$NAME"-snet" 
CLUSTER_SUBNET_RANGE="10.201.0.0/22" 
CLUSTER_SUBNET_RESOURCE_ID="" 
SERVICE_CIDR="10.0.0.0/16" 
DOCKER_BRIDGE="172.17.0.1/16" 
DNSSERVICE_IP="10.0.0.10" 
NETWORK_RESOURCE_GROUP=$CLUSTER_RESOURCE_GROUP 
NODE_ACCOUNT="jaypaddy" 
ACR_NAME=$NAME 
DNS_NAME_PREFIX="paddyinc" 
NODEPOOL_NAME="nodepool1" 
CLUSTER_AZURE_SUB_ID="881ac365-d417-4791-b2a9-48789acbb88d" 
PUBLIC_IP_RESOURCE_GROUP=$NETWORK_RESOURCE_GROUP  
PUBLIC_IP_RESOURCE_ID="" 
PUBLIC_IP_NAME="mythicalakszone-pip" 
REGIONAL_ZONES="1 2 3"
AGIC_SUBNET_NAME=$NAME"-appgw-snet"
#AGIC_VNET_ADDR_SPACE="10.202.0.0/16"
AGIC_SUBNET_RANGE="10.201.4.0/22"
AGIC_NAME="aksappgateway" 

# Login to Azure 
echo "login with your Corp/Enterprise Azure AD Tenant"
az login  
echo "Press to continue..."
read input

echo "App Gateway Ingress Controller Feature Registration"
az feature register --name AKS-IngressApplicationGatewayAddon --namespace microsoft.containerservice
echo "Press to continue..."
read input

echo "status of App Gateway Ingress Controller Feature Registration"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService')].{Name:name,State:properties.state}"
echo "Press to continue..."
read input

echo "refresh the registration of the Microsoft.ContainerService resource provider"
az provider register --namespace Microsoft.ContainerService
echo "Press to continue..."
read input

echo "add and refresh aks-preview"
az extension add --name aks-preview
az extension list
echo "Press to continue..."
read input


# Create an Azure resource group
echo "Creating AKS Cluster Resource Group - ${CLUSTER_RESOURCE_GROUP}"
az group create --name $CLUSTER_RESOURCE_GROUP --location eastus
echo "Press to continue..."
read input

#Create a VNET with Cluster Subnet and AGIC Subnets
echo "Creating VNET-SUBNET  - ${VNET_NAME}-${CLUSTER_SUBNET_NAME}"
az network vnet create -g $NETWORK_RESOURCE_GROUP   \
                       -n $VNET_NAME                \
                       --address-prefixes $VNET_ADDRESS_SPACE \
                       --subnet-name $CLUSTER_SUBNET_NAME \
                       --subnet-prefix $CLUSTER_SUBNET_RANGE
if [ $? -ne 0 ]
then
    echo "Error. Please delete the Resource Group ${NETWORK_RESOURCE_GROUP} & ${CLUSTER_RESOURCE_GROUP}"
    exit
fi
echo "VNET..."
az network vnet subnet list --resource-group $NETWORK_RESOURCE_GROUP --vnet-name $VNET_NAME --output table

# Get the Cluster Subnet Resource ID as input to AKS creation
echo "Get Cluster Subnet ID"
CLUSTER_SUBNET_ID=$(az network vnet subnet show --resource-group $NETWORK_RESOURCE_GROUP --vnet-name $VNET_NAME -n $CLUSTER_SUBNET_NAME  --query "id" --output tsv)
echo $CLUSTER_SUBNET_ID
echo "Press to continue..."
read input

echo "Get or Create Public IP for Outbound"
# If there is a  Public IP Address, use it, else, create a new Public IP
if [ -z "$PUBLIC_IP_RESOURCE_ID" ]
then
    # Create a Standard Zone Redundant Public IP for Load Balancer Outbound Communication
    echo "Creating Public IP"
    az network public-ip create   -g $PUBLIC_IP_RESOURCE_GROUP \
                                -n $PUBLIC_IP_NAME \
                                --sku Standard 
    #Build logic to check for errors
    PUBLIC_IP_RESOURCE_ID=$(az network public-ip show -g $NETWORK_RESOURCE_GROUP  -n $PUBLIC_IP_NAME --query "id" --output tsv)
fi
echo "Using ${PUBLIC_IP_RESOURCE_ID}"
echo "Press to continue..."
read input

echo "Create Azure Container Registry"
az acr create -n $ACR_NAME -g $CLUSTER_RESOURCE_GROUP --sku Standard
echo "Press to continue...Next is AKS Cluster Depeloyment"
read input

#Check if cluster already exists, if it does, then skip cluster creation
echo "Generating AKS Creation Command"
# Deploy AKS Cluster
AKS_CREATE_CMD="az aks create \
--resource-group ${CLUSTER_RESOURCE_GROUP} \
--name ${CLUSTER_NAME} \
--generate-ssh-keys \
--node-count 3 \
--min-count 3 \
--max-count 9 \
--network-policy calico \
--network-plugin azure \
--vnet-subnet-id ${CLUSTER_SUBNET_ID} \
--docker-bridge-address ${DOCKER_BRIDGE} \
--dns-service-ip ${DNSSERVICE_IP} \
--service-cidr ${SERVICE_CIDR} \
--location ${LOCATION} \
--enable-cluster-autoscaler \
--dns-name-prefix ${DNS_NAME_PREFIX} \
--nodepool-name ${NODEPOOL_NAME} \
--vm-set-type VirtualMachineScaleSets \
--attach-acr ${ACR_NAME} \
--load-balancer-sku standard \
--load-balancer-outbound-ips ${PUBLIC_IP_RESOURCE_ID} \
--enable-managed-identity \
--zones ${REGIONAL_ZONES} \
--enable-addons ingress-appgw \
--appgw-name ${AGIC_NAME} \
--appgw-subnet-prefix ${AGIC_SUBNET_RANGE}"

echo $AKS_CREATE_CMD
echo
echo
echo
echo "Deploy AKS"
echo "Press to execute Cluster Creation..."
read input
$AKS_CREATE_CMD
#echo $CMD_OUT
echo "Press to Continue..."
read input

echo "Cluster Deployment Done"
MANAGED_IDENTITY_ID=$(az aks show  --name ${CLUSTER_NAME} --resource-group ${CLUSTER_RESOURCE_GROUP} --query "identity.principalId" --output tsv)
echo "Managed Identity ${MANAGED_IDENTITY_ID}"

#echo "Grant Network Contributor Role to ${MANAGED_IDENTITY_ID} for AKS Cluster Subnet ${CLUSTER_SUBNET_ID}"
#az role assignment create --assignee $MANAGED_IDENTITY_ID --scope $CLUSTER_SUBNET_ID --role "Network Contributor"

echo "Grant Contributor Role to ${MANAGED_IDENTITY_ID} for Load Balancer PublicIp  ${PUBLIC_IP_RESOURCE_ID}"
az role assignment create --assignee $MANAGED_IDENTITY_ID --scope $PUBLIC_IP_RESOURCE_ID --role "Contributor"

echo "Script Ended - Cluster Deployment Done"
echo "Press to Exit."
read input

echo "#########################################################################"
echo "az aks get-credentials -g ${CLUSTER_RESOURCE_GROUP} -n ${CLUSTER_NAME}"
echo "kubectl get nodes"
echo "kubectl describe nodes | grep -e \"Name:\" -e \"failure-domain.beta.kubernetes.io/zone\""
echo "kubectl apply -f https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/aspnetapp.yaml"
echo "kubectl get ingress"
