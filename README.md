# Deploy-to-k8s
democase of terraforming cluster deployment techniques

This document provides guidance on setting up JFrog Artifactory in a Kubernetes cluster. It serves as a basic tutorial for developers to install and configure JFrog on a Kubernetes environment running on a local machine.
Setup local environment to build DevOps resources



Cluster create, terraform script:

terraform init #Install the required providers to set up the necessary resources.
terraform plan #Verify the resources that will be installed on the system.
terraform apply #Install resources on the system

Following command verify the cluster

kubectl cluster-info
kubectl get nodes -o wide


We can verify that all resources have been installed in the "artifactory-oss" namespace. The Artifactory service UI is running on port 8082, while Artifactory itself is operating on port 8081.

kubectl get -n artifactory-oss all


Assume 192.168.49.2 is your current cluster/minikube IP address, or use localhost instead
Open the artifactory UI in the browser “http://192.168.49.2:30080/ui”

You can log in using the default username "admin" and password "password." Upon your first login, Artifactory will prompt you to change the default password. Be sure to update the password, set the base URL to http://jfrog.artifactory.devops.myapp.com (the domain configured in the Artifactory Ingress resource), and skip any other initial configuration steps.

We can create the initial repositories configurations to push the dependencies and binary in the artifactory.

Navigate to “Artifactory → Artifacts → Manage Repositories → Create Repository” and create the following repositories:

    Local: This repository manages your application binaries. For example “my-app-snapshot”
    Remote: This repository stores all dependencies used in your application, which will be downloaded from central repositories and stored in repository. For example “my-app-central-snapshot”
    Virtual: This virtual repository provides a common endpoint that aggregates the “Local” and “Remote” repositories. This endpoint will be configured in your application. “my-app-virtual-snapshot”

I am using maven repository to maintain the repository. Following configuration we have to give “my-app-snapshot” local repository

Following configuration we have to give “my-app-central-snapshot” local repository

Following configuration we have to give “my-app-virtual-snapshot” local repository

Add the local and remote repositories to the virtual repository and select the local repository in the “Default Deployment Repository”.

Once all the repositories are created, you can view them in the main section under “Artifactory → Artifacts.” The virtual URL http://jfrog.artifactory.devops.myapp.com/artifactory/my-app-virtual-snapshot/ will be used for your Maven application.

We need to configure the authentication details in the Maven settings configuration file “~/.m2/settings.xml” to enable your Maven application to authenticate with Artifactory.

<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">
    <servers>
        <server>
            <id>my-app-virtual-snapshot</id>
            <username>admin</username>
            <password>Give your artifactory admin passoword</password>
        </server>
    </servers>
</settings>

Note: The admin user should not be used for UI and Artifactory access. Instead, create a custom user with appropriate permissions for reading and writing in Artifactory.

We have configure the maven repository and distribution management tags inside our maven application POM XML file

<distributionManagement>
    <repository>
        <uniqueVersion>false</uniqueVersion>
        <id>my-app-virtual-snapshot</id>
        <name>my-app-virtual-snapshot</name>
        <url>http://jfrog.artifactory.devops.myapp.com/artifactory/my-app-virtual-snapshot/</url>
        <layout>default</layout>
    </repository>
</distributionManagement>

<repositories>
    <repository>
        <id>my-app-virtual-snapshot</id>
        <name>my-app-virtual-snapshot</name>
        <url>http://jfrog.artifactory.devops.myapp.com/artifactory/my-app-virtual-snapshot/</url>
        <layout>default</layout>
    </repository>
</repositories>

The we can deploy the maven application with following command

mvn clean deploy

