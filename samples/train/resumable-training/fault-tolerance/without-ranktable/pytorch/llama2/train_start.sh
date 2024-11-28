#!/bin/bash
# default start shell path
DLS_USER_HOME_DIR="$(
  cd "$(dirname "$0")" || exit 1
  if [[ $? -eq 1 ]]; then
    exit 1
  fi
  pwd -P
)"
cd "$DLS_USER_HOME_DIR" || exit 1

# set pythonpath(especially for tensorflow)
export PYTHONPATH="$DLS_USER_JOB_DIR:$PYTHONPATH"
export PYTHONUNBUFFERED=1

mkdir -p /job/code/alllogs/$MINDX_TASK_ID/ttplogs
mkdir -p /job/code/alllogs/$MINDX_TASK_ID/trainlogs
mkdir -p /job/code/alllogs/$MINDX_TASK_ID/demo/

# env for breakpoint ckpt
export RESUME_MODE_ENABLE=1

export ASCEND_GLOBAL_LOG_LEVEL=1                                                    # 设置plog等级为info，应根据实际需要设计等级
# 日志保存路径可根据实际情况修改
export ASCEND_PROCESS_LOG_PATH=/job/code/alllogs/$MINDX_TASK_ID/plogs/$XDL_IP       # 设置plog保存路径，其中$MINDX_TASK_ID为ascend-operator注入的任务uid环境变量，$XDL_IP为任务yaml中写入的环境变量，status.hostIP
export TTP_LOG_PATH=/job/code/alllogs/$MINDX_TASK_ID/ttplogs/ttplog$XDL_IP-$RANK    # 设置ttp日志保存路径，其中$RANK为ascend-operator为pytorch框架注入的环境变量
export TRAIN_LOG_PATH=/job/code/alllogs/$MINDX_TASK_ID/trainlogs/$XDL_IP-$RANK      # 设置训练日志保存路径

export HCCL_ASYNC_ERROR_HANDLING=0                 # 当HCCL_ASYNC_ERROR_HANDLING为0时，表示关闭watchdog功能。如果开启watchdog功能，可能会影响进程级恢复的正常使用。
export GLOO_SOCKET_IFNAME=enp189s0f0               # 物理机上可以通信的网口，根据主节点高速网卡实际情况进行配置，如任务yaml中配置hostNetwork为false，则设置为eth0
export HCCL_SOCKET_IFNAME=enp189s0f0               # 如任务yaml中配置hostNetwork为false，则设置为eth0
export CUDA_DEVICE_MAX_CONNECTIONS=1
export INF_NAN_MODE_ENABLE=1
export NPU_ASD_ENABLE=0
export TTP_OT=360                                  # Torch框架等待CheckPoint保存时间，到时未保存完毕会强制退出进程。

# 是否开启编译缓存加速功能，可参考断点续训->特性说明->恢复时间优化（Pytorch）章节
#export ASCEND_CACHE_PATH=/job/code/complie        # 添加共享存储路径
#export ASCEND_MAX_OP_CACHE_SIZE=-1                # 使用共享存储时建议开启，可解决多节点读取共享存储缓存资源争抢严重问题

export PATH=$PATH:/usr/local/python3/bin
env |grep PROC
if [[ "${RANK}" -eq 0 ]]; then                     # 判断是否是rank,如是则设置其pod_ip为TTP_ADDR
  export TTP_ADDR=$POD_IP
else
  export TTP_ADDR=$MASTER_ADDR                     # 集群主节点的IP地址
fi
echo ${TTP_PORT}
echo ${TTP_ADDR}
LOAD_CHECKPOINT_PATH={设置ckpt保存目录}             # 设置ckpt保存目录  注意ckpt、权重、日志文件等应在yaml进行挂载到宿主机
SAVE_CHECKPOINT_PATH={设置ckpt保存目录}             # 设置ckpt保存目录
# 数据集路径如：DATA_PATH="/job/data/testcode/dataset/llama_text_document"
DATA_PATH={数据集路径}                                 # 配置数据集路径
# 词表路径如： TOKENIZER_MODEL="/job/data/testcode/dataset/llama/tokenizer.model"
TOKENIZER_MODEL={设置词表路径}                          # 配置词表路径
source /usr/local/Ascend/ascend-toolkit/set_env.sh

function check_npu_availability {
    i=0
    while [ $i -lt 10 ]; do
        npu_info=$(npu-smi info)
        if [[ $npu_info == *"command not found"* ]]; then
          echo "the container doesn't mount 'npu-smi' cmd, skip it now. you could mount 'npu-smi' cmd by yaml or
          ascend docker runtime"
          break
        elif [[ $npu_info == *"8020"* ]]; then
          echo "npu is busy, check again"
        else
          # npu maybe free
          break
        fi
        sleep 5
        let i++
    done

    if [ $i -eq 10 ]; then
      echo "npu is occupied by others too long, please release it"
      exit 1
    fi
}

function dls_get_executor {
    local filename="$(basename -- "$1")"
    local extension="${filename##*.}"
    extension="$(echo "$extension" | tr '[:upper:]' '[:lower:]')"
    case "$extension" in
    py|pyc|pyw|pyo|pyd)
        which python
        ;;
    sh)
        which bash
        ;;
    *)
        ;;
    esac
}

function set_env {
    local install_path=/usr/local/Ascend
    if [ -d ${install_path}/ascend-toolkit/latest ]; then
      # use toolkit env
      source ${install_path}/ascend-toolkit/set_env.sh
    elif [ -d ${install_path}/nnae/latest ]; then
      # use nnae env
      source ${install_path}/nnae/set_env.sh
    fi

    # use tfplugin env
    if [ -d ${install_path}/tfplugin/latest ]; then
      source ${install_path}/tfplugin/set_env.sh
    fi
}

function logger {
    echo "[$(date +%Y%m%d-%H:%M:%S)] [MindXDL Service Log]$*"
}

echo $@ |grep -q -E '^[ 0-9a-zA-Z,./:_=-]*$'
ret=$?
if [ "${ret}" -ne 0 ]; then
  echo "params error!"
  exit 1
fi

# training job input parameters
code_real_dir=`readlink -f $1`
if [ -d "${code_real_dir}" ]; then
    app_url="${code_real_dir}/"
fi
output_real_path=`readlink -f $2`
if [ -d "${output_real_path}" ]; then
    output_url="${output_real_path}"
else
    mkdir -p ${2}
    output_url="${2}"
fi
boot_file="$3"
shift 3

function show_help() {
  echo "Usage train_start.sh /job/code/resnet50 /tmp/output train.py"
}

function param_check() {
  if [ -z "${app_url}" ]; then
    echo "please input code dir"
    show_help
    exit 1
  fi

  if [ -L ${app_url} ]; then
    echo "code dir is a link!"
    exit 1
  fi

  if [ -z "${boot_file}" ]; then
    echo "please input boot file"
    show_help
    exit 1
  fi

  if [ -L ${boot_file} ]; then
    echo "boot file is a link!"
    exit 1
  fi

  if [ -z "${output_url}" ]; then
    echo "please input output url"
    show_help
    exit 1
  fi

  if [ -L ${output_url} ]; then
    echo "output url is a link!"
    exit 1
  fi

}

boot_file_path=${app_url}
params="$@"
train_param=${params%%need_freeze*}
if [[ $@ =~ need_freeze ]]; then
    freeze_cmd=${params##*need_freeze }
fi

param_check
chmod 640 ${output_url}

start_time=$(date +%Y-%m-%d-%H:%M:%S)
logger "Training start at ${start_time}"

sleep 1

if [[ "${LOCAL_WORLD_SIZE}" == "" ]]; then
    device_count=1
    server_count=1
else
    # 获取环境变量中的device_count字段
    device_count=${LOCAL_WORLD_SIZE}
    if [[ "${device_count}" -eq 0 ]]; then
      echo "device count is 0, train job failed." | tee -a hccl.log
      chmod 440 ${output_url}
      exit 1
    fi
    # 获取环境变量中的server_count字段
    server_count=`expr ${WORLD_SIZE} / ${LOCAL_WORLD_SIZE}`
    if [[ "${server_count}" == "" ]]; then
      echo "server count is 0, train job failed." | tee -a hccl.log
      chmod 440 ${output_url}
      exit 1
    fi
fi


DLS_PROGRAM_EXECUTOR="$(dls_get_executor "$boot_file")"
# set training env
set_env

# check npu status and wait some time if it is used by others
check_npu_availability

export JOB_ID=123456789


# 分布式场景
if [[ "${device_count}" -ge 1 ]]; then
  server_id=${RANK}
  logger "server id is: ""${server_id}"
  DISTRIBUTED_ARGS="--nproc_per_node $LOCAL_WORLD_SIZE --nnodes $server_count --node_rank $RANK --master_addr $MASTER_ADDR --master_port $MASTER_PORT"
  torchrun $DISTRIBUTED_ARGS ${boot_file_path}${boot_file} ${train_param} --tokenizer-model ${TOKENIZER_MODEL} --data-path $DATA_PATH --load ${LOAD_CHECKPOINT_PATH} --save ${SAVE_CHECKPOINT_PATH} 2>&1 |& tee -a ${TRAIN_LOG_PATH}
ST=${PIPESTATUS[0]}
if [[ ${ST} -ne 0 ]]; then
       logger "running job failed. exit code: ${ST}" | tee -a ${output_url}/log
      exit ${ST}
fi
fi

chmod 440 "${output_url}"