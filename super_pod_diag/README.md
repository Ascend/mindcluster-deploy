## ascend-fault-diag super_pod_diag.sh

故障诊断组件Ascend-FaultDiag的超节点日志清洗及诊断脚本

--------

### super_pod_diag.sh

单机“超节点日志清洗诊断”采集脚本

**1、运行说明**

`bash super_pod_diag.sh --host_log {HOST_LOG} --bmc_log {BMC_LOG} --lcne_log {LCNE_LOG} --output {OUTPUT}`

示例：
`bash super_pod_diag.sh --host_log /home/host --bmc_log /home/logcollect_BMC.zip --lcne_log logcollect_SWITCH.zip --output .`

执行结果： 在`{OUTPUT_PATH}`目录下生成诊断结果和拓扑信息文件。  

**2、参数说明**
`--host_log {HOST_LOG}`，host日志路径(未压缩)，必选
`--bmc_log {BMC_LOG}`， bmc日志路径(已压缩且解压后的文件为LogCollect.xlsx同级目录)，必选
`--lcne_log {LCNE_LOG}`， lcne日志路径(已压缩且解压后的文件为LogCollect.xlsx同级目录)，必选
`--output {OUTPUT}`，输出目录，必选

**3、限制说明**
要求host日志路径下文件未压缩，bmc和lcne日志为压缩文件
