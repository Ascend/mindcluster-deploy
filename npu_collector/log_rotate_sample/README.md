**目录说明**<br>
**ascend_log_rotate.sh**: 日志转储脚本配置示例。用于配置训练容器内日志保存路径、宿主机挂在关系，以及启动其他日志采集脚本。<br/>
**npu_info_collect.sh**: NPU环境检查脚本示例。通过执行hccn_tool、npu-smi等相关命令，记录软件版本信息、NPU网口指标等。<br/>
**os_log_collect.py**: OS日志采集脚本示例。将脚本执行期间新产生的OS日志，转存至新的日志文件。注：该脚本无转储。<br/>
**demo.yaml**：训练任务拉起yaml文件示例。注：非完整示例，仅供参考。