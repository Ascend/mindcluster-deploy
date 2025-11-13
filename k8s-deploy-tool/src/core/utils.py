from datetime import datetime

def print_dict(d, indent=0):
    """递归打印字典"""
    for key, value in d.items():
        print(' ' * indent + str(key) + ':', end=' ')
        if isinstance(value, dict):
            print()
            print_dict(value, indent + 4)
        else:
            print(value)
    

def format_duration(creation_timestamp):
    """将创建时间戳格式化为可读的持续时间"""
    if not creation_timestamp:
        return "Unknown"
    
    created = creation_timestamp.replace(tzinfo=None)
    now = datetime.utcnow()
    delta = now - created
    
    if delta.days > 0:
        return f"{delta.days}d"
    elif delta.seconds >= 3600:
        hours = delta.seconds // 3600
        return f"{hours}h"
    elif delta.seconds >= 60:
        minutes = delta.seconds // 60
        return f"{minutes}m"
    else:
        return f"{delta.seconds}s"

def print_pod_table(pods, wide=False):
    """以表格形式打印Pod信息"""
    if not pods:
        print("No pods found matching the criteria.")
        return
    
    # 表头
    if wide:
        print(f"{'NAME':<50} {'READY':<10} {'STATUS':<15} {'RESTARTS':<10} {'AGE':<10} {'IP':<20} {'NODE':<30}")
        print("-" * 150)
    else:
        print(f"{'NAME':<50} {'READY':<10} {'STATUS':<15} {'RESTARTS':<10} {'AGE':<10}")
        print("-" * 100)
    
    for pod in pods:
        ready_containers = 0
        total_containers = len(pod.status.container_statuses) if pod.status.container_statuses else 0
        
        for container_status in pod.status.container_statuses or []:
            if container_status.ready:
                ready_containers += 1
        
        ready_str = f"{ready_containers}/{total_containers}"

        status = pod.status.phase
        if pod.metadata.deletion_timestamp is not None:
            status = "Terminating"
        if pod.status.container_statuses:
            for container_status in pod.status.container_statuses:
                if container_status.state.waiting:
                    status = f"Waiting:{container_status.state.waiting.reason}"
                elif container_status.state.terminated:
                    status = f"Terminated:{container_status.state.terminated.reason}"
        
        restart_count = 0
        for container_status in pod.status.container_statuses or []:
            restart_count += container_status.restart_count
        
        age = format_duration(pod.metadata.creation_timestamp)
        
        if wide:
            pod_ip = pod.status.pod_ip or "<none>"
            node_name = pod.spec.node_name or "<none>"
            print(f"{pod.metadata.namespace}/{pod.metadata.name:<45} {ready_str:<10} {status:<15} {restart_count:<10} {age:<10} {pod_ip:<20} {node_name:<30}")
        else:
            print(f"{pod.metadata.namespace}/{pod.metadata.name:<45} {ready_str:<10} {status:<15} {restart_count:<10} {age:<10}")