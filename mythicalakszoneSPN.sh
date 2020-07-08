# Create an AKS Cluster
echo "This script creates the following resources:"
echo "Resource Group. If it already exists, the creation continues without error."
echo "VNET & SUBNET. If it already exists, the creation continues without error."
echo "PublicIP if one is given as input, uses it else create a new Public IP for Load Balancer.\
On reruns it does not error if public ip already exists"
echo "Container Registry."
echo "AKS Cluster with:"
echo "3 Zones"
echo "User assigned Service Principal"
echo "Load Balancer Outbound IP"
echo "Autoscale"

NAME="mythicalakszonespn" 
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
EGRESS_PUBLIC_IP_RESOURCE_GROUP=$NETWORK_RESOURCE_GROUP  
EGRESS_PUBLIC_IP_RESOURCE_ID="" 
EGRESS_PUBLIC_IP_NAME=$NAME"-egress-pip" 
INGRESS_PUBLIC_IP_RESOURCE_GROUP=$NETWORK_RESOURCE_GROUP  
INGRESS_PUBLIC_IP_RESOURCE_ID="" 
INGRESS_PUBLIC_IP_DNS_LABEL=$NAME
INGRESS_PUBLIC_IP_NAME=$NAME"-ingress-pip" 
INGRESS_PUBLIC_IP=""
CLUSTER_SERVICEPRINCIPAL_ID=""
CLUSTER_SERVICEPRINCIPAL_SECRET=""
REGIONAL_ZONES="1 2 3"


# Login to Azure 
echo "login with your Corp/Enterprise Azure AD Tenant"
az login  
echo "Press to continue..."
read input


# Create Service Principal
echo "Get or Create Cluster Service Principal"
if [ -z "$CLUSTER_SERVICEPRINCIPAL_ID" ]
then
    # Create a Service Principal
    az ad sp create-for-rbac --name $CLUSTER_NAME --skip-assignment
    read -p "Please specify Service Principal Id: " CLUSTER_SERVICEPRINCIPAL_ID
    read -p "Please specify Service Principal password: " CLUSTER_SERVICEPRINCIPAL_SECRET
    echo "Creating Service Principal"
    #CLUSTER_SERVICEPRINCIPAL_ID=$(az ad sp create-for-rbac --name $CLUSTER_NAME --skip-assignment --query [appId] -o tsv)
fi
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
# Get the Cluster Subnet Resource ID as input to AKS creation
echo "Get Subnet ID"
CLUSTER_SUBNET_ID=$(az network vnet subnet show --resource-group $NETWORK_RESOURCE_GROUP --vnet-name $VNET_NAME -n $CLUSTER_SUBNET_NAME  --query "id" --output tsv)
echo $CLUSTER_SUBNET_ID
echo "Press to continue..."
read input

echo "Get or Create Egress Public IP for Outbound"
# If there is a  Public IP Address, use it, else, create a new Public IP
if [ -z "$EGRESS_PUBLIC_IP_RESOURCE_ID" ]
then
    # Create a Standard Zone Redundant Public IP for Load Balancer Outbound Communication
    echo "Creating Public IP"
    az network public-ip create -g $EGRESS_PUBLIC_IP_RESOURCE_GROUP \
                                -n $EGRESS_PUBLIC_IP_NAME \
                                --sku Standard 
    #Build logic to check for errors
    EGRESS_PUBLIC_IP_RESOURCE_ID=$(az network public-ip show -g $NETWORK_RESOURCE_GROUP  -n $EGRESS_PUBLIC_IP_NAME --query "id" --output tsv)
fi
echo "Using ${EGRESS_PUBLIC_IP_RESOURCE_ID} for Outbound"
echo "Press to continue..."
read input

echo "Get or Create Ingress Public IP for Outbound"
# If there is a  Public IP Address, use it, else, create a new Public IP
if [ -z "$INGRESS_PUBLIC_IP_RESOURCE_ID" ]
then
    # Create a Standard Zone Redundant Public IP for Load Balancer Outbound Communication
    echo "Creating Public IP"
    az network public-ip create   -g $INGRESS_PUBLIC_IP_RESOURCE_GROUP \
                                -n $INGRESS_PUBLIC_IP_NAME \
                                --dns-name $INGRESS_PUBLIC_IP_DNS_LABEL \
                                --sku Standard 
    #Build logic to check for errors
    INGRESS_PUBLIC_IP_RESOURCE_ID=$(az network public-ip show -g $INGRESS_PUBLIC_IP_RESOURCE_GROUP  -n $INGRESS_PUBLIC_IP_NAME --query "id" --output tsv)
    INGRESS_PUBLIC_IP=$(az network public-ip show -g $NETWORK_RESOURCE_GROUP  -n $EGRESS_PUBLIC_IP_NAME --query "ipAddress" --output tsv)
fi
echo "Using ${INGRESS_PUBLIC_IP_RESOURCE_ID} for Outbound"
echo "Press to continue..."
read input


echo "Create Azure Container Registry"
az acr create -n $ACR_NAME -g $CLUSTER_RESOURCE_GROUP --sku Standard
echo "Press to continue...Next is AKS Cluster Depeloyment"
read input


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
--load-balancer-outbound-ips ${EGRESS_PUBLIC_IP_RESOURCE_ID} \
--service-principal $CLUSTER_SERVICEPRINCIPAL_ID \
--client-secret $CLUSTER_SERVICEPRINCIPAL_SECRET \
--zones ${REGIONAL_ZONES}"

echo $AKS_CREATE_CMD
echo
echo "Deploy AKS"
echo "Press to execute Cluster Creation..."
read input
$AKS_CREATE_CMD

echo "Cluster Deployment Done"

#--attach-acr assigns permissions for the managed identity to pull from Azure container registry
echo "Grant Network Contributor Role to ${CLUSTER_SERVICEPRINCIPAL_ID} for AKS Cluster Subnet ${CLUSTER_SUBNET_ID}"
az role assignment create --assignee $CLUSTER_SERVICEPRINCIPAL_ID --scope $CLUSTER_SUBNET_ID --role "Network Contributor"
echo "Press to Continue."
read input

echo "Grant Contributor Role to ${CLUSTER_SERVICEPRINCIPAL_ID} for Load Balancer Egress PublicIp Resource Group ${EGRESS_PUBLIC_IP_RESOURCE_GROUP}"
az role assignment create --assignee $CLUSTER_SERVICEPRINCIPAL_ID --scope $EGRESS_PUBLIC_IP_RESOURCE_ID --role "Contributor"
echo "Press to Continue."
read input

#Create a service using the static IP address for ingress
#https://docs.microsoft.com/en-us/azure/aks/static-ip#create-a-service-using-the-static-ip-address
#Grant Access for the Identity of the Cluster to the resource group with Public IP for Inbound
#Also ensure that the PublicIP specified for outbound is also setup in the YAML files for the service
#In this case the NGINX service file will need to include the following
#annotations:
    #service.beta.kubernetes.io/azure-load-balancer-resource-group: mythicalakszone_RG
    #service.beta.kubernetes.io/azure-dns-label-name: mythicalakszone
#spec:
  #loadBalancerIP: X.X.X.X 

#Get the Resource Group for 
INGRESS_PUBLIC_IP_RESOURCEGROUP_ID=$(az group show --name ${INGRESS_PUBLIC_IP_RESOURCE_GROUP}  --query "id" --output tsv)
az role assignment create \
    --assignee $CLUSTER_SERVICEPRINCIPAL_ID \
    --role "Network Contributor" \
    --scope $INGRESS_PUBLIC_IP_RESOURCEGROUP_ID


echo "Script Ended - Cluster Deployment Done"
echo "Press to Exit."
read input

echo "#########################################################################"
#to Deploy NGINX, please use the YAML files from NGINX's Github repo
#https://docs.nginx.com/nginx-ingress-controller/installation/installation-with-manifests/
#Update loadbalancer.yaml in service folder to include the following
#annotations:
    #service.beta.kubernetes.io/azure-load-balancer-resource-group: ${INGRESS_PUBLIC_IP_RESOURCE_GROUP}
    #service.beta.kubernetes.io/azure-dns-label-name: ${INGRESS_PUBLIC_IP_DNS_LABEL}
#spec:
  #loadBalancerIP: X.X.X.X 

echo "az aks get-credentials -g ${CLUSTER_RESOURCE_GROUP} -n ${CLUSTER_NAME}"
echo "kubectl get nodes"
echo "kubectl describe nodes | grep -e \"Name:\" -e \"failure-domain.beta.kubernetes.io/zone\""
echo "kubectl apply -f AzureCatsDogs.yaml"

echo "NGINX Installation"
echo "helm install nginx-ingress stable/nginx-ingress \
    --namespace ingress-basic \
    --set controller.replicaCount=1 \
    --set controller.nodeSelector.\"beta\.kubernetes\.io/os\"=linux \
    --set defaultBackend.nodeSelector.\"beta\.kubernetes\.io/os\"=linux \
    --set controller.service.type=LoadBalancer \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.service.annotations.\"service\.beta\.kubernetes\.io/azure-load-balancer-resource-group\"=\"${INGRESS_PUBLIC_IP_RESOURCE_GROUP}\" \
    --set controller.service.loadBalancerIP=${INGRESS_PUBLIC_IP}"