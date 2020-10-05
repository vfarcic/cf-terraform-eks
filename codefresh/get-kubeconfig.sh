set -e

terraform init

export CLUSTER_NAME=$(terraform output cluster_name)

export REGION=$(terraform output region)

export KUBECONFIG=$PWD/kubeconfig.yaml

aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION --alias $CLUSTER_NAME

kubectl apply --filename codefresh/create-cluster.yaml

export CURRENT_CONTEXT=$(kubectl config current-context)

set +e

codefresh delete cluster $CURRENT_CONTEXT

set -e

codefresh create cluster \
    --kube-context $CURRENT_CONTEXT \
    --serviceaccount codefresh \
    --namespace codefresh

echo 
echo 
echo "Execute the following command to use the newly created Kube config:"
echo
echo "export KUBECONFIG=$PWD/kubeconfig.yaml"

