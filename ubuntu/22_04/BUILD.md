# Build an Azure Virtual Machine Image

## Prerequisites

* Azure account credentials
* [az CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* [Packer](https://www.packer.io/downloads)


## Authenticate

### Use existing account

```
az login
```

### (Optional) Create a service principal

```
RESOURCE_GROUP={RESOURCE_GROUP}
SUBSCRIPTION_ID={SUBSCRIPTION_ID}
TENANT_ID={TENANT_ID}
CLIENT_SECRET={CLIENT_SECRET}
APP_NAME={SERVICE_PRINCIPAL_NAME}
az account set -s $SUBSCRIPTION_ID
az ad app create --display-name $APP_NAME --homepage "http://localhost/$APP_NAME"
APP_ID=$(az ad app list --display-name $APP_NAME | jq '.[0].appId' | tr -d '"')
az ad sp create-for-rbac --name $APP_ID --role="Contributor" --scopes="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
az ad sp credential reset --name "$APP_ID" --password "${CLIENT_SECRET}"
CLIENT_ID=$(az ad sp list --display-name $APP_ID | jq '.[0].appId' | tr -d '"')
az role assignment create --assignee "$CLIENT_ID" --role "Owner" --subscription "$SUBSCRIPTION_ID"
```
> Replace `{RESOURCE_GROUP}` with an existing resource group name; a [resource group](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal) is nothing more than a container for related resources.  Replace `{SUBSCRIPTION_ID}` with the id of your Azure subscription. Replace `{TENANT_ID}` with the tenant identifier.  To find the default subscription and tenant id type `az account list --query "[?isDefault]"`.  Replace `{CLIENT_SECRET}` with any alpha-numeric set of characters (and this secret must be 8 or more characters in length).  Replace `{SERVICE_PRINCIPAL_NAME}` with any alpha-numeric set of characters (and this name must also be 8 or more characters in length).

### (Optional) Login with service principal

```
az login --service-principal --username {APP_ID} --password {CLIENT_SECRET} --tenant {TENANT_ID}
```
> Replace `{APP_ID}`, `{CLIENT_SECRET}`, and `{TENANT_ID}` with the values you used to create the service principal above.

## Create shared image gallery

See https://docs.microsoft.com/en-us/azure/virtual-machines/create-gallery?tabs=cli and https://docs.microsoft.com/en-us/cli/azure/sig?view=azure-cli-latest#az-sig-create-examples.

For example

```
az sig create --resource-group cloudmonk --gallery-name toolsetvms
```

## Create image definition

See https://docs.microsoft.com/en-us/azure/virtual-machines/image-version?tabs=cli and https://docs.microsoft.com/en-us/cli/azure/sig/image-definition?view=azure-cli-latest#az-sig-image-definition-create.

For example

```
az sig image-definition create \
   --resource-group cloudmonk \
   --gallery-name toolsetvms \
   --gallery-image-definition K8sToolsetImage \
   --publisher myPublisher \
   --offer 0000-com-vmware-k8s-toolset-vm \
   --sku 2023 \
   --os-type Linux \
   --os-state generalized
```

## Use Packer to build and upload an Azure Virtual Machine Image

Copy common scripts into place

```
gh repo clone clicktruck/scripts
cp scripts/init.sh .
cp scripts/kind-load-cafile.sh .
cp scripts/inventory.sh .
cp scripts/install-krew-and-plugins.sh .
```

Type the following to build the image

```
packer init {HCL_FILENAME}
packer fmt {HC_FILENAME}
packer validate {HCL_FILENAME}
packer inspect {HCL}
packer build -only='{BUILD_NAME}.*' {HCL_FILENAME}
```
> Replace `{HCL_FILENAME}` with one of [ `arm.pkr.hcl`, `arm-ci.pkr.hcl` ].  If you choose `arm-ci.pkr.hcl` you will need to supply additional `-var` key-value pairs for [ `subscription_id`, `tenant_id`, `client_id`, and `client_secret` ] to `packer build` above.

> Replace `{BUILD_NAME}` with `standard`.  In ~10 minutes you should notice a `manifest.json` file where within the `artifact_id` contains a reference to the image ID.


### Available overrides

You may wish to size the instance and/or choose a different region to host the image.

```
packer build --var vm_size="Standard_A4" --var location="eastus2" -only='standard.*' arm.pkr.hcl
```
> Consult the `variable` blocks inside [arm.pkr.hcl](arm.pkr.hcl)



## For your consideration

* [Azure Virtual Machine Builders](https://www.packer.io/docs/builders/azure)
