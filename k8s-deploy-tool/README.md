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