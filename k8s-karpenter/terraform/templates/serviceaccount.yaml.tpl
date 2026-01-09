apiVersion: v1
kind: ServiceAccount
metadata:
  name: karpenter
  namespace: karpenter-system
  annotations:
    eks.amazonaws.com/role-arn: ${controller_role_arn}
  labels:
    app.kubernetes.io/name: karpenter
    app.kubernetes.io/component: controller
