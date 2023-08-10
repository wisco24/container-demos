#!/bin/bash

# exit when any command fails
set -e

# Check if helm is installed.
if ! command -v helm &> /dev/null
then
    echo "helm could not be found. Install it following this: https://helm.sh/docs/intro/install/"
    exit
fi

# Check if jq is installed.
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Install it following this: https://stedolan.github.io/jq/download/"
    exit
fi

# Check if eksctl is installed.
if ! command -v eksctl &> /dev/null
then
    echo "eksctl could not be found. Install it following this: https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html"
    exit
fi

# Check if kubectl is installed.
if ! command -v kubectl &> /dev/null
then
    echo "kubectl could not be found. Install it following this: https://kubernetes.io/docs/tasks/tools/"
    exit
fi

# Local state file
STATE_FILE=".container-security-demo"

# Set color green for echo output
green=$(tput setaf 2)

# Set Cluster Name
CLUSTER_NAME=$1-cluster-$RANDOM

# Deploys EKS cluster.
echo "💬 ${green}Deploying EKS cluster $CLUSTER_NAME..."
eksctl create cluster \
    --tags Project=TrendMicroContainerSecurityDemo \
    -t t3.medium \
    --enable-ssm \
    --full-ecr-access \
    --region=$2 \
    --alb-ingress-access \
    --tags purpose=demo,owner="$(whoami)" \
    --name "$CLUSTER_NAME" \
    --vpc-public-subnets=$3,$4
echo "💬 ${green}EKS Cluster $CLUSTER_NAME deployed."


# Deploys Calico according to https://docs.aws.amazon.com/eks/latest/userguide/calico.html
echo "💬 ${green}Deploying Calico..."
kubectl create namespace tigera-operator
helm repo add projectcalico https://docs.projectcalico.org/charts
helm repo update                         
helm install calico projectcalico/tigera-operator --version v3.24.1 -f calico/values.yaml --namespace tigera-operator
echo "💬 ${green}Calico was deployed."

# Create demo attacker and namespace if it doesn't exist
kubectl create namespace attacker --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -

# Deplouy java-goof Vulnerable demo app
echo "💬 ${green}Deploying vulnerable apps..."
kubectl apply -f pods/java-goof.yaml
until kubectl get svc -n demo java-goof-service --output=jsonpath='{.spec.clusterIP}' | grep "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$" ; do : ; done
JAVAGOOFURL=$(kubectl get svc -n demo --selector=app=java-goof -o jsonpath='{.items[*].spec.clusterIP}')
echo "💬 ${green}java-goof URL: http://${JAVAGOOFURL}"

# Deploy openssl vulnerable app
kubectl apply -f pods/openssl3.yaml
until kubectl get -n demo svc web-app-service --output=jsonpath='{.spec.clusterIP}' | grep "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$" ; do : ; done
WEBAPPURL=$(kubectl get svc -n demo --selector=app=web-app -o jsonpath='{.items[*].spec.clusterIP}')
echo "💬 ${green}web-app URL: http://${WEBAPPURL}"
echo "💬 ${green}Vulnerable apps deployed."


# Installs Container Security to k8s Cluster
helm install \
     trendmicro \
     --namespace trendmicro-system --create-namespace \
     --values ../overrides.yaml \
     https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz
echo "💬 ${green}Container Security deployed."

# Saving state to local file for later demo cleanup
STATE=$(jq --null-input \
  --arg clustername "$CLUSTER_NAME" \
  '{"clustername": $clustername}')
echo "$STATE" > $STATE_FILE

echo "💬 ${green}Deployment completed."