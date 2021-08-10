**These instructions follow the deprecaated two steps approch to generate and manually push the extension driver image
on the OCP platform**

# Table of Contents
* [Deploy RHPAM on OpenShift with MS SQL Server](#deploy-rhpam-on-openshift-with-ms-sql-server)
    * [Deploy MS SQL instance](#deploy-ms-sql-instance)
        * [Create the RHPAM database and validate the MS SQL installation](#create-the-rhpam-database-and-validate-the-ms-sql-installation)
* [Build the custom KIE Server extension image](#build-the-custom-kie-server-extension-image)
* [Deploy the RHPAM application](#deploy-the-rhpam-application)
    * [Pushing the required images](#pushing-the-required-images)
    * [Deploy the KeiApp instance](#deploy-the-keiapp-instance)
    * [Validate the installation](#validate-the-installation)

# Deploy RHPAM on OpenShift with MS SQL Server
## Deploy MS SQL instance
**Note**: These steps are optional if you already have your own running instance of MS SQL server (either as an OpenShift
container or as a standalone service)
**Note**: These steps deploy an instance of MS SQL 2019 in the same OCP project where RHPAM will be then installed
**Note**: The original instructions are available at [Workshop: SQL Server 2019 on OpenShift (CTP 2.5)](https://github.com/johwes/sqlworkshops-sqlonopenshift/tree/master/sqlonopenshift/01_deploy).
The repository was forked to add a fix for latest versions of OpenShift.

**Prerequisites**
* You are logged into the OpenShift project
* You downloaded the secret file from Red Hat registry as rh.registry-secret.yaml

Create the password secret and deploy MS SQL instance
```shell
git clone git@github.com:dmartinol/sqlworkshops-sqlonopenshift.git
cd sqlworkshops-sqlonopenshift/sqlonopenshift/01_deploy
oc create secret generic mssql --from-literal=SA_PASSWORD="msSql2019"
oc apply -f storage.yaml
oc apply -f sqldeployment.yaml
```

In case you consider changing the password, please consider the password policy requirements:
`The password must be at least 8 characters long and contain characters from three of
the following four sets: Uppercase letters, Lowercase letters, Base 10 digits, and Symbols`

### Create the RHPAM database and validate the MS SQL installation
**Prerequisites**
* Docker

Run the following command to run an instance of the mssql-tools container and connect the `sqlcmd` tool to the running
MS SQL instance:
```shell
oc run -it --rm mssql-tools --image mcr.microsoft.com/mssql-tools
/opt/mssql-tools/bin/sqlcmd -Usa -PmsSql2019 -S${MSSQL_SERVICE_SERVICE_HOST},${MSSQL_SERVICE_SERVICE_PORT}
```

Then run the following SQL commands to check the database version and create the `rhpam` database:
```roomsql
SELECT @@version
GO
CREATE DATABASE rhpam
GO
SELECT name FROM master.sys.databases
GO
use rhpam
GO
SELECT * FROM information_schema.tables
GO
exit
exit
```

**Note**: Look at the content of ${MSSQL_SERVICE_SERVICE_HOST} and ${MSSQL_SERVICE_SERVICE_PORT} because they will also be used for the
deployment of RHPAM:
```shell
echo ${MSSQL_SERVICE_SERVICE_HOST}
echo ${MSSQL_SERVICE_SERVICE_PORT}
```
Output is:
```text
172.30.231.25
31433
```

## Build the custom KIE Server extension image

**Reference**: [2.6. Building a custom KIE Server extension image for an external database](https://access.redhat.com/documentation/en-us/red_hat_process_automation_manager/7.11/html-single/deploying_red_hat_process_automation_manager_on_red_hat_openshift_container_platform/index#externaldb-build-proc_openshift-operator)
**Prerequisites* [Validated on MacOS]
* Docker
* python3

Follow these instructions to create a virtualenv, activate it and configure it with all the needed dependencies, including
[CEKit](https://docs.cekit.io/en/3.11.0/index.html), the tool used to create the container image:
```shell
virtualenv ~/cekit
source ~/cekit/bin/activate
curl https://raw.githubusercontent.com/cekit/cekit/develop/requirements.txt -o requirements.txt
pip3 install -r requirements.txt
pip3 install -U cekit
pip3 install docker
pip3 install docker-squash
pip3 install behave
pip3 install lxml
```
Download these [templates](https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=rhpam&productChanged=yes)
then run the command to generate the extension image:
```shell
cd rhpam-7.11.0-openshift-templates/templates/contrib/jdbc/cekit
make mssql
```
Validate the image is created:
```shell
docker images | grep jboss-kie-mssql-extension-openshift-image
```

## Deploy the RHPAM application
[custom-rhpam-mssql.yaml](./custom-rhpam-mssql.yaml) defines the `KieApp` instance for the RHPAM application, with the
following features:
* KIE Server:
    * Custom image `rhpam-kieserver-rhel8-custom`
    * 1 replica
    * Using `external` database, pointing to the MS SQL instance defined above
* Business Central:
    * 1 replica

You can use this file as a reference to configure your instance (in particular, look at properties in the `database.externalConfig`
section, to connect it to your exact MS SQL instance)

### Pushing the required images
Tag and push the KIE Server custom image (downloaded from Quay if not already there) and the JDBC extension image to
your OCP namespace (`oc project -q`):
```shell
OCP_REGISTRY=$(oc get route -n openshift-image-registry | grep image-registry | awk '{print $2}')
docker login  -u `oc whoami` -p  `oc whoami -t` ${OCP_REGISTRY}

docker login quay.io
docker pull quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom:7.11.0-4
docker tag quay.io/ecosystem-appeng/rhpam-kieserver-rhel8-custom:7.11.0-4 \
    ${OCP_REGISTRY}/`oc project -q`/rhpam-kieserver-rhel8-custom:7.11.0-4
docker tag kiegroup/jboss-kie-mssql-extension-openshift-image:7.2.2.jre11 \
    ${OCP_REGISTRY}/`oc project -q`/jboss-kie-mssql-extension-openshift-image:7.2.2.jre11
    
docker push ${OCP_REGISTRY}/`oc project -q`/rhpam-kieserver-rhel8-custom:7.11.0-4
docker push ${OCP_REGISTRY}/`oc project -q`/jboss-kie-mssql-extension-openshift-image:7.2.2.jre11
```

**Note**: if `docker login` is not working because of the SSL certificate, add the OCP registry as an
insecure registry, adding the following to either `/etc/docker/daemon.json` or from the Docker Desktop application (MacOS):
```
"insecure-registries" : ["default-route-openshift-image-registry.apps.mw-ocp4.cloud.lab.eng.bos.redhat.com"]
```

**Note**: since we are pushing the container images into the OCP namespace, there's no need to define the secrets to store
the login passwords to `Quay.io` nor to the `Red Hat registry'

### Deploy the KeiApp instance
Run the following to deploy the sample application:
```shell
oc create -f custom-rhpam-mssql.yaml
```

**Note**: you should at least update the `extensionImageStreamTagNamespace` and `imageContext` properties to match your
actual project name

### Validate the installation
1. Verify the custom library is installed properly:
```shell
oc exec `oc get pods | grep custom-kieserver | grep Running | awk '{print $1}'` \
  -- ls /opt/eap/standalone/deployments/ROOT.war/WEB-INF/lib/GetTasksCustomAPI-1.0.jar
```
2. Run the application from the `Route` called `custom-rhpam-mssql-rhpamcentrmon`
