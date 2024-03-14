# Overview

Shakudo is an easy to use data platform that has everything that a data team needs to deliver products end-to-end and continuously adds new integrations that data teams want.
By using Shakudo data teams become less reliant on engineers. Shakudo’s platform automates many common engineering and development tasks, and comes with built-in tools that simplify the process of scaling data solutions.

For more information, visit our [Website](https://www.shakudo.io/integrations) project.

For one click deployment to Google Kubernetes Engine see our
[Google Cloud Platform Marketplace solution](https://console.cloud.google.com/marketplace/details/shakudo-public/)

# Setup

## Command-line tools
You'll need the following tools in your development environment:

- install [kubectl](https://kubernetes.io/docs/tasks/tools/) (`kubectl` version should match the version of your cluster)
    ```shell
    curl -LO "https://dl.k8s.io/release/v1.27.3/bin/darwin/arm64/kubectl.sha256"
	curl -LO "https://dl.k8s.io/release/v1.27.3/bin/darwin/arm64/kubectl"
	echo "$(cat kubectl.sha256)  kubectl" | shasum -a 256 --check
	chmod +x ./kubectl
	sudo mv ./kubectl /usr/local/bin/kubectl
	sudo chown root: /usr/local/bin/kubectl
	kubectl version --client
	rm kubectl kubectl.sha256
    ```
- install [gcloud](https://cloud.google.com/sdk/docs/install)
- install [jq](https://stedolan.github.io/jq/download/)
- install [base64](https://formulae.brew.sh/formula/base64)
- install [kubectx](https://formulae.brew.sh/formula/kubectx)
- install [k9s](https://k9scli.io/topics/install/)
- Download the [keycloak server distribution](https://www.keycloak.org/downloads) and [update your path](https://www.keycloak.org/docs/latest/server_admin/#admin-cli)

## Set environment variables

Setup common environment variables that will be used for the deployment:

```shell
# This is the gcp project the scripts use for creating GKE cluster and an OAuth client
export GCP_PROJECT="REPLACE_ME"
# This is the gcp project where the Cloud DNS service is configured for your organization
export DNS_PROJECT="REPLACE_ME"
# This is the gcp project where your gcr is located
export GCR_PROJECT="REPLACE_ME"

export COMPUTE_ZONE="REPLACE_ME" # example: northamerica-northeast1-c 
export CLUSTER_NAME="REPLACE_ME"
export NODE_VERSION=1.27.8-gke.1067004
```

## Create a Google Kubernetes Engine (GKE) cluster

Use `gcloud` to login to your Google account:

```shell
gcloud auth login
```

Create a new cluster from the command-line:

```shell
gcloud container clusters create "${CLUSTER_NAME}" --project=${GCP_PROJECT} \
        --num-nodes=1 \
        --cluster-version="${NODE_VERSION}" \
        --zone="${COMPUTE_ZONE}" \
        --release-channel=None \
        --logging=NONE \
        --monitoring=NONE \
        --maintenance-window-start 04:00 \
        --maintenance-window-end 23:59 \
        --maintenance-window-recurrence 'FREQ=WEEKLY;BYDAY=SA,SU'
```

Create node pools from the command-line:

```shell
gcloud container node-pools create hyperplane-system-pool --project=${GCP_PROJECT} \
        --cluster "${CLUSTER_NAME}" \
        --zone="${COMPUTE_ZONE}" \
        --machine-type=e2-standard-8 \
        --node-version="${NODE_VERSION}" \
        --node-labels="hyperplane.dev/nodeType=hyperplane-system-pool" \
        --enable-autoscaling --min-nodes=0 --max-nodes=4 --num-nodes=1

gcloud container node-pools create autoscale-default-jobs-pool --project=${GCP_PROJECT} \
        --cluster "${CLUSTER_NAME}" \
        --zone="${COMPUTE_ZONE}" \
        --machine-type=e2-standard-8 \
        --node-version="${NODE_VERSION}" \
        --node-labels="hyperplane.dev/nodeType=default-jobs-pool" \
        --enable-autoscaling --min-nodes=0 --max-nodes=20 --num-nodes=1 --preemptible

gcloud container node-pools create autoscale-default-jhub-pool --project=${GCP_PROJECT} \
        --cluster "${CLUSTER_NAME}" \
        --zone="${COMPUTE_ZONE}" \
        --machine-type=e2-standard-8 \
        --node-version="${NODE_VERSION}" \
        --node-labels="hyperplane.dev/nodeType=default-jhub-pool" \
        --enable-autoscaling --min-nodes=0 --max-nodes=20 --num-nodes=1

gcloud container node-pools create autoscale-dask-pool-16-128 --project=${GCP_PROJECT} \
        --cluster "${CLUSTER_NAME}" \
        --zone="${COMPUTE_ZONE}" \
        --machine-type=e2-standard-16 \
        --node-version="${NODE_VERSION}" \
        --node-labels="hyperplane.dev/nodeType=dask-worker-pool" \
        --enable-autoscaling --min-nodes=0 --max-nodes=20 --num-nodes=1 --preemptible
```

Delete the default-pool which will not be used: 

```shell
gcloud container node-pools delete default-pool --project=${GCP_PROJECT} \
        --cluster "${CLUSTER_NAME}" \
        --zone="${COMPUTE_ZONE}"
```

Create a vpc firewall rule for the project:

```shell
gcloud compute firewall-rules create istio --project=${GCP_PROJECT} \
        --direction=INGRESS --priority=1000 --network=default --action=ALLOW \
        --rules=tcp:10250,tcp:443,tcp:15017 --source-ranges=0.0.0.0/0 \
        &> /dev/null || true
```

Create a persistent disk for conda (optional):

```shell
gcloud compute disks create shakudo-conda-disk --size=50GB --project "${GCP_PROJECT}" --zone "${COMPUTE_ZONE}"
```

Create a kubecontext for your new cluster:

```shell
gcloud container clusters get-credentials "${CLUSTER_NAME}" --zone "${COMPUTE_ZONE}" --project "${GCP_PROJECT}"
kubectl config use-context "gke_${GCP_PROJECT}_${COMPUTE_ZONE}_${CLUSTER_NAME}"
```

## Create your own GCP Service Account for certmanager and download its JSON Key File

Use a project which has Cloud DNS enabled:

```shell
gcloud config set project ${DNS_PROJECT}
```

Create a service account:

```shell
gcloud iam service-accounts create [SA_NAME] --description="[DESCRIPTION]" --display-name="[DISPLAY_NAME]"
```

Download the key file:

```shell
gcloud iam service-accounts keys create cloud_dns_service_account.json --iam-account [SA_NAME]@${DNS_PROJECT}.iam.gserviceaccount.com
```

Grant DNS admin to the service account:

```shell
gcloud projects add-iam-policy-binding ${DNS_PROJECT} --member="serviceAccount:[SA_NAME]@${DNS_PROJECT}.iam.gserviceaccount.com" --role roles/dns.admin
```

## Create your own GCP Service Account for accessing your gcr images and download its JSON Key File

```shell
gcloud config set project ${GCR_PROJECT}
```

Create a service account:

```shell
gcloud iam service-accounts create [SA_NAME] --description="[DESCRIPTION]" --display-name="[DISPLAY_NAME]"
```

Download the key file:

```shell
gcloud iam service-accounts keys create gcr_service_account.json --iam-account [SA_NAME]@${GCR_PROJECT}.iam.gserviceaccount.com
```

Grant object viewer access to the service account to pull gcr images:

```shell
gcloud projects add-iam-policy-binding ${GCR_PROJECT} --member="serviceAccount:[SA_NAME]@${GCR_PROJECT}.iam.gserviceaccount.com" --role="roles/storage.objectViewer
```

## Generate ssh keys for github and ssh portal

```shell
ssh-keygen -t rsa -N '' -f ./id_rsa_github
ssh-keygen -o -a 100 -t ed25519 -N '' -f ./id_ed25519_ssh_portal
```

Add the public key from the above command as a deploy key to your github repo. 
```shell
cat id_rsa_github.pub
```

Add the public key to the known hosts file:

```shell
cat id_rsa_github.pub >> KNOWN_HOSTS.txt 
```

## Configure the values.yaml with your desired values for pre and post installation

Set the following values to fit your deployment:

`TOREPLACE_RELEASE_NAMESPACE:` The namespace you plan to deploy the shakudo platform into (needs to match the namespace chosen in the gcp mp).

`TOREPLACE_DOMAIN:` The domain name where you want to host your shakudo dashboard app. Ex: shakudo.my_company.com

`TOREPLACE_DNS_PROJECT:` Your gcp project which has cloud dns enabled and configured. 

`TOREPLACE_GITPROJECTNAME:` The github project which your repository resides in. Ex: My-Corp

`TOREPLACE_GITREPONAME:` The git repo which will house your pipeline jobs. Ex: my-corp-datascience

`TOREPLACE_HYPERPLANE_GIT_BRANCH_NAME:` The branch name which will be used when pulling your jobs. 

`TOREPLACE_HYPERPLANE_GITSERVER_SSH_PUBLIC:` This should match the contents of id_rsa_github.pub.

Values which need to be Base64 encoded:

`TOREPLACE_DNS_SERVICEACCOUNT_KEYFILE_CONTENTS:` should match the output of `cat cloud_dns_service_account.json | base64`

`TOREPLACE_CLIENT_SERVICE_ACCOUNT_JSON:` should match the output of `cat gcr_service_account.json | base64`

`TOREPLACE_ID_RSA:` should match the output of `cat ./id_rsa_github | base64`

`TOREPLACE_ID_RSA_PUB:` should match the output of `cat ./id_rsa_github.pub | base64`

`TOREPLACE_ID_ED25519_SSH_PORTAL:` should match the output of `cat ./id_ed25519_ssh_portal | base64`

`TOREPLACE_ID_ED25519_SSH_PORTAL_PUB:` should match the output of `cat ./id_ed25519_ssh_portal.pub | base64`

`TOREPLACE_KNOWN_HOSTS:` should match the output of `cat ./KNOWN_HOSTS.txt | base64` 

# Installation

## Apply Pre-install resources 

```shell
./scripts/pre_gcp_mp_install.sh
```

## Quick install with Google Cloud Marketplace

Install this app to a Google Kubernetes Engine cluster via Google Cloud Marketplace, follow these [on-screen instructions](https://console.cloud.google.com/marketplace/details?project=shakudo-public)

## Apply Post-install resources

```shell
./scripts/post_gcp_mp_install.sh
```

## Create dns records for new domain 

Execute the following commands to create a dns record entry in your gcp project, ensure that you optain the load balancer ip from the istio-system service (can be found via k9s when viewing the services)

```shell
export RELEASE_NAMESPACE=MY_RELEASE_NAMESPACE
export PROJECT_ID=MY_GCP_PROJECT_WITH_DNS
export DOMAIN_NAME=my-cluster.dns-zone.com
export DNS_ZONE=MY_DNS_ZONE

export istio_system_json="$(kubectl get services -n "istio-system" -o=json)"
export load_balancer_external_ip="$(jq -r '.items[] | select(.spec.type == "LoadBalancer") | .status.loadBalancer.ingress[0].ip' <<< ${istio_system_json})"

gcloud dns --project=${PROJECT_ID} record-sets create ${DOMAIN_NAME}. --zone=${DNS_ZONE} --type=A --ttl=300 --rrdatas=${load_balancer_external_ip}
gcloud dns --project=${PROJECT_ID} record-sets create "*.${DOMAIN_NAME}." --zone=${DNS_ZONE} --type=A --ttl=300 --rrdatas=${load_balancer_external_ip}
```

Apply the certs:

```shell
./scripts/apply_certs --domain $DOMAIN_NAME
```

```sh
kubectl get certificates -o wide --all-namespaces
```
Wait for certs to be issued before configuring keycloak. 
If the status of any of the certificates is `False` after 5 minutes. Delete the certificate and apply the certs again
```sh
kubectl delete certificate <certificate-name> --all-namespaces
```

## Scale up resources
```shell
kubectl scale deployment hyperplane-live-notifications-informer --replicas=1 --namespace REPLACE_ME
kubectl scale deployment grafana --replicas=1 --namespace REPLACE_ME
kubectl scale deployment prometheus-operator --replicas=1 --namespace REPLACE_ME
kubectl scale deployment oauth2-proxy --replicas=1 --namespace REPLACE_ME
```

## Set up SSO (optional)

#### Create OAuth client
Go to [GCP credentials console](https://console.cloud.google.com/apis/credentials?referrer=search&)
> Create credentials --> OAuth client ID --> Application type=web application 


#### Add redirect URIs to OAuth client
```sh
echo "Authorized JavaScript origins -> add URI -> https://${DOMAIN_NAME}"
echo "Authorized redirect URIs -> add URI -> https://${DOMAIN_NAME}/auth/realms/Hyperplane/broker/google/endpoint"
```
> **User action:** Add the above URIs to the OAuth client

> **User action:** Replace <OAUTH_CLIENT_ID> and <OAUTH_CLIENT_SECRET> with your OAuth client id and secret from the step above. 
```sh
export HOSTED_DOMAIN=<Your SSO Domain>
./scripts/setup_sso.sh --client-id <OAUTH_CLIENT_ID> --client-secret <OAUTH_CLIENT_SECRET> --hosted-domain ${HOSTED_DOMAIN}
```

Navigate to `https://${DOMAIN_NAME}` and log in with google sso.

## Create users manually instead of using SSO (optional)

Get the keycloak admin password

```sh
kubectl get secret keycloak-login-pass -n test-namespace -o  jsonpath="{.data.password}" | base64 --decode
```

Navigate to `https://${DOMAIN_NAME}/auth/` and log in with username "admin" and password above, select realm "Hyperplane" navigate to the users page and create user accounts. 
