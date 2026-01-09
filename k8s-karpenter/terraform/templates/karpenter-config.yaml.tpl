apiVersion: v1
kind: ConfigMap
metadata:
  name: karpenter-config
  namespace: karpenter-system
data:
  settings.yaml: |
    clusterName: ${cluster_name}
    defaultInstanceProfile: ${instance_profile}
    featureGates:
      drift: true
    batchMaxDuration: 10s
    batchIdleDuration: 1s
