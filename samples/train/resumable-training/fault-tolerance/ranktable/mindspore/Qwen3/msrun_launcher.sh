#!/bin/bash
# Copyright 2025 Huawei Technologies Co., Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================

# msrun Default Parameters

# 各日志等级及路径按需配置
export HCCL_ASYNC_ERROR_HANDLING=0
# export ASCEND_GLOBAL_LOG_LEVEL=1
export LOGLEVEL=DEBUG
# export HCCL_ENTRY_LOG_ENABLE=1
export HCCL_CONNECT_TIMEOUT=600

# 物理机上可以通信的网口，根据主节点高速网卡实际情况进行配置，如任务YAML中配置hostNetwork为false，则设置为eth0。示例仅供参考，请根据实际情况修改
export GLOO_SOCKET_IFNAME=enp194s0f0
# 如任务YAML中配置hostNetwork为false，则设置为eth0。示例仅供参考，请根据实际情况修改
export HCCL_SOCKET_IFNAME=enp194s0f0
# 配置集合通信起始端口，预防该端口被占用
export HCCL_IF_BASE_PORT=64000

export MS_TFT_IP=$MS_SCHED_HOST                # 配置MindSpore所用MindIO controller地址
export MS_TFT_PORT=8000                        # 配置MindSpore所用MindIO controller端口
export HCCL_OP_RETRY_ENABLE="L0:0, L1:1, L2:1"  # 设置HCCL算子不同层级(L0/L1/L2)的重执行开关状态。重执行是指当通信算子执行报SDMA或者RDMA CQE类型的错误时，HCCL会尝试重新执行此通信算子。

# 以任务id分类，生成各类日志文件夹等
mkdir -p /job/code/alllogs/${MINDX_TASK_ID}
mkdir -p /job/code/alllogs/${MINDX_TASK_ID}/traininglog/log-print/
mkdir -p /job/code/output/checkpoint
export GLOG_v=2
export GLOG_log_dir=/job/code/alllogs/${MINDX_TASK_ID}/traininglog/msrun
export LOG_MF_PATH=/job/code/alllogs/${MINDX_TASK_ID}/traininglog/mf/log$MF_LOG_SUFFIX
# Add the suffix to the msrun_log
LOG_DIR=/job/code/alllogs/${MINDX_TASK_ID}/traininglog/log-output/$MF_LOG_SUFFIX
export ASCEND_PROCESS_LOG_PATH=/job/code/alllogs/$MINDX_TASK_ID/plogs/$MS_NODE_RANK     #设置plog落盘路径
export TTP_LOG_PATH=/job/code/alllogs/$MINDX_TASK_ID/ttplogs/$MS_NODE_RANK
export TRAIN_LOG_PATH=/job/code/alllogs/$MINDX_TASK_ID/trainlogs/$MS_NODE_RANK

source /usr/local/Ascend/ascend-toolkit/set_env.sh

WORKER_NUM=$MS_WORKER_NUM
LOCAL_WORKER=$MS_LOCAL_WORKER
MASTER_ADDR=$MS_SCHED_HOST
MASTER_PORT=$MS_SCHED_PORT
NODE_RANK=$MS_NODE_RANK
JOIN="True"
CLUSTER_TIME_OUT=7200

# Set PYTHONPATH
MF_SCRIPTS_ROOT=$(realpath "$(dirname "$0")")
export PYTHONPATH=$MF_SCRIPTS_ROOT/../:$PYTHONPATH

# Set the log suffix
if [ -z "${MF_LOG_SUFFIX+x}" ] || [ "$MF_LOG_SUFFIX" == "" ]
then
  MF_LOG_SUFFIX=$MF_LOG_SUFFIX
else
  MF_LOG_SUFFIX=_$MF_LOG_SUFFIX
fi

if [ $# != 1 ] && [ $# != 2 ] && [ $# != 6 ] && [ $# != 9 ]
then
  echo "Usage Help: bash msrun_launcher.sh [EXECUTE_ORDER] For Default 8 Devices In Single Machine"
  echo "Usage Help: bash msrun_launcher.sh [EXECUTE_ORDER] [WORKER_NUM] For Quick Start On Multiple Devices In Single Machine"
  echo "Usage Help: bash msrun_launcher.sh [EXECUTE_ORDER] [WORKER_NUM] [MASTER_PORT] [LOG_DIR] [JOIN] [CLUSTER_TIME_OUT] For Multiple Devices In Single Machine"
  echo "Usage Help: bash msrun_launcher.sh [EXECUTE_ORDER] [WORKER_NUM] [LOCAL_WORKER] [MASTER_ADDR] [MASTER_PORT] [NODE_RANK] [LOG_DIR] [JOIN] [CLUSTER_TIME_OUT] For Multiple Devices In Multiple Machines"
  exit 1
fi

# Start Without Parameters For 8 Devices On Single Machine
if [ $# == 1 ]
then
  echo "No parameter is entered. Notice that the program will run on default 8 cards. "
  SINGLE_NODE=false
else
  WORKER_NUM=$MS_LOCAL_WORKER
fi

# Check WORKER_NUM
if [[ ! $WORKER_NUM =~ ^[0-9]+$ ]]; then
    echo "error: worker_num=$WORKER_NUM is not a number"
    exit 1
fi

# Quick Start For Multiple Devices On Single Machine
if [ $# == 2 ]
then
  LOCAL_WORKER=$WORKER_NUM
  SINGLE_NODE=true
fi

# Multiple Devices On Single Machine
if [ $# == 6 ]
then
  LOCAL_WORKER=$WORKER_NUM
  MASTER_PORT=$3
  LOG_DIR=$4
  JOIN=$5
  CLUSTER_TIME_OUT=$6

  SINGLE_NODE=true
fi

# Multiple Devices On Multiple Machine
if [ $# == 9 ]
then
  LOCAL_WORKER=$3
  MASTER_ADDR=$4
  MASTER_PORT=$5
  NODE_RANK=$6
  LOG_DIR=$7
  JOIN=$8
  CLUSTER_TIME_OUT=$9

  if [ $WORKER_NUM == $LOCAL_WORKER ]
  then
    echo "worker_num is equal to local_worker, Notice that task will run on single node."
    SINGLE_NODE=true
  else
    echo "worker_num=$WORKER_NUM, local_worker=$LOCAL_WORKER, \
     Please run this script on other nodes with different node_rank."
    SINGLE_NODE=false
  fi
fi
ulimit -u unlimited
# Init msrun Command
if [ $SINGLE_NODE == true ]
then
     msrun --worker_num=$WORKER_NUM \
         --local_worker_num=$LOCAL_WORKER \
         --master_port=$MASTER_PORT \
         --log_dir=$LOG_DIR \
         --join=$JOIN \
         --cluster_time_out=$CLUSTER_TIME_OUT $1 2>&1  |& tee -a /job/code/alllogs/${MINDX_TASK_ID}/traininglog/log-print/node-$MS_NODE_RANK
else
     msrun --worker_num=$WORKER_NUM \
         --local_worker_num=$LOCAL_WORKER \
         --master_addr=$MASTER_ADDR \
         --master_port=$MASTER_PORT \
         --node_rank=$NODE_RANK \
         --log_dir=$LOG_DIR \
         --join=$JOIN \
         --cluster_time_out=$CLUSTER_TIME_OUT $1 2>&1  |& tee -a /job/code/alllogs/${MINDX_TASK_ID}/traininglog/log-print/node-$MS_NODE_RANK
fi

ST=${PIPESTATUS[0]}
if [[ ${ST} -ne 0 ]]; then
    echo "process exit with exitcode:${ST}"
    logger "running job failed. exit code: $ret" | tee -a ${output_url}/log
    exit ${ST}
fi