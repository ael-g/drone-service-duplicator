#!/bin/bash

if [ -z ${PLUGIN_KUBERNETES_USER} ]; then
  PLUGIN_KUBERNETES_USER="default"
fi

if [ ! -z ${PLUGIN_KUBERNETES_TOKEN} ]; then
  KUBERNETES_TOKEN=$PLUGIN_KUBERNETES_TOKEN
fi

if [ ! -z ${PLUGIN_KUBERNETES_SERVER} ]; then
  KUBERNETES_SERVER=$PLUGIN_KUBERNETES_SERVER
fi

kubectl config set-credentials default --token=${KUBERNETES_TOKEN}
echo "WARNING: Using insecure connection to cluster"
kubectl config set-cluster default --server=${KUBERNETES_SERVER} --insecure-skip-tls-verify=true

kubectl config set-context default --cluster=default --user=${PLUGIN_KUBERNETES_USER}
kubectl config use-context default

#SOURCE_NAMESPACE=dev
#TARGET_NAMESPACE=feature-test-new
#SERVICE_LABEL=app
#MATCH_ON_KEY=repo
#HOST=feature-test.habx-dev.fr
#ADDITIONAL_SERVICES

HOST=$( echo $HOST | tr '[:upper:]' '[:lower:]')
TARGET_NAMESPACE=$( echo $TARGET_NAMESPACE | tr '[:upper:]' '[:lower:]')

ALL_SERVICES="$ADDITIONAL_SERVICES $SERVICE_LABEL"

# Deployments and service
echo > resources.yaml
echo > ingress.yaml

for additionalService in $ALL_SERVICES
do
  for n in $(kubectl get -o=name service,deployment -l $MATCH_ON_KEY=$additionalService -n $SOURCE_NAMESPACE)
  do
      (echo "---") >> resources.yaml
      kubectl get -o=yaml -n $SOURCE_NAMESPACE --export $n >> resources.yaml
  done

  # Ingress rules
  for n in $(kubectl get -o=name ingress -l $MATCH_ON_KEY=$additionalService -n $SOURCE_NAMESPACE)
  do
      (echo "---") >> ingress.yaml
      kubectl get -o=yaml -n $SOURCE_NAMESPACE --export $n | yq -y '. | .spec.rules[].host="'$HOST'" | .spec.tls[].hosts[0]="'$HOST'" | .spec.tls[].secretName="'$HOST'"'>> ingress.yaml
  done
done

# Other resources
echo > others.yaml
for n in $(kubectl get -o=name role,rolebinding -l drone-service-duplicator-duplicate-always=true -n $SOURCE_NAMESPACE)
do
    (echo "---") >> others.yaml
    kubectl get -o=yaml -n $SOURCE_NAMESPACE $n | yq -y '. | .metadata.namespace="'$TARGET_NAMESPACE'" | del(.metadata.creationTimestamp) | del(.metadata.resourceVersion) | del(.metadata.selfLink) | del(.metadata.uid)' >> others.yaml
done

cat resources.yaml ingress.yaml others.yaml > all.yaml

# Creating resources in kubernetes
PUSH_TIMESTAMP=$(date -Iseconds)

kubectl create namespace $TARGET_NAMESPACE || true
kubectl label namespace $TARGET_NAMESPACE sourceNamespace="$SOURCE_NAMESPACE" --overwrite
kubectl annotate namespace $TARGET_NAMESPACE lastGitPush="$PUSH_TIMESTAMP" --overwrite
kubectl apply -f all.yaml -n $TARGET_NAMESPACE

if [ ! -z ${SLACK_INCOMING_WEBHOOK} ]; then
  if [ ! -z ${GITHUB_TO_SLACK_ID_JSON} ]; then
    echo "Notifying commiter's "${DRONE_COMMIT_AUTHOR}" of url availability"
    SLACK_ID=$(wget -O - ${GITHUB_TO_SLACK_ID_JSON} | jq -r '.["'${DRONE_COMMIT_AUTHOR}'"]')
    curl -X POST -H 'Content-type: application/json' --data '{"text":"<@'$SLACK_ID'>, your feature is ready to be tested at url '$HOST'"}' ${SLACK_INCOMING_WEBHOOK}
  fi
fi
