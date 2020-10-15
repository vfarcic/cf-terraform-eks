#!/bin/bash

if [ "$1" == "" ]; then
  echo "Usage: $0 [CLUSTER_NAME] [REGION]"
  exit
fi

export KUBECONFIG=$PWD/kubeconfig.yaml

aws eks update-kubeconfig --name $1 --region $2 --alias $1

echo "Execute the following command to use the newly created Kube config:"
echo
echo "export KUBECONFIG=$PWD/kubeconfig.yaml"

