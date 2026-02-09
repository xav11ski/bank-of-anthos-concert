#!/bin/bash
# deploy-frontend.sh — Build, push, and roll out frontend changes
# Usage: ./deploy-frontend.sh

set -e

REGISTRY=default-route-openshift-image-registry.apps.o1-968455.cp.fyre.ibm.com
NAMESPACE=demoapps-bank-anthos
IMAGE=frontend

# Auto-increment tag based on what's in the registry
LATEST_TAG=$(oc get imagestreamtag -n $NAMESPACE 2>/dev/null | grep "$IMAGE:" | sed 's/.*:v//' | sed 's/ .*//' | sort -n | tail -1)
NEXT_TAG="v$((LATEST_TAG + 1))"
echo "🏷  Building as $IMAGE:$NEXT_TAG"

# Auth
SA_TOKEN=$(oc create token registry-pusher -n $NAMESPACE)
podman login $REGISTRY -u registry-pusher -p $SA_TOKEN --tls-verify=false

# Build (amd64 for cluster)
podman build --platform linux/amd64 \
  -t $REGISTRY/$NAMESPACE/$IMAGE:$NEXT_TAG \
  ./src/frontend/

# Push
podman push $REGISTRY/$NAMESPACE/$IMAGE:$NEXT_TAG --tls-verify=false

# Update deployment
oc set image deployment/frontend \
  front=image-registry.openshift-image-registry.svc:5000/$NAMESPACE/$IMAGE:$NEXT_TAG \
  -n $NAMESPACE

# Wait for rollout
oc rollout status deployment/frontend -n $NAMESPACE

echo "✅ Deployed $IMAGE:$NEXT_TAG"
