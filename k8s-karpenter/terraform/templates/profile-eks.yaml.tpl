apiVersion: v1
kind: ConfigMap
metadata:
  name: karpenter-profile-eks
  namespace: karpenter-system
data:
  enabled: "true"
  clusterName: "${cluster_name}"
  nodeRole: "${node_role_arn}"
  instanceProfile: "${instance_profile}"
  environment: "eks"
  region: "${aws_region}"
  defaultNodePool: "default"
  defaultNodeClass: "default"
