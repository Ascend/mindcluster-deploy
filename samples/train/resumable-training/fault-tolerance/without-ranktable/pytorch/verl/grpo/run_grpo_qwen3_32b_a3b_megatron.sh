set -x
export RAY_DEDUP_LOGS=0
export HYDRA_FULL_ERROR=1
export RAY_DEBUG=1
export PYTHONHASHSEED=0
export PYTHONUNBUFFERED=1
export VLLM_ASCEND_ENABLE_NZ=0
export TASK_QUEUE_ENABLE=1

project_name='GRPO-Qwen3'
exp_name='GRPO-Qwen3-32b-npu'
gen_tp=16
MODEL_PATH=/data/models/Qwen3-32B
CKPTS_DIR="/data/ckpt/Qwen3-32B-save/"
TRAIN_FILE="/data/datasets/gsm8k-new/train.parquet"
TEST_FILE="/data/datasets/gsm8k-new/test.parquet"
address="http://${MASTER_ADDR}:${DashboardPort}"
echo "address: ${address}"

offload=True
train_tp=8
train_pp=1

RUNTIME_ENV=recipe/fault_recover/config/runtime_env.yaml
ray job submit --no-wait --runtime-env="${RUNTIME_ENV}" \
    --address ${address} \
    -- python3 -m recipe.fault_recover.main_ppo --config-path=config \
    --config-name='fault_recover_ppo_megatron_trainer.yaml'\
    fault_manager.enable=True \
    fault_manager.max_reschedule_times=3 \
    algorithm.adv_estimator=grpo \
    data.train_files="${TRAIN_FILE}" \
    data.val_files="${TEST_FILE}" \
    data.train_batch_size=32 \
    data.max_prompt_length=2048 \
    data.max_response_length=2048 \
    data.filter_overlong_prompts=True \
    data.truncation='error' \
    data.shuffle=True \
    data.dataloader_num_workers=0 \
    actor_rollout_ref.model.path=${MODEL_PATH} \
    actor_rollout_ref.actor.optim.lr=1e-6 \
    actor_rollout_ref.model.use_remove_padding=True \
    actor_rollout_ref.actor.ppo_mini_batch_size=32 \
    actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.actor.checkpoint.async_save=False \
    actor_rollout_ref.actor.megatron.use_mbridge=False \
    actor_rollout_ref.actor.use_kl_loss=True \
    actor_rollout_ref.actor.entropy_coeff=0 \
    actor_rollout_ref.actor.kl_loss_coef=0.001 \
    actor_rollout_ref.actor.kl_loss_type=low_var_kl \
    actor_rollout_ref.actor.megatron.pipeline_model_parallel_size=${train_pp} \
    actor_rollout_ref.actor.megatron.tensor_model_parallel_size=${train_tp} \
    actor_rollout_ref.actor.megatron.param_offload=${offload} \
    actor_rollout_ref.actor.megatron.optimizer_offload=${offload} \
    actor_rollout_ref.actor.megatron.grad_offload=${offload} \
    actor_rollout_ref.ref.megatron.pipeline_model_parallel_size=${train_pp} \
    actor_rollout_ref.ref.megatron.tensor_model_parallel_size=${train_tp} \
    actor_rollout_ref.ref.megatron.param_offload=${offload} \
    actor_rollout_ref.rollout.log_prob_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.rollout.tensor_model_parallel_size=${gen_tp} \
    actor_rollout_ref.rollout.name=vllm \
    actor_rollout_ref.rollout.gpu_memory_utilization=0.4 \
    actor_rollout_ref.rollout.n=4 \
    actor_rollout_ref.rollout.enable_chunked_prefill=True \
    actor_rollout_ref.rollout.max_num_batched_tokens=4096 \
    actor_rollout_ref.ref.log_prob_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.actor.use_torch_compile=False \
    actor_rollout_ref.ref.use_torch_compile=False \
    +actor_rollout_ref.actor.megatron.override_transformer_config.ckpt_acceleration=True \
    +actor_rollout_ref.actor.megatron.override_transformer_config.use_flash_attn=True \
    ++actor_rollout_ref.ref.megatron.override_transformer_config.use_flash_attn=True \
    +actor_rollout_ref.actor.megatron.override_transformer_config.apply_rope_fusion=True \
    +actor_rollout_ref.actor.megatron.override_transformer_config.gradient_accumulation_fusion=True \
    +actor_rollout_ref.actor.megatron.override_transformer_config.use_fused_ring_attention_update=True \
    +actor_rollout_ref.actor.megatron.override_transformer_config.use_distributed_optimizer=True \
    +actor_rollout_ref.rollout.engine_kwargs.vllm.compilation_config.cudagraph_mode="FULL_AND_PIECEWISE" \
    algorithm.use_kl_in_reward=False \
    trainer.critic_warmup=0 \
    trainer.logger=['console','tensorboard'] \
    trainer.project_name="${project_name}" \
    trainer.experiment_name="${exp_name}" \
    trainer.n_gpus_per_node=16 \
    trainer.nnodes=2 \
    trainer.resume_from_path=checkpoints/ \
    trainer.default_local_dir=${CKPTS_DIR} \
    trainer.save_freq=1 \
    trainer.test_freq=-1 \
    trainer.total_epochs=1 \
    trainer.total_training_steps=6 \
    trainer.device=npu $@   2>&1 | tee /tmp/ray.output

ray_name=$(cat /tmp/ray.output | grep "submitted successfully" | awk -F "'" '{print $2}')
ray_name=${ray_name//\'}
mkdir -p $path_log_dir
echo "log dir is: $path_log_dir  ray_name is $ray_name"
cp $0 $path_log_dir/
nohup ray job logs -f $ray_name 2>&1 | tee $path_log_dir/grpo-qwen3-32b-a3-megatron.log &