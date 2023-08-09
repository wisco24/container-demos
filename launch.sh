#!/bin/bash

# exit when any command fails
set -e

# Check if number of arguments equals 3 or 4
if [ "$#" -ne 1 ]; then
    echo "You must enter a command line arguments: STACK_NAME "
    exit
fi

# Check if AWS CLI is installed.
if ! command -v aws &> /dev/null
then
    echo "AWS CLI could not be found. Install it here: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    exit
fi

# Check if JQ is installed.
if ! command -v jq &> /dev/null
then
    echo "JQ could not be found."
    exit
fi

# Get Bucket
BUCKET_NAME="v1-demo-environments"
Bucket_Location=$(aws s3api get-bucket-location --bucket ${BUCKET_NAME} --output text)
if [ $Bucket_Location != '' ] && [ $Bucket_Location != 'None' ]
then
  BUCKET_REGION=${Bucket_Location}
else
  BUCKET_REGION="us-east-1"
fi
echo 'Bucket Region is '${BUCKET_REGION}
echo ""

# Set Region
if [ $2 != '']
then
  AWS_REGION=$2
else
  AWS_REGION="us-east-1"
fi
echo 'Region to be deployed to is '${AWS_REGION}


# Create CloudFormation Stack
STACK_NAME=$1
BUCKET_URL="https://"${BUCKET_NAME}".s3."${BUCKET_REGION}".amazonaws.com"
TEMPLATE_URL=""${BUCKET_URL}"/main.template.yaml"
PARAMETER1="true"
PARAMETER2="true"
echo 'Deploying Stack...'
# You should add more parameters as needed under the --parameters flag, like:
# ParameterKey=PARAMETER1,ParameterValue=${PARAMETER1} \
# ParameterKey=PARAMETER2,ParameterValue=${PARAMETER2} \
aws cloudformation create-stack --stack-name ${STACK_NAME} \
    --template-url ${TEMPLATE_URL} \
    --parameters ParameterKey=BuildEks,ParameterValue=true \
    --parameters ParameterKey=BuildEcs,ParameterValue=true \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --disable-rollback --region ${AWS_REGION}

echo 'Stack deployed!'

curl https://github.com/wisco24/container-demos/blob/43fe910ad540a017424e4ce176a479f7df1d2f51/cloudshell.zip > cloudshell.zip
unzip cloudshell.zip
rm cloudshell.zip
cd cloudshell
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
sudo yum install -y openssl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
./deploy.sh