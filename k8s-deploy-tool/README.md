## 使用方法

### 1. 安装依赖

```
pip install -r requirements.txt
```

### (可选)2. 设置服务框架类型
当前支持ome和aibrix，如果不设置，默认使用ome

```
export SERVING_FRAMEWORK=ome
```

### 3. 部署应用

```
python main.py deploy -c config/isvc-config.yaml
参数说明：
-c, --config: 配置文件路径，必填
-k, --kubeconfig: kubeconfig文件路径，选填，默认值为~/.kube/config
--dry-run: 试运行（不实际部署），选填
```

### 4. 查看状态

```
python main.py status -n my-test -ns default
参数说明：
-n, --app-name: 应用名称，必填
-ns, --namespace: 应用命名空间，选填，默认值为"default"
-k, --kubeconfig: kubeconfig文件路径，选填，默认值为~/.kube/config
```

### 5. 删除应用

```
python main.py delete -n my-test -ns default
参数说明：
-n, --app-name: 应用名称，必填
-ns, --namespace: 应用命名空间，选填，默认值为"default"
-k, --kubeconfig: kubeconfig文件路径，选填，默认值为~/.kube/config
```

### 6. 试运行（不实际部署）

```
python main.py deploy -c config/isvc-config.yaml --dry-run
参数说明：
-c, --config: 配置文件路径，必填
-k, --kubeconfig: kubeconfig文件路径，选填，默认值为~/.kube/config
--dry-run: 试运行（不实际部署）
```

## 模板文件说明
模板路径位于`src/templates/`目录下，用户可以自行修改模板文件，以适应不同的需求。用户可通过查看k8s、ome或aibrix官方文档，了解模板文件中各个字段的含义。

## 安全说明
### 注意事项
该脚本依赖kubeconfig文件，kubeconfig文件中保存了集群的认证信息，请勿将kubeconfig文件泄露给他人。

### 日志说明
该脚本运行过程中，会生成日志文件，日志文件路径位于项目目录下的k8s_deploy_tool.log，日志文件中保存了脚本运行过程中的信息，请用户自行管理日志文件。

### 环境变量说明
该脚本支持通过环境变量"SERVING_FRAMEWORK"设置服务框架类型，当前支持ome和aibrix，如果不设置，默认使用ome。

### 通信矩阵

| 源设备                                  | 源IP                              | 源端口                                   | 目的设备                        | 目的IP                                              | 目的端口（侦听）                              | 协议  | 端口说明                                                       | 侦听端口是否可更改 | 认证方式  | 加密方式    | 所属平面 | 版本   | 特殊场景 | 备注                                                                                                                     |
|--------------------------------------|----------------------------------|---------------------------------------|-----------------------------|---------------------------------------------------|---------------------------------------|-----|------------------------------------------------------------|-----------|-------|---------|------|------|------|------------------------------------------------------------------------------------------------------------------------|
| k8s-deploy-tool脚本运行节点                        | k8s-deploy-tool脚本运行节点窗口IP       | 动态端口32768~60999（默认范围，实际范围根据运行环境及配置变动） | K8s集群管理节点                   | K8s集群管理节点IP                                       | 6443/443（K8s集群内）                      | TCP | k8s-deploy-tool脚本作为客户端，访问K8s的api server                    | 是         | HTTPS | SSL/TLS | 业务平面 | 所有版本 | 无    | K8s api server默认https端口为6443，如果用户安装K8s时修改了该端口，请以实际为准；K8s集群内使用serviceaccount访问api server时，会访问对应的service，service端口默认为443 |
