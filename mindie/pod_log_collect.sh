#!/bin/bash

# 获取当前时间，格式为 YYYY-MM-DD_HH-MM-SS
time=$(date +"%Y-%m-%d_%H-%M-%S")
log_dir="./mindie_cluster_log/log_${time}"

# 创建日志目录
mkdir -p "$log_dir"

# 获取所有 mindie-xxxx-xxxx 的 Pod 名称及其命名空间，请根据具体 Pod 名称调整
pods=$(kubectl get pods -A | grep "mindie-" | awk '{print $1 " " $2}')

# 检查是否找到匹配的 Pod
if [[ -z "$pods" ]]; then
    echo "未找到任何 mindie-xxxx-xxxx 的 Pod"
    exit 1
fi

# 循环处理每个 Pod
echo "$pods" | while read -r namespace podname; do
    # 设置日志文件路径
    logfile="${log_dir}/${podname}.log"

    # 打印当前操作信息
    echo "正在记录 Pod [$podname] (Namespace: $namespace) 的日志到 $logfile"

    # 启动 kubectl logs 并重定向日志到文件
    kubectl logs -f -n "$namespace" "$podname" | head -n 1000 > "$logfile" 2>&1 &
done

echo "日志记录启动完成。日志保存在 $log_dir"