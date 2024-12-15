source /root/.bashrc
export LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64:/usr/local/Ascend/driver/lib64/common:/usr/local/Ascend/driver/lib64/driver:$LD_LIBRARY_PATH

export MS_COMPILER_CACHE_ENABLE=1
export MS_COMPILER_CACHE_PATH=/job/code/cache
source /usr/local/Ascend/driver/bin/setenv.bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh

unset RANK_TABLE_FILE
export GlOG_v=2
export MS_ENABLE_TFT="{TTP:1 UCE:1}"  # 开启uce功能场景下设置
export MINDIO_FOR_MINDSPORE=1
export HCCL_DETERMINISTIC=true
export ASCEND_LAUNCH_BLOCKING=1
export ASCEND_GLOBAL_LOG_LEVEL=1

export  HCCL_SOCKET_IFNAME=enp189s0f0
export  GLOO_SOCKET_IFNAME=enp189s0f0
export MS_DEV_SIDE_EFFECT_LOAD_ELIM=3

export WORLD_SIZE=$MS_WORKER_NUM
export LOGLEVEL=1

# 日志目录
export ASCEND_PROCESS_LOG_PATH=/job/code/mindformers/output/plog
msrun_log=/job/code/mindformers/output/msrun_log/

# 配置、脚本文件
config_yaml=/job/code/mindformers/configs/llama2/pretrain_llama2_70b_bf16_32p.yaml
msrun_launcher=/job/code/mindformers/scripts/msrun_launcher.sh
reset_process=/job/code/mindformers/scripts/reset_process.py

rm -rf $ASCEND_PROCESS_LOG_PATH
rm -rf $msrun_log

# 使用共享存储
USE_NFS=false
# 多节点
MULTI_NODE=true

# 开启uce功能场景下设置，替换yaml文件中ctrl_ip的值
if [ $USE_NFS -ne true ] || [ $MULTI_NODE -ne true ] || [ $MS_NODE_RANK -eq 1 ]; then
   sed -i "s#\(ctrl_ip:\).*#\1 \"$MS_SCHED_HOST\"#g" "$config_yaml"
fi

# 拉起训练进程，获取进程号
source $msrun_launcher "python -u run_mindformer.py --config $config_yaml --run_mode train" $MS_WORKER_NUM $MS_LOCAL_WORKER $MS_SCHED_HOST $MS_SCHED_PORT $MS_NODE_RANK $msrun_log True 300

msrun_pid=$MSRUN_PID_NUM_SELF
train_pids=$MSRUN_TRAINING_PID_NUM_SELF

python -u $reset_process -p "${train_pids[@]}" -r &
reset_pid=$!
wait $msrun_pid
exit_code=$?
if [ ${exit_code} -eq 0 ]; then
   kill -15 ${reset_pid}
   echo "training finished"
   exit ${exit_code}
else
   wait ${reset_pid}
fi