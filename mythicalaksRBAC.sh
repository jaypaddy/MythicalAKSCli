# Create an AKS Cluster
echo "Welcome to AKS Deployment"
echo "-Multi Zone"
echo "-Azure CNI"
echo "-Standard LoadBalancer with PublicIP"



CLUSTER_RESOURCE_GROUP="MythicalAKSZone_RG" \
CLUSTER_NAME="mythicalakszone" \
LOCATION="eastus" \
SUBNET_NAME="mythicalakszone-snet" \
SERVICE_CIDR="10.0.0.0/16" \
DOCKER_BRIDGE="172.17.0.1/16" \
DNSSERVCE_IP="10.0.0.10" \
NETWORK_RESOURCE_GROUP="PADDYINC_NETWORK_RG" \
NODE_ACCOUNT="jaypaddy" \
ATTACH_ACR="mythicalakszone" \
DNS_NAME_PREFIX="paddyinc" \
NODEPOOL_NAME="nodepool1" \
USER_AUTH_AAD_TENANT="paddyinc.onmicrosoft.com" \
CLUSTER_AZURE_SUB_ID="881ac365-d417-4791-b2a9-48789acbb88d" \
SERVERAPP_ID="" \
SERVERAPP_SECRET="" \
CLIENTAPP_ID="" \
AAD_TENANT_ID="" \

echo "login to your User Authentication AAD Tenant"
# Login as Azure AD Admin
az login  
echo "Press to continue..."
read input

# Create an Azure resource group
echo "Creating AKS Cluster Resource Group - ${CLUSTER_RESOURCE_GROUP}"
az group create --name myResourceGroup --location westus2
echo "Press to continue..."
read input


# Create a service principal for the Azure AD Server pplication
# This service principal is used to authenticate itself within the Azure platform.
echo "Create a service principal for the Azure AD Server Application"
az ad sp create --id $SERVERAPP_ID
read input

# Get the service principal secret
echo "Get the service principal secret"
SERVERAPP_SECRET=$(az ad sp credential reset \
    --name $SERVERAPP_ID \
    --credential-description "AKSPassword" \
    --query password -o tsv)
read input

# Assign Permissions
# The Azure AD app needs permissions to perform the following actions:
#   Read directory data
#   Sign in and read user profile
echo "Assign Permissions"
az ad app permission add \
    --id $SERVERAPP_ID \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope 06da0dbc-49e2-44d2-8312-53f166ab848a=Scope 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role
read input

# Grant Permissions
echo "Grant Permissions"
az ad app permission grant --id $SERVERAPP_ID --api 00000003-0000-0000-c000-000000000000
az ad app permission admin-consent --id  $SERVERAPP_ID
read input


# Check if the App with the DisplayName already exists
APP_EXISTS=$(az ad app list \
    --display-name "${CLUSTER_NAME}Client" \
    --identifier-uri "https://${CLUSTER_NAME}Client" \
    --query [0].appId -o tsv)
if [ -z "$APP_EXISTS" ]
then
    # Get Create the APP, 
    # Create Azure AD Client application
    echo "Create Azure AD Server application"
    CLIENTAPP_ID=$(az ad app create \
        --display-name "${CLUSTER_NAME}Client" \
        --native-app \
        --reply-urls "https://${CLUSTER_NAME}Client" \
        --query appId -o tsv)
else
    CLIENTAPP_ID=$APP_EXISTS
    echo "Using existing Azure AD Server application ${CLUSTER_NAME}Server - ${CLIENTAPP_ID}"
fi
read input

# Create a service principal for the client application
echo "Create a service principal for the client application"
az ad sp create --id $CLIENTAPP_ID
read input

# Get the oAuth2 ID for the server app
echo "Get the oAuth2 ID for the server app"
oAuthPERMISSION_ID=$(az ad app show --id $SERVERAPP_ID --query "oauth2Permissions[0].id" -o tsv)
read input

# Add the permissions for the client application and server application components to use the oAuth2 communication flow
echo "Add the permissions for the client application and server application components to use the oAuth2 communication flow"
az ad app permission add --id $CLIENTAPP_ID --api $SERVERAPP_ID --api-permissions $oAuthPERMISSION_ID=Scope
az ad app permission grant --id $CLIENTAPP_ID --api $SERVERAPP_ID
read input

# Logout from paddyinc.onmicrosoft.com
echo "Logout from ${USER_AUTH_AAD_TENANT}"
az logout
read input

# Login to microsoft.onmicrosoft.com
echo "Login to Microsoft AAD Tenant"
az login -t microsoft.onmicrosoft.com 
az account set --subscription $CLUSTER_AZURE_SUB_ID
read input



echo "Create Cluster SPN"
CLUSTERSPN_ID=$(az ad sp create-for-rbac --skip-assignment \
    --name "${CLUSTER_NAME}SPN" \
    --query appId -o tsv)
read input

echo "Generate Cluster SPN Secret"
CLUSTERSPN_SECRET=$(az ad sp credential reset \
    --name $CLUSTERSPN_ID \
    --credential-description aksSPNpassword \
    --query password -o tsv)
read input


# Assumes Resource Group is created
echo "Get Subnet ID"
SUBNET_ID=$(az network vnet subnet show --resource-group $NETWORK_RESOURCE_GROUP --vnet-name paddyincVNET -n $SUBNETNAME  --query "id" --output tsv)
read input

# Assign the service principal Contributor permissions to the virtual network resource
az role assignment create --assignee $CLUSTERSPN_ID --scope $SUBNET_ID --role Contributor


echo "Deploy AKS"
# Deploy AKS Cluster
az aks create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $CLUSTER_NAME \
  --generate-ssh-keys \
  --aad-server-app-id $SERVERAPP_ID \
  --aad-server-app-secret $SERVERAPP_SECRET \
  --aad-client-app-id $CLIENTAPP_ID \
  --aad-tenant-id d3874fe2-2294-4325-ae98-8b107af06423 \
  --node-count 1 \
  --network-policy azure \
  --network-plugin azure \
  --vnet-subnet-id $SUBNET_ID \
  --enable-cluster-autoscaler \
  --docker-bridge-address $DOCKER_BRIDGE \
  --dns-service-ip $DNSSERVCE_IP \
  --service-cidr $SERVICE_CIDR \
  --service-principal $CLUSTERSPN_ID \
  --client-secret $CLUSTERSPN_SECRET \
  --location $LOCATION \
  --admin-username  $NODE_ACCOUNT \
  --dns-name-prefix $DNS_NAME_PREFIX \
  --nodepool-name $NODEPOOL_NAME \
  --vm-set-type VirtualMachineScaleSets \
  --min-count 1 \
  --max-count 3 \
  --no-wait 


  --attach-acr $ATTACH_ACR \

echo "Script Ended - Cluster Deployment Started"



echo "az aks create \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --name ${CLUSTER_NAME} \
  --generate-ssh-keys \
  --aad-server-app-id ${SERVERAPP_ID} \
  --aad-server-app-secret ${SERVERAPP_SECRET} \
  --aad-client-app-id ${CLIENTAPP_ID} \
  --aad-tenant-id d3874fe2-2294-4325-ae98-8b107af06423 \
  --node-count 1 \
  --network-policy azure \
  --network-plugin azure \
  --vnet-subnet-id ${SUBNET_ID} \
  --enable-cluster-autoscaler \
  --docker-bridge-address ${DOCKER_BRIDGE} \
  --dns-service-ip ${DNSSERVCE_IP} \
  --service-cidr ${SERVICE_CIDR} \
  --service-principal ${CLUSTERSPN_ID} \
  --client-secret ${CLUSTERSPN_SECRET} \
  --location ${LOCATION} \
  --admin-username  ${NODE_ACCOUNT} \
  --dns-name-prefix ${DNS_NAME_PREFIX} \
  --nodepool-name ${NODEPOOL_NAME} \
  --vm-set-type VirtualMachineScaleSets \
  --min-count 1 \
  --max-count 3 \
  --no-wait "

  az aks create   --resource-group PADDYINC_RG   --name mythicalk8srbacnp   --generate-ssh-keys   --aad-server-app-id 6319484e-e903-46ee-965d-cf1fa82c61e2   --aad-server-app-secret c61bbfbd-45aa-4542-ac13-9834945ee264   --aad-client-app-id a2889676-f9ed-41c4-9bc4-ab4873ee2268   --aad-tenant-id d3874fe2-2294-4325-ae98-8b107af06423   --node-count 1   --network-policy azure   --network-plugin azure   --vnet-subnet-id /subscriptions/881ac365-d417-4791-b2a9-48789acbb88d/resourceGroups/PADDYINC_NETWORK_RG/providers/Microsoft.Network/virtualNetworks/paddyincVNET/subnets/akssubnet   --enable-cluster-autoscaler   --docker-bridge-address 172.17.0.1/16   --dns-service-ip 10.0.0.10   --service-cidr 10.0.0.10/24   --service-principal 03c7b624-a3be-43c2-b6ca-414aea743354   --client-secret 647ec8b1-4f6e-4a7f-ad0c-60097b67da7b   --location southcentralus   --admin-username  jaypaddy   --dns-name-prefix paddyinc   --nodepool-name nodepool1   --vm-set-type VirtualMachineScaleSets   --min-count 1   --max-count 3   --no-wait 