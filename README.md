# Istio mTLS Microservices Example

This example demonstrates a simple microservices architecture using Istio with mTLS enabled. It consists of a frontend and backend service, with secure communication between them.

## Prerequisites

- Kubernetes cluster
- Istio installed
- kubectl configured to communicate with your cluster
- Helm 3

## Installation

1. Install Istio using Helm:
```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
helm install istio-base istio/base -n istio-system --create-namespace
helm install istiod istio/istiod -n istio-system --wait
helm install istio-ingressgateway istio/gateway -n istio-system --wait
```

2. Deploy the microservices:
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f k8s/gateway.yaml
kubectl apply -f k8s/security.yaml
```

## Architecture

- Frontend Service: A simple web service
- Backend Service: An API service
- Istio Gateway: Handles incoming traffic
- mTLS: Secures communication between services
- Authorization Policy: Controls access between services

## Testing

1. Get the Istio Ingress Gateway IP:
```bash
kubectl get svc istio-ingressgateway -n istio-system
```

2. Access the frontend through the gateway:
```bash
curl http://<INGRESS_IP>
```

3. Access the backend API:
```bash
curl http://<INGRESS_IP>/api
```

## Security Features

- mTLS is enabled for the backend service
- Authorization policy restricts access to the backend service
- Only the frontend service can access the backend API
- All communication is encrypted

## Cleanup

To remove all resources:
```bash
kubectl delete -f k8s/
``` 