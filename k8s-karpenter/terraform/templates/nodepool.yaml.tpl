apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        workload-type: general
        environment: production
      annotations:
        karpenter.sh/do-not-evict: "false"
    spec:
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1beta1
        kind: EC2NodeClass
        name: ${node_class_name}
      
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        
        - key: node.kubernetes.io/instance-type
          operator: In
          values:
%{ for type in instance_types ~}
            - ${type}
%{ endfor ~}
        
        - key: topology.kubernetes.io/zone
          operator: In
          values:
%{ for az in availability_zones ~}
            - ${az}
%{ endfor ~}
        
        - key: karpenter.sh/capacity-type
          operator: In
          values:
            - on-demand
  
  limits:
    cpu: "${cpu_limit}"
    memory: ${memory_limit}
  
  disruption:
    consolidateAfter: 30s
    consolidatePolicy: WhenUnderutilized
    expireAfter: 720h
  
  weight: 100
