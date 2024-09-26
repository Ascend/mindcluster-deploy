#!/bin/bash

mode=$1

ASCEND_LOG_DIR="/var/log/ascend_log"
GROUP_NAME=${GROUP_NAME}
NODE_NAME=${HOST_IP}
# 日志转储执行脚本挂载路径
ASCEND_LOG_ROTATE_SCRIPT_DIR=${ASCEND_LOG_ROTATE_SCRIPT_DIR}

# 训练任务日志目录
log_dir="${ASCEND_LOG_DIR}/app_log/${GROUP_NAME}-$(date +%m%d-%H%M)/${NODE_NAME}"
# CANN单机独享文件的存储目录：包括CANN应用类日志、软件栈trace日志、算子输入dump文件等
ascend_work_path_dir="${log_dir}/ascend_work_path"
# CANN编译运行共享文件的存储目录：包括CANN算子编译缓存文件等
ascend_cache_path_dir="${log_dir}/ascend_cache_path"
# 用户训练打屏日志存储目录
train_log_dir="${log_dir}/train_log"
# NPU环境检查文件存储目录
environment_check_dir="${log_dir}/environment_check"
# OS系统日志存储目录
host_log_dir="${log_dir}/host_log"

# 采集脚本（可选）
npu_info_collect_script="${ASCEND_LOG_ROTATE_SCRIPT_DIR}/npu_info_collect.sh"
os_log_collect_script="${ASCEND_LOG_ROTATE_SCRIPT_DIR}/os_log_collect.py"

# 创建目录
function mkdir_log_dir() {
   echo "[INFO] Start to create log dir"
   mkdir -p "$log_dir" || { echo "[ERROR] Unable to create directory: $log_dir"; return 1; }
   mkdir -p "$ascend_work_path_dir" || { echo "[ERROR] Unable to create directory: $ascend_work_path_dir"; return 1; }
   mkdir -p "$ascend_cache_path_dir" || { echo "[ERROR] Unable to create directory: $ascend_cache_path_dir"; return 1; }
   mkdir -p "$train_log_dir" || { echo "[ERROR] Unable to create directory: $train_log_dir"; return 1; }
   mkdir -p "$environment_check_dir" || { echo "[ERROR] Unable to create directory: $environment_check_dir"; return 1; }
   mkdir -p "$host_log_dir" || { echo "[ERROR] Unable to create directory: $host_log_dir"; return 1; }
   echo "[INFO] Create log dir successfully"
}

# 设置环境变量
function set_env() {
    # 通过环境变量设置CANN单机独享文件的存储目录
    echo "[INFO] start export ASCEND_WORK_PATH=${ascend_work_path_dir}"
    export ASCEND_WORK_PATH="${ascend_work_path_dir}"

    # 通过环境变量设置CANN编译运行共享文件的存储目录
    echo "[INFO] start export ASCEND_CACHE_PATH=${ascend_cache_path_dir}"
    export ASCEND_CACHE_PATH="${ascend_cache_path_dir}"

    # 通过环境变量设置CANN应用类日志的存储目录
    echo "[INFO] start export ASCEND_PROCESS_LOG_PATH=${ascend_work_path_dir}/log"
    export ASCEND_PROCESS_LOG_PATH="${ascend_work_path_dir}/log"

    # 将用户训练打屏日志存储目录设置为环境变量，用于执行训练脚本时，重定向打屏日志
    echo "[INFO] start export TRAIN_LOG_DIR=${train_log_dir}"
    export TRAIN_LOG_DIR="${train_log_dir}"

    # 将训练任务日志目录设置为环境变量
    echo "[INFO] start export TEMP_LOG_DIR_PATH=${log_dir}"
    export TEMP_LOG_DIR_PATH="${log_dir}"
}

# 在训练开始前启动采集进程(可选操作)
function collection_before_training() {
    # 启动NPU环境检查文件进程
    echo "[INFO] start to collect npu info"
    if [[ -f ${npu_info_collect_script} ]]; then
        . "${npu_info_collect_script}" "${environment_check_dir}/npu_info_before.txt" &
    else
        echo "[WARN] The ${npu_info_collect_script} is no such file, collect npu info failed"
    fi

    # 启动OS日志采集进程
    echo "[INFO] start to collect os log"
    if [[ -f ${os_log_collect_script} ]]; then
	      python3 "${os_log_collect_script}" -i "/var/log/messages" -o "${host_log_dir}/messages" -t 5 &
    else
        echo "[WARN] The ${os_log_collect_script} is no such file, collect os log failed"
    fi
}

# 在训练结束后启动采集进程(可选操作)
function collection_after_training() {
    # 启动NPU环境检查文件进程
    echo "[INFO] start to collect npu info"
    if [[ -f ${npu_info_collect_script} ]]; then
        . "${npu_info_collect_script}" "${TEMP_LOG_DIR_PATH}/environment_check/npu_info_after.txt"
    else
        echo "[WARN] The ${npu_info_collect_script} is no such file, collect npu info failed"
    fi

    # 终止OS日志采集进程
    echo "[INFO] terminate os log collect processs"
    ps -ef | grep "os_log_collect.py" | grep -v grep | awk '{print $2}' | xargs kill -9
}

function main() {
    if [ $mode -eq 1 ]; then
      mkdir_log_dir
      set_env
      collection_before_training
    fi
    if [ $mode -eq 0 ]; then
      collection_after_training
    fi
}

main