source /usr/local/Ascend/ascend-toolkit/set_env.sh
source /usr/local/Ascend/nnal/atb/set_env.sh
export LD_LIBRARY_PATH=/usr/local/Ascend/nnal/atb/latest/atb/cxx_abi_0/lib:/usr/local/Ascend/nnal/atb/latest/atb/cxx_abi_0/examples:/usr/local/Ascend/nnal/atb/latest/atb/cxx_abi_0/tests/atbopstest:/usr/local/Ascend/ascend-toolkit/latest/tools/aml/lib64:/usr/local/Ascend/ascend-toolkit/latest/tools/aml/lib64/plugin:/usr/local/Ascend/ascend-toolkit/latest/lib64:/usr/local/Ascend/ascend-toolkit/latest/lib64/plugin/opskernel:/usr/local/Ascend/ascend-toolkit/latest/lib64/plugin/nnengine:/usr/local/Ascend/ascend-toolkit/latest/opp/built-in/op_impl/ai_core/tbe/op_tiling:/usr/local/Ascend/driver/lib64/common/:/usr/local/Ascend/driver/lib64/driver/:/usr/local/Ascend/nnal/atb/latest/atb/cxx_abi_0/lib:/usr/local/Ascend/nnal/atb/latest/atb/cxx_abi_0/examples:/usr/local/Ascend/nnal/atb/latest/atb/cxx_abi_0/tests/atbopstest:/usr/local/Ascend/ascend-toolkit/latest/tools/aml/lib64:/usr/local/Ascend/ascend-toolkit/latest/tools/aml/lib64/plugin:/usr/local/Ascend/ascend-toolkit/latest/lib64/plugin/nnengine:/usr/local/Ascend/ascend-toolkit/latest/opp/built-in/op_impl/ai_core/tbe/op_tiling/lib/linux/:/usr/local/Ascend/ascend-toolkit/latest/lib64:/usr/local/Ascend/ascend-toolkit/latest/lib64/plugin/opskernel:/usr/local/Ascend/driver/lib64/driver:/usr/local/Ascend/driver/lib64/common:/usr/local/lib::/usr/local/Ascend/driver/lib64/driver:/usr/local/Ascend/driver/lib64/common:/usr/local/lib::/usr/local/Ascend/ascend-toolkit/latest/aarch64-linux/devlib

SERVER_PORT=8080
PROXY_PORT=8080

dis_generate_hosts() {
    instant_num=$1
    pod_num=$2
    role=$3
    dp_size=$4
    declare -a arr=()

    for ((i=0; i<instant_num; i++)); do  # 修正：instant_num
        name="$STORM_SERVICE_NAME-$role-$i"
        if [[ $pod_num -eq 1 ]]; then  # 修正：添加空格
            type_name="$name"
            for ((k=0; k<dp_size; k++)); do
                echo "$type_name"
            done
        else
            for ((j=0; j<pod_num; j++)); do
                type_name="$name-${j}"
                for ((k=0; k<dp_size; k++)); do
                    echo "$type_name"
                done
            done
        fi
    done
}

dis_generate_ports() {
    instant_num=$1
    pod_num=$2
    dp_size=$3
    declare -a arr=()
    for ((i=0; i<instant_num; i++)); do
	     server_port=${SERVER_PORT}
	     for ((j=0; j<pod_num; j++)); do
            for ((k=0; k<dp_size; k++)); do
	             port=$(( server_port + k ))
	             echo "$port"
	          done
	     done
    done
}

generate_hosts() {
    instant_num=$1
    pod_num=$2
    role_name=$3 
    declare -a arr=()

    for ((i=0; i<instant_num; i++)); do
        if [[ $pod_num -eq 1 ]]; then  
            echo "$STORM_SERVICE_NAME-$role_name-$i"
        else
            echo "$STORM_SERVICE_NAME-$role_name-$i-0" 
        fi
    done
}

generate_ports() {
    instant_num=$1
    declare -a arr=()

    for ((i=0; i<instant_num; i++)); do
        echo "$SERVER_PORT"
    done
}


# 计算每个pod的DP大小
PREFILL_DP_SIZE_LOCAL=$((PREFILL_DP_SIZE / PREFILL_POD))
DECODE_DP_SIZE_LOCAL=$((DECODE_DP_SIZE / DECODE_POD))

if [[ $DISTRIBUTED_DP == "true" ]]; then
    PREFILLER_HOSTS=($(dis_generate_hosts ${PREFILL_NUM} ${PREFILL_POD} prefill ${PREFILL_DP_SIZE_LOCAL}))
    DECODER_HOSTS=($(dis_generate_hosts ${DECODE_NUM} ${DECODE_POD} decode ${DECODE_DP_SIZE_LOCAL}))

    PREFILLER_PORTS=($(dis_generate_ports ${PREFILL_NUM} ${PREFILL_POD} ${PREFILL_DP_SIZE_LOCAL}))
    DECODER_PORTS=($(dis_generate_ports ${DECODE_NUM} ${DECODE_POD} ${DECODE_DP_SIZE_LOCAL}))
else
    PREFILLER_HOSTS=($(generate_hosts ${PREFILL_NUM} ${PREFILL_POD} prefill))
    DECODER_HOSTS=($(generate_hosts ${DECODE_NUM} ${DECODE_POD} decode))

    PREFILLER_PORTS=($(generate_ports ${PREFILL_NUM}))
    DECODER_PORTS=($(generate_ports ${DECODE_NUM}))
fi 

echo "==================================="
echo "PREFILLER_HOSTS: ${PREFILLER_HOSTS[@]}"
echo "DECODER_HOSTS: ${DECODER_HOSTS[@]}"
echo "PREFILLER_PORTS: ${PREFILLER_PORTS[@]}"
echo "DECODER_PORTS: ${DECODER_PORTS[@]}"
echo "==================================="

python3 load_balance_proxy_layerwise_server_example.py \
        --host "$POD_IP" \
        --port "${PROXY_PORT}" \
        --prefiller-hosts "${PREFILLER_HOSTS[@]}" \
        --prefiller-port "${PREFILLER_PORTS[@]}" \
        --decoder-hosts "${DECODER_HOSTS[@]}" \
        --decoder-port "${DECODER_PORTS[@]}"