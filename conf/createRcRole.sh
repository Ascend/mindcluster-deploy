#! /bin/bash
#  Copyright (C)  2021-2023. Huawei Technologies Co., Ltd. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# run this shell like this : bash createKubeConfig.sh https://masterip:port
set -e

function createRoleBinding() {
  #resilience-controller
  kubectl delete clusterrolebinding resilience-controller-clusterrolebinding || true
  kubectl create clusterrolebinding resilience-controller-clusterrolebinding --clusterrole=resilience-controller-role \
  --user=resilience-controller
}

function createRole() {
  #resilience-controller
  kubectl delete clusterrole resilience-controller-role || true
  creatRCRole
}

function creatRCRole() {
    cat <<EOF | kubectl apply -f -
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: resilience-controller-role
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["list"]
  - apiGroups: ["batch.volcano.sh"]
    resources: ["jobs"]
    verbs: ["get", "list", "create", "watch", "delete"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get"]
EOF
}

createRole
echo "clusterrole create successfully"
createRoleBinding
echo "createRoleBinding create successfully"
