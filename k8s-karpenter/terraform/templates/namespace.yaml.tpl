apiVersion: v1
kind: Namespace
metadata:
  name: karpenter-system
  labels:
    name: karpenter-system
    app.kubernetes.io/name: karpenter
    app.kubernetes.io/component: autoscaler
