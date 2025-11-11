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

# NPU env
source /usr/local/Ascend/mindie/set_env.sh
source /usr/local/Ascend/ascend-toolkit/set_env.sh
source /usr/local/Ascend/nnal/atb/set_env.sh
source /usr/local/Ascend/atb-models/set_env.sh

if [[ -z "${MIES_INSTALL_PATH}" ]]; then
    export MIES_INSTALL_PATH=/usr/local/Ascend/mindie/latest/mindie-service
fi
echo "MIES_INSTALL_PATH: ${MIES_INSTALL_PATH}"

# log config
export MINDIE_LOG_TO_STDOUT=1  # MindIE日志打印到标准输出
export MINDIE_LOG_TO_FILE=1 # MindIE日志打印到文件

mkdir -p /job/script/alllog/
INFER_LOG_PATH=/job/script/alllog/output_$(date +%Y%m%d_%H%M%S).log

# config.json
export MIES_CONFIG_JSON_PATH=/job/script/config.json

function chmod_mindie_server_path {
  chmod 750 $MIES_INSTALL_PATH
  chmod -R 550 $MIES_INSTALL_PATH/bin
  chmod -R 500 $MIES_INSTALL_PATH/bin/mindie_llm_backend_connector
  chmod 550 $MIES_INSTALL_PATH/lib
  chmod 440 $MIES_INSTALL_PATH/lib/*
  chmod 550 $MIES_INSTALL_PATH/lib/grpc
  chmod 440 $MIES_INSTALL_PATH/lib/grpc/*
  chmod -R 550 $MIES_INSTALL_PATH/include
  chmod -R 550 $MIES_INSTALL_PATH/scripts
  chmod 750 $MIES_INSTALL_PATH/logs
  chmod 750 $MIES_INSTALL_PATH/conf
  chmod 640 $MIES_INSTALL_PATH/conf/config.json
  chmod 700 $MIES_INSTALL_PATH/security
  chmod -R 700 $MIES_INSTALL_PATH/security/*

  chmod 640 $MIES_CONFIG_JSON_PATH
}

chmod_mindie_server_path

function logger {
    echo "[$(date +%Y%m%d-%H:%M:%S)] [EntryPoint Script Log]$*"
}

cur_restart_times=0
max_restart_times="${1:-0}"
if [[ "$max_restart_times" =~ ^[0-9]+$ ]]; then
  logger "max_restart_times is $max_restart_times" | tee -a ${INFER_LOG_PATH}
else
  logger "max_restart_times param type error: $max_restart_times" | tee -a ${INFER_LOG_PATH}
  exit 1
fi

cd $MIES_INSTALL_PATH

while true; do
  ./bin/mindieservice_daemon 2>&1 |& tee -a ${INFER_LOG_PATH}
  ST=${PIPESTATUS[0]}
  if [[ ${ST} -ne 0 ]]; then
    logger "running job failed. exit code: ${ST}" | tee -a ${INFER_LOG_PATH}
    if [[ $cur_restart_times -ge $max_restart_times ]]; then
      logger "reach max restart times, cur: $cur_restart_times, max: $max_restart_times" | tee -a ${INFER_LOG_PATH}
      exit ${ST}
    else
      logger "restart mindie service daemon, cur: $cur_restart_times, max: $max_restart_times" | tee -a ${INFER_LOG_PATH}
      ((cur_restart_times++))
      find /dev/shm -name '*llm_backend_*' -type f -delete
      find /dev/shm -name 'llm_tokenizer_shared_memory_*' -type f -delete
    fi
  else
    logger "job completed!" | tee -a ${INFER_LOG_PATH}
    exit 0
  fi
done
