## 使用方法

### 1. 安装依赖

```
pip install -r requirements.txt
```

### (可选)2. 设置服务框架类型
当前仅支持ome，如果不设置，默认使用ome

```
export SERVING_FRAMEWORK=ome
```

### 3. 部署应用

```
python main.py deploy -c configs/isvc-config.yaml
```

### 4. 查看状态

```
python main.py status -n my-webapp -ns default
```

### 5. 删除应用

```
python main.py delete -n my-webapp -ns default
```

### 6. 试运行（不实际部署）

```
python main.py deploy -c config/isvc-config.yaml --dry-run
```

## 用户配置文件参数说明
```
app_name: "my-test"                                      # 应用名称，必填
app_namespace: "default"                                 # 应用命名空间，选填，默认值为"default"

inference_service:                                       # 推理服务配置，下属字段至少存在一个
  model_name: "llama-3-1-8b-instruct"                    # 模型名称，必填
  runtime_name: "llama-3-1-8b-rt"                        # 运行时名称，选填，如果不填，ome-controller-manager会根据model_name选取集群中存在的runtime
  engine:                                                # engine配置，下属字段至少存在一个。engine、decoder、router中的字段会被合并到runtime中，并且此处设置字段优先级更高
    min_replicas: 1                                      # 最小副本数，选填，默认值为1，当前要求大于0
    max_replicas: 1                                      # 最大副本数，选填，默认值为1，要求大于等于min_replicas
    pod_num: 1                                           # 实例pod数量，选填，默认值为1
    image: "sglang:11.11.1"                              # 容器镜像，选填，如果不填，会使用runtime中配置的image
    npu_num: 1                                           # 每个容器中的npu数量，选填，默认值为1
    labels:                                              # labels、annotations、node_selector、env_vars均为选填，如果存在，会覆盖runtime中配置的对应字段，此处xxx,yyy无实际意义，用户可以删除
      xxx: yyy
    annotations:
      xxx: yyy
    node_selector:
      xxx: yyy
    env_vars:
      xxx: yyy

    dp_size: 1                                           # dp_size、tp_size、pp_size为模型并行参数，选填，默认值为1，用户根据模型并行需求设置
    tp_size: 1
    pp_size: 1

  decoder:                                               # decoder配置，下属字段至少存在一个。
    ...                                                  # 其他参数与engine字段说明相同

  router:
    min_replicas: 1                                      # 最小副本数，选填，默认值为1，当前要求大于0
    max_replicas: 1                                      # 最大副本数，选填，默认值为1，要求大于等于min_replicas
    image: "sglang:11.11.1"                              # 容器镜像，选填，如果不填，会使用runtime中配置的image
    labels:                                              # labels、annotations、node_selector、env_vars均为选填，如果存在，会覆盖runtime中配置的对应字段，此处xxx,yyy无实际意义，用户可以删除
      xxx: yyy
    annotations:
      xxx: yyy
    node_selector:
      xxx: yyy  

mf_store:
  image: "sglang:test"                                   # mf_store镜像，选填，如果不填，会使用模板中的image
  replicas: 1                                            # mf_store副本数，选填，默认值为1，当前要求仅为1
  container_port: 9000                                   # mf_store服务端口，选填，默认值为9000
  env_vars:                                              # node_selector、env_vars均为选填，如果存在，会覆盖模板中配置的对应字段，此处xxx,yyy无实际意义，用户可以删除
    xxx: yyy
  node_selector:
    xxx: yyy
  resources:                                             # 资源配置
   requests:
     memory: "128Mi"
     cpu: "100m"
   limits:
     memory: "512Mi"
     cpu: "500m"

```

## python脚本参数说明
```
deploy: 部署应用
-c, --config: 配置文件路径，必填
-k, --kubeconfig: kubeconfig文件路径，选填，默认值为~/.kube/config
--dry-run: 试运行（不实际部署）
```

```
status: 查看应用状态
-n, --name: 应用名称，必填
-ns, --namespace: 应用命名空间，选填，默认值为"default"
-k, --kubeconfig: kubeconfig文件路径，选填，默认值为~/.kube/config
```

```
delete: 删除应用
-n, --name: 应用名称，必填
-ns, --namespace: 应用命名空间，选填，默认值为"default"
-k, --kubeconfig: kubeconfig文件路径，选填，默认值为~/.kube/config
```

## 模板文件说明
模板路径位于`src/templates/`目录下，用户可以自行修改模板文件，以适应不同的需求。用户可通过查看k8s或ome官方文档，了解模板文件中各个字段的含义。

## 安全说明
### 注意事项
该脚本依赖kubeconfig文件，kubeconfig文件中保存了集群的认证信息，请勿将kubeconfig文件泄露给他人。

### 日志说明
该脚本运行过程中，会生成日志文件，日志文件路径位于项目目录下的k8s_deploy_tool.log，日志文件中保存了脚本运行过程中的信息，请用户自行管理日志文件。

### 通信矩阵

| 源设备                                  | 源IP                              | 源端口                                   | 目的设备                        | 目的IP                                              | 目的端口（侦听）                              | 协议  | 端口说明                                                       | 侦听端口是否可更改 | 认证方式  | 加密方式    | 所属平面 | 版本   | 特殊场景 | 备注                                                                                                                     |
|--------------------------------------|----------------------------------|---------------------------------------|-----------------------------|---------------------------------------------------|---------------------------------------|-----|------------------------------------------------------------|-----------|-------|---------|------|------|------|------------------------------------------------------------------------------------------------------------------------|
| k8s-deploy-tool脚本运行节点                        | k8s-deploy-tool脚本运行节点窗口IP       | 动态端口32768~60999（默认范围，实际范围根据运行环境及配置变动） | K8s集群管理节点                   | K8s集群管理节点IP                                       | 6443/443（K8s集群内）                      | TCP | k8s-deploy-tool脚本作为客户端，访问K8s的api server                    | 是         | HTTPS | SSL/TLS | 业务平面 | 所有版本 | 无    | K8s api server默认https端口为6443，如果用户安装K8s时修改了该端口，请以实际为准；K8s集群内使用serviceaccount访问api server时，会访问对应的service，service端口默认为443 |
