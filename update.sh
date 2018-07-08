##!/bin/bash
#
#if [ -z ${PLUGIN_NAMESPACE} ]; then
#  PLUGIN_NAMESPACE="default"
#fi
#
#if [ -z ${PLUGIN_KUBERNETES_USER} ]; then
#  PLUGIN_KUBERNETES_USER="default"
#fi
#
#if [ ! -z ${PLUGIN_KUBERNETES_TOKEN} ]; then
#  KUBERNETES_TOKEN=$PLUGIN_KUBERNETES_TOKEN
#fi
#
#if [ ! -z ${PLUGIN_KUBERNETES_SERVER} ]; then
#  KUBERNETES_SERVER=$PLUGIN_KUBERNETES_SERVER
#fi
#
#kubectl config set-credentials default --token=${KUBERNETES_TOKEN}
#echo "WARNING: Using insecure connection to cluster"
#kubectl config set-cluster default --server=${KUBERNETES_SERVER} --insecure-skip-tls-verify=true
#
#kubectl config set-context default --cluster=default --user=${PLUGIN_KUBERNETES_USER}
#kubectl config use-context default

SOURCE_NAMESPACE=dev
TARGET_NAMESPACE=feature-test

echo > resources.yaml
for n in $(kubectl get -o=name ingress,service,deployment -l repo=app -n $SOURCE_NAMESPACE)
do
    (echo "---") >> resources.yaml
    kubectl get -o=yaml -n $SOURCE_NAMESPACE --export $n >> resources.yaml
done

kubectl create namespace $TARGET_NAMESPACE || true
kubectl apply -f resources.yaml -n $TARGET_NAMESPACE
