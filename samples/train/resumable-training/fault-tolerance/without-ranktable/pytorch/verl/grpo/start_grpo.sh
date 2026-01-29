export RAY_DEDUP_LOGS=0
export PYTHONPATH=$PYTHONPATH:/data/code/Megatron-LM # modify according to actual situation

unset https_proxy http_proxy
export HCCL_SOCKET_IFNAME=eth0 # modify according to actual situation
export TP_SOCKET_IFNAME=eth0   # modify according to actual situation
export GLOO_SOCKET_IFNAME=eth0 # modify according to actual situation

source /usr/local/Ascend/driver/bin/setenv.bash;
source /usr/local/Ascend/ascend-toolkit/set_env.sh
source /usr/local/Ascend/nnal/atb/set_env.sh

export LD_PRELOAD=/usr/local/lib/libjemalloc.so.2
export VLLM_ASCEND_ENABLE_NZ=0
export HCCL_HOST_SOCKET_PORT_RANGE="60000-60050"
export HCCL_NPU_SOCKET_PORT_RANGE="61000-61050"

unset LOCAL_RANK

#export ASCEND_GLOBAL_LOG_LEVEL=1
export ASCEND_LAUNCH_BLOCKING=0

server_count=`expr ${WORLD_SIZE} / ${LOCAL_WORLD_SIZE}`
export NPU_PER_NODE=${LOCAL_WORLD_SIZE}  # A3 NPU Number
export NNODES=$server_count         # example is 2 Nodes

export path_log_dir=/data/logs/$MINDX_TASK_ID/trainlog  # modify according to actual situation
export ASCEND_PROCESS_LOG_PATH=/data/logs/$MINDX_TASK_ID/plog # modify according to actual situation

ray stop --force
rm -rf /tmp

export ServerPort=6666     # modify according to actual situation
export DashboardPort=8888  # modify according to actual situation

cnt=0
if [ "$REPLICA_TYPE" = "Master" ]; then
  # head start
  echo "This is head node"
  export TORCH_DEVICE_BACKEND_AUTOLOAD=0
  export CURRENT_IP=$(ifconfig $TP_SOCKET_IFNAME | grep -Eo 'inet (addr:)?([0-9]{1,3}\.){3}[0-9]{1,3}' | awk '{print $NF}')
  echo "CURRENT_IP=$CURRENT_IP"

  ray start --head --port $ServerPort --dashboard-port=$DashboardPort --node-ip-address=$CURRENT_IP --dashboard-host=$CURRENT_IP --disable-usage-stats --dashboard-agent-listen-port=52366

  while [[ $cnt -lt 10 ]]; do
    ray_status_output=$(ray status)
    npu_count=$(echo "$ray_status_output" | grep -oP '(?<=/)\d+\.\d+(?=\s*NPU)' | head -n 1)
    npu_count_int=$(echo "$npu_count" | awk '{print int($1)}')

    # judge npu_count_int bigger than NNODES*NPU_PER_NODE
    if [ "$npu_count_int" -ge "$((NNODES*NPU_PER_NODE))" ]; then
      echo "Ray cluster is ready with $npu_count_int npu (from $npu_count NPU resources), starting Python script."
      ray status
      bash run_grpo_qwen3_32b_a3b_megatron.sh
      break
    fi

    echo "Waiting for Ray to allocate $((NNODES*NPU_PER_NODE)) devices. Current device count: $npu_count_int"
    cnt=$((cnt+1))
    sleep 5
  done

else
  echo "This is worker node"
  ray start --address="$MASTER_ADDR:$ServerPort" --disable-usage-stats
fi

cnt=0
while true; do
  ray_name=$(ray job list | grep -o "raysubmit_[a-zA-Z0-9]*")
  if [[ -n $ray_name ]]; then
    echo "Job $ray_name start succeeded"
    break
  fi

  cnt=$((cnt+1))
  if [[ $cnt -gt 10 ]]; then
    echo "Job $ray_name start failed"
    ray stop --force
    rm -rf /tmp
    exit 1
  fi

  sleep 10
done

ray_name=$(ray job list | grep -o "raysubmit_[a-zA-Z0-9]*")
while true; do
  output=$(ray job status $ray_name)
  failed=$(echo $output | grep $ray_name | grep -i failed)
  succeeded=$(echo $output | grep $ray_name | grep -i succeeded)
  gcs_error=$(echo $output | grep -i 'Failed to get cluster ID from GCS server')

  if [[ -n $gcs_error ]]; then
    echo "ray cannot connect，Job $ray_name exit with exception"
    ray stop --force
    rm -rf /tmp
    exit 1
  fi


  if [[ -n $succeeded ]]; then
    ray stop --force
    rm -rf /tmp
    echo "Job $ray_name exit without exception"
    exit 0
  fi

  if [[ -n $failed ]]; then
    echo "Job $ray_name exit with exception"
    ray stop --force
    rm -rf /tmp
    exit 1
  fi

  sleep 10
done
