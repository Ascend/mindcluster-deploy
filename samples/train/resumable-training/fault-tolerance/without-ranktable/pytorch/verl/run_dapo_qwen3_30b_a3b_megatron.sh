#!/usr/bin/env bash
set -xeuo pipefail
# This example is qwen3 30B moe model, RL algo is DAPO, train backend is megatron.
# train servers are A3, 2 nodes.
project_name='DAPO'
exp_name='dapo-qwen3-30b-a3-megatron'
RUNTIME_ENV=examples_npu/config/runtime_env.yaml # modify according to actual situation

adv_estimator=grpo

use_kl_in_reward=False
kl_coef=0.0
use_kl_loss=False
kl_loss_coef=0.0

clip_ratio_low=0.2
clip_ratio_high=0.28

enable_filter_groups=True
max_num_gen_batches=0
filter_groups_metric=acc
max_prompt_length=$((128))
max_response_length=$((128))

enable_overlong_buffer=True
overlong_buffer_len=$((128 * 1))
overlong_penalty_factor=0.1

loss_agg_mode="token-mean"

train_prompt_bsz=64
gen_prompt_bsz=$((train_prompt_bsz * 2))
n_resp_per_prompt=1
train_prompt_mini_bsz=32

NNODES=${NNODES:-2}
NPU_PER_NODE=${NPU_PER_NODE:-16}

WORKING_DIR=${WORKING_DIR:-"${PWD}"}
MODEL_PATH="/home/qwen30b/Qwen3-30B-A3B-Instruct-2507" # modify according to actual situation
MCORE_MODEL_PATH="/home/qwen30b/Qwen3-30B-A3B-GPU" # modify according to actual situation
RAY_DATA_HOME=${RAY_DATA_HOME:-"${HOME}/verl"}
CKPTS_DIR="/home/qwen30b/ckpt" # modify according to actual situation

TRAIN_FILE="/home/DAPO-Math-17k/data/dapo-math-17k.parquet" # modify according to actual situation
TEST_FILE="/home/DAPO-Math-17k/data/dapo-math-17k.parquet" # modify according to actual situation

# Algorithm
temperature=1.0
top_p=1.0
top_k=-1 # 0 for HF rollout, -1 for vLLM rollout
val_top_p=0.7

offload=True
gen_tp=2
gen_dp=8
gen_world_size=$((NNODES*NPU_PER_NODE)) # nnodes* npus_in_per_node

train_tp=4
train_ep=2
train_pp=2
train_cp=2
export PYTHONUNBUFFERED=1

ray job submit --no-wait --runtime-env="${RUNTIME_ENV}" \
    -- python3 -m recipe.dapo.main_dapo \
    --config-path=../../examples_npu/config/ \
    --config-name="dapo_trainer-megatron" \
    data.train_files="${TRAIN_FILE}" \
    data.val_files="${TEST_FILE}" \
    data.prompt_key=prompt \
    data.truncation='left' \
    data.max_prompt_length=${max_prompt_length} \
    data.max_response_length=${max_response_length} \
    data.train_batch_size=${train_prompt_bsz} \
    data.gen_batch_size=${gen_prompt_bsz} \
    actor_rollout_ref.rollout.n=${n_resp_per_prompt} \
    algorithm.adv_estimator=${adv_estimator} \
    algorithm.use_kl_in_reward=${use_kl_in_reward} \
    algorithm.kl_ctrl.kl_coef=${kl_coef} \
    actor_rollout_ref.actor.use_kl_loss=${use_kl_loss} \
    actor_rollout_ref.actor.kl_loss_coef=${kl_loss_coef} \
    actor_rollout_ref.actor.clip_ratio_low=${clip_ratio_low} \
    actor_rollout_ref.actor.clip_ratio_high=${clip_ratio_high} \
    actor_rollout_ref.actor.clip_ratio_c=10.0 \
    actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=1 \
    algorithm.filter_groups.enable=${enable_filter_groups} \
    algorithm.filter_groups.max_num_gen_batches=${max_num_gen_batches} \
    algorithm.filter_groups.metric=${filter_groups_metric} \
    actor_rollout_ref.ref.log_prob_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.rollout.log_prob_micro_batch_size_per_gpu=1 \
    actor_rollout_ref.model.path="${MODEL_PATH}" \
    actor_rollout_ref.actor.optim.lr=1e-6 \
    actor_rollout_ref.actor.optim.weight_decay=0.1 \
    actor_rollout_ref.actor.ppo_mini_batch_size=${train_prompt_mini_bsz} \
    actor_rollout_ref.actor.megatron.param_offload=${offload} \
    actor_rollout_ref.actor.megatron.optimizer_offload=${offload} \
    actor_rollout_ref.actor.megatron.grad_offload=${offload} \
    actor_rollout_ref.actor.megatron.pipeline_model_parallel_size=${train_pp} \
    actor_rollout_ref.actor.megatron.tensor_model_parallel_size=${train_tp} \
    actor_rollout_ref.actor.megatron.expert_model_parallel_size=${train_ep} \
    actor_rollout_ref.actor.megatron.dist_checkpointing_path=${MCORE_MODEL_PATH} \
    actor_rollout_ref.actor.megatron.use_dist_checkpointing=True \
    actor_rollout_ref.actor.megatron.context_parallel_size=${train_cp} \
    actor_rollout_ref.ref.megatron.context_parallel_size=${train_cp} \
    actor_rollout_ref.actor.entropy_coeff=0 \
    actor_rollout_ref.actor.optim.clip_grad=1.0 \
    actor_rollout_ref.actor.loss_agg_mode=${loss_agg_mode} \
    actor_rollout_ref.rollout.gpu_memory_utilization=0.7 \
    actor_rollout_ref.rollout.tensor_model_parallel_size=${gen_tp} \
    +actor_rollout_ref.rollout.dp_model_parallel_size=${gen_dp} \
    +actor_rollout_ref.rollout.rollout_world_size=${gen_world_size} \
    actor_rollout_ref.rollout.enable_chunked_prefill=True \
    actor_rollout_ref.rollout.max_num_batched_tokens=$((max_prompt_length + max_response_length)) \
    actor_rollout_ref.rollout.temperature=${temperature} \
    actor_rollout_ref.rollout.top_p=${top_p} \
    actor_rollout_ref.rollout.top_k=${top_k} \
    actor_rollout_ref.rollout.val_kwargs.temperature=${temperature} \
    actor_rollout_ref.rollout.val_kwargs.top_p=${val_top_p} \
    actor_rollout_ref.rollout.val_kwargs.top_k=${top_k} \
    actor_rollout_ref.rollout.val_kwargs.do_sample=True \
    actor_rollout_ref.rollout.val_kwargs.n=1 \
    actor_rollout_ref.rollout.name=vllm \
    actor_rollout_ref.ref.megatron.pipeline_model_parallel_size=${train_pp} \
    actor_rollout_ref.ref.megatron.tensor_model_parallel_size=${train_tp} \
    actor_rollout_ref.ref.megatron.expert_model_parallel_size=${train_ep} \
    actor_rollout_ref.ref.megatron.param_offload=${offload} \
    actor_rollout_ref.ref.megatron.dist_checkpointing_path=${MCORE_MODEL_PATH} \
    actor_rollout_ref.ref.megatron.use_dist_checkpointing=True \
    actor_rollout_ref.actor.use_torch_compile=False \
    actor_rollout_ref.ref.use_torch_compile=False \
    reward_model.reward_manager=dapo \
    reward_model.overlong_buffer.enable=${enable_overlong_buffer} \
    reward_model.overlong_buffer.len=${overlong_buffer_len} \
    reward_model.overlong_buffer.penalty_factor=${overlong_penalty_factor} \
    reward_model.overlong_buffer.log=False \
    trainer.logger=['console'] \
    trainer.project_name="${project_name}" \
    trainer.experiment_name="${exp_name}" \
    trainer.n_gpus_per_node=${NPU_PER_NODE} \
    trainer.nnodes="${NNODES}" \
    trainer.device=npu \
    trainer.val_before_train=False \
    trainer.test_freq=-1 \
    trainer.save_freq=-1 \
    trainer.total_epochs=1 \
    trainer.total_training_steps=100 \
    trainer.default_local_dir="${CKPTS_DIR}" \
    trainer.resume_mode=auto \
    trainer.log_val_generations=-1 \
    actor_rollout_ref.nccl_timeout=7200 \
    +actor_rollout_ref.actor.megatron.override_transformer_config.use_flash_attn=True \
    +actor_rollout_ref.actor.megatron.override_transformer_config.context_parallel_size=${train_cp} $@   2>&1 | tee /tmp/ray.output
ray_name=$(cat /tmp/ray.output | grep "submitted successfully" | awk -F "'" '{print $2}')
ray_name=${ray_name//\'}
mkdir -p $path_log_dir
echo "log dir is: $path_log_dir"
cp $0 $path_log_dir/
nohup ray job logs -f $ray_name 2>&1 | tee $path_log_dir/dapo-qwen3-30b-a3-megatron.log &