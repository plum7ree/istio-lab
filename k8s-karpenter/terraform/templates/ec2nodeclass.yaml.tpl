apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: ${ami_family}
  
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${cluster_name}
  
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${cluster_name}
  
  role: ${node_role_arn}
  
  blockDeviceMappings:
%{ for device in block_device_mappings ~}
    - deviceName: ${device.device_name}
      ebs:
        volumeSize: ${device.ebs.volume_size}
        volumeType: ${device.ebs.volume_type}
        deleteOnTermination: ${device.ebs.delete_on_termination}
        encrypted: ${device.ebs.encrypted}
%{ endfor ~}
  
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 2
    httpTokens: required
  
  tags:
    Environment: production
    ManagedBy: Karpenter
    NodePool: default
