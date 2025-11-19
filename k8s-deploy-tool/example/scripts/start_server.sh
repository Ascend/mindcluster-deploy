export VLLM_USE_V1=1
export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export LD_LIBRARY_PATH=/usr/local/Ascend/ascend-toolkit/latest/python/site-packages:$LD_LIBRARY_PATH

SERVER_PORT=8080

if [ "${ROLE_NAME}" = "prefill" ]; then
    DATA_PARALLEL_SIZE=$PREFILL_DP_SIZE
    TP_SIZE=$PREFILL_TP_SIZE
    KV_ROLE="kv_producer"
    ENGINE_ID=$ROLE_REPLICA_INDEX
    export HCCL_BUFFSIZE=1024
elif [ "${ROLE_NAME}" = "decode" ]; then
    DATA_PARALLEL_SIZE=$DECODE_DP_SIZE
    TP_SIZE=$DECODE_TP_SIZE
    KV_ROLE="kv_consumer"
    ENGINE_ID=$((PREFILL_NUM + ROLE_REPLICA_INDEX))
    export HCCL_BUFFSIZE=2048
fi

if [ "X$POD_GROUP_SIZE" = "X" ]; then
  DATA_PARALLEL_SIZE_LOCAL=$DATA_PARALLEL_SIZE
else
  DATA_PARALLEL_SIZE_LOCAL=$((DATA_PARALLEL_SIZE / POD_GROUP_SIZE))
fi

if [ "X$POD_GROUP_INDEX" = "X" ] || [ "X$POD_GROUP_INDEX" = "X0" ]; then
  DATA_PARALLEL_ADDRESS=$POD_IP
  DP_RANK_START=0
else
  DATA_PARALLEL_ADDRESS=${ROLESET_NAME}-${ROLE_NAME}-${ROLE_TEMPLATE_HASH}-${ROLE_REPLICA_INDEX}-0.${STORM_SERVICE_NAME}
  DP_RANK_START=$((DATA_PARALLEL_SIZE_LOCAL * POD_GROUP_INDEX))
fi

echo "DATA_PARALLEL_ADDRESS: $DATA_PARALLEL_ADDRESS"
echo "DATA_PARALLEL_SIZE_LOCAL: ${DATA_PARALLEL_SIZE_LOCAL}"
echo "DP_RANK_START: ${DP_RANK_START}"

KV_CONFIG_JSON=$(cat <<EOF
{
  "kv_connector": "MooncakeLayerwiseConnector",
  "kv_role": "${KV_ROLE}",
  "kv_port": "30000",
  "engine_id": "${ENGINE_ID}",
  "kv_connector_module_path": "vllm_ascend.distributed.mooncake_layerwise_connector",
  "kv_connector_extra_config": {
    "use_ascend_direct": true,
    "prefill": {
      "dp_size": ${PREFILL_DP_SIZE},
      "tp_size": ${PREFILL_TP_SIZE}
    },
    "decode": {
      "dp_size": ${DECODE_DP_SIZE},
      "tp_size": ${DECODE_TP_SIZE}
    }
  }
}
EOF
)

serve_prefill() {
  if [ "X$POD_GROUP_INDEX" = "X" ] || [ "X$POD_GROUP_INDEX" = "X0" ]; then
    echo "start master"
    vllm serve ${MODEL_PATH} \
        --host ${POD_IP} \
        --port ${SERVER_PORT} \
        --api-server-count 1 \
        --data-parallel-size ${DATA_PARALLEL_SIZE} \
        --data-parallel-size-local ${DATA_PARALLEL_SIZE_LOCAL}  \
        --data-parallel-address ${DATA_PARALLEL_ADDRESS} \
        --data-parallel-rpc-port 13389  \
        --tensor-parallel-size ${TP_SIZE} \
        --enable-expert-parallel \
        --seed 1024 \
        --enforce-eager \
        --distributed-executor-backend mp \
        --served-model-name ${MODEL_NAME} \
        --max-model-len 32768 \
        --max-num-batched-tokens 32768 \
        --trust-remote-code \
        --gpu-memory-utilization 0.9 \
        --kv-transfer-config "$KV_CONFIG_JSON"
  else
    echo "start worker"
    vllm serve ${MODEL_PATH} \
        --host ${POD_IP} \
        --port ${SERVER_PORT} \
        --headless \
        --api-server-count 1 \
        --data-parallel-size ${DATA_PARALLEL_SIZE} \
        --data-parallel-start-rank ${DP_RANK_START} \
        --data-parallel-size-local ${DATA_PARALLEL_SIZE_LOCAL} \
        --data-parallel-address ${DATA_PARALLEL_ADDRESS}  \
        --data-parallel-rpc-port 13389 \
        --tensor-parallel-size ${TP_SIZE} \
        --enable-expert-parallel \
        --seed 1024 \
        --enforce-eager \
        --distributed-executor-backend mp \
        --served-model-name ${MODEL_NAME}  \
        --max-model-len 32768 \
        --max-num-batched-tokens 32768 \
        --trust-remote-code \
        --gpu-memory-utilization 0.9 \
        --kv-transfer-config "$KV_CONFIG_JSON"
  fi
}

serve_prefill_multi_node() {
    vllm serve ${MODEL_PATH} \
        --host ${POD_IP} \
        --port $1 \
        --api-server-count 1 \
        --data-parallel-size ${DATA_PARALLEL_SIZE} \
        --data-parallel-rank $2 \
        --data-parallel-address ${DATA_PARALLEL_ADDRESS} \
        --data-parallel-rpc-port 13389 \
        --tensor-parallel-size ${TP_SIZE} \
        --enable-expert-parallel \
        --seed 1024 \
        --enforce-eager \
        --distributed-executor-backend mp \
        --served-model-name ${MODEL_NAME} \
        --max-model-len 32768 \
        --max-num-batched-tokens 32768 \
        --trust-remote-code \
        --gpu-memory-utilization 0.9 \
        --kv-transfer-config "$KV_CONFIG_JSON"
}

serve_decode() {
   if [ "X$POD_GROUP_INDEX" = "X" ] || [ "X$POD_GROUP_INDEX" = "X0" ]; then
      echo "start master"
      vllm serve ${MODEL_PATH} \
        --host ${POD_IP} \
        --port $SERVER_PORT \
        --api-server-count 1 \
        --data-parallel-size ${DATA_PARALLEL_SIZE} \
        --data-parallel-size-local ${DATA_PARALLEL_SIZE_LOCAL}  \
        --data-parallel-address ${DATA_PARALLEL_ADDRESS}  \
        --data-parallel-rpc-port 5964  \
        --tensor-parallel-size ${TP_SIZE} \
        --enable-expert-parallel \
        --seed 1024 \
        --distributed-executor-backend mp \
        --served-model-name ${MODEL_NAME}  \
        --max-model-len 32768 \
        --max-num-batched-tokens 512 \
        --max-num-seqs 16 \
        --trust-remote-code \
        --no-enable-prefix-caching \
        --gpu-memory-utilization 0.9 \
        --compilation-config '{"cudagraph_capture_sizes":[16]}' \
        --kv-transfer-config "$KV_CONFIG_JSON"
   else
    echo "start worker"
     vllm serve ${MODEL_PATH} \
       --host ${POD_IP} \
       --port $SERVER_PORT \
       --headless \
       --api-server-count 1 \
       --data-parallel-size ${DATA_PARALLEL_SIZE} \
       --data-parallel-start-rank ${DP_RANK_START} \
       --data-parallel-size-local ${DATA_PARALLEL_SIZE_LOCAL}  \
       --data-parallel-address ${DATA_PARALLEL_ADDRESS}  \
       --data-parallel-rpc-port 5964  \
       --tensor-parallel-size ${TP_SIZE} \
       --enable-expert-parallel \
       --seed 1024 \
       --distributed-executor-backend mp \
       --served-model-name ${MODEL_NAME}  \
       --max-model-len 32768 \
       --max-num-batched-tokens 512 \
       --max-num-seqs 16 \
       --trust-remote-code \
       --no-enable-prefix-caching \
       --gpu-memory-utilization 0.9 \
       --compilation-config '{"cudagraph_capture_sizes":[16]}' \
       --kv-transfer-config "$KV_CONFIG_JSON"
  fi
}

serve_decode_multi_node() {
    vllm serve ${MODEL_PATH} \
        --host ${POD_IP} \
        --port $1 \
        --api-server-count 1 \
        --data-parallel-size ${DATA_PARALLEL_SIZE} \
        --data-parallel-rank $2 \
        --data-parallel-address ${DATA_PARALLEL_ADDRESS} \
        --data-parallel-rpc-port 13389  \
        --tensor-parallel-size ${TP_SIZE} \
        --enable-expert-parallel \
        --seed 1024 \
        --distributed-executor-backend mp \
        --served-model-name ${MODEL_NAME} \
        --max-model-len 32768 \
        --max-num-batched-tokens 512 \
        --max-num-seqs 16 \
        --trust-remote-code \
        --no-enable-prefix-caching \
        --gpu-memory-utilization 0.9 \
        --compilation-config '{"cudagraph_capture_sizes":[16]}' \
        --kv-transfer-config "$KV_CONFIG_JSON"
}

wait_for_children() {
    local status=0
    local child_failed=0
    
    # Use wait -n to wait for any child process to exit, without waiting for all
    while true; do
        # Wait for any child process to exit and get its PID and exit status
        if wait -n 2>/dev/null; then
            local exit_code=$?
            local pid=$!
            echo "Child process $pid exited with code: $exit_code"
            
            # If child process exit code is non-zero, record and exit immediately
            if [ $exit_code -ne 0 ]; then
                echo "Error: Child process $pid exited abnormally with code: $exit_code"
                child_failed=1
                status=$exit_code
                break  # Exit loop immediately, don't wait for other child processes
            fi
        else
            # wait -n returns non-zero when no more child processes to wait for
            local wait_status=$?
            if [ $wait_status -eq 127 ]; then
                # 127 means no more child processes
                echo "All child processes have been processed"
                break
            else
                echo "wait -n returned status: $wait_status"
                break
            fi
        fi
    done
    
    # If any child process failed, kill all other child processes and return non-zero status
    if [ $child_failed -ne 0 ]; then
        echo "Terminating all other child processes immediately..."
        for pid in "${CHILD_PIDS[@]}"; do
            # Check if process is still running
            if kill -0 "$pid" 2>/dev/null; then
                echo "Killing child process: $pid"
                kill "$pid" 2>/dev/null
            fi
        done
        return $status
    else
        return 0
    fi
}

distributed_serve() {
  CHILD_PIDS=()

  for ((i=0; i<DATA_PARALLEL_SIZE_LOCAL; i++)); do
  {
      DP_RANK=$((DP_RANK_START + i))
      PORT=$((SERVER_PORT + i))
      start=$((i * TP_SIZE))
      end=$(( (i + 1) * TP_SIZE - 1 ))
      visible_devices=""
      for ((j=start; j<=end; j++)); do
          if [ -z "$visible_devices" ]; then
              visible_devices="$j"
          else
              visible_devices="$visible_devices,$j"
          fi
      done

      export ASCEND_RT_VISIBLE_DEVICES=$visible_devices
      echo "DP_RANK: ${DP_RANK}"
      echo "ASCEND_RT_VISIBLE_DEVICES: ${ASCEND_RT_VISIBLE_DEVICES}"

      if [ "${ROLE_NAME}" = "prefill" ]; then
      echo "start prefill, port: $PORT"
          serve_prefill_multi_node ${PORT} ${DP_RANK}
      elif [ "${ROLE_NAME}" = "decode" ]; then
      echo "start decode, port: $PORT"
          serve_decode_multi_node ${PORT} ${DP_RANK}
      else
          echo "Unknown ROLE_NAME: ${ROLE_NAME}"
          exit 1
      fi
  } &
  CHILD_PIDS+=($!)
  echo "Starting child process, PID: $!"
  done

  if ! wait_for_children; then
      CHILD_EXIT_STATUS=$?
      echo "Error: Some child processes exited abnormally, parent process will exit with code: $CHILD_EXIT_STATUS"
      exit $CHILD_EXIT_STATUS
  fi
}

standalone_serve() {
  if [ "${ROLE_NAME}" = "prefill" ]; then
        echo "start prefill, port: $SERVER_PORT"
        serve_prefill
  elif [ "${ROLE_NAME}" = "decode" ]; then
        echo "start decode, port: $SERVER_PORT"
        serve_decode
  else
        echo "Unknown ROLE_NAME: ${ROLE_NAME}"
        exit 1
  fi
}

if [ "${DISTRIBUTED_DP}" = "true" ]; then
    echo "start as DISTRIBUTED_DP"
    distributed_serve
else
    standalone_serve
fi