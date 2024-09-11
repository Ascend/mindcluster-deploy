## ascend-fault-diag collect_tool

故障诊断组件Ascend-FaultDiag的日志采集脚本


```
collect_tool
    |-- net_data_collect.py
    |-- npu_data_collect.py
    |-- npu_info_collect.sh
    |-- host_resource_collect.py
```

--------

### 一、net_data_collect.py
单机“NPU网口统计指标文件”采集脚本

**1、运行说明**

`python3 net_data_collect.py -n {NPU_NUM} -it {INTERVAL_TIME} -o {OUTPUT_PATH}`

示例：
`python3 net_data_collect.py -n 8 -it 15 -o /xx/enviornment_check/worker-0`

执行结果： 在`{OUTPUT_PATH}`目录下生成`{NPU_NUM}`个`npu_(\d+)_details.csv`文件。  

**2、参数说明**

`-n {NPU_NUM}`，npu卡数，默认值为8

`-it {INTERVAL_TIME}`，采集间隔时间，单位秒，默认值为15

`-o {OUTPUT_PATH}`，输出目录，必选


--------

### 二、npu_data_collect.py
单机“NPU状态监控指标文件”采集脚本

**1、运行说明**

`python3 npu_data_collect.py -it {INTERVAL_TIME} -o {OUTPUT_PATH} -n {NPU_NUM}`

示例：
`python3 npu_data_collect.py -it 15 -o /xx/enviornment_check/worker-0 -n 8`

执行结果： 在`{OUTPUT_PATH}`目录下生成`{NPU_NUM}`个`npu_smi_(\d+)_details.csv`文件。  

**2、参数说明**

`-o {OUTPUT_PATH}`，输出目录，必选

`-it {INTERVAL_TIME}`，采集间隔时间，单位秒，默认值为15

`-n {NPU_NUM}`，npu卡数，默认值为8

--------

### 三、npu_info_collect.sh

单机“NPU网口检查文件”采集脚本，注：在训练前和训练后执行该脚本。

**1、运行说明**

`bash npu_info_collect.sh {SAVE_FILE} {NPU_NUM} {CHIP_NUM}`

示例：
```
bash npu_info_collect.sh /xx/enviornment_check/worker-0/npu_info_before.txt
bash npu_info_collect.sh /xx/enviornment_check/worker-0/npu_info_after.txt
```

执行结果：生成文件。 

**2、参数说明**

`{SAVE_FILE}`：保存文件。

`{NPU_NUM}`：npu卡数，默认值为8。

`{CHIP_NUM}`：每个NPU内芯片的数量，默认值为1。

--------

### 四、host_resource_collect.py

单机“主机资源监控文件”采集脚本

**1、运行说明**

`python3 host_resource_collect.py -o {OUTPUT_PATH}`

示例：
`python3 host_resource_collect.py -o /xx/enviornment_check/worker-0`

执行结果： 在`{OUTPUT_PATH}`目录下生成`host_metrics_(\d+).json`文件。  

**2、参数说明**

`-o {OUTPUT_PATH}`，输出目录，必选

**3、限制说明**

要求驱动版本≥23.0.RC3，驱动指令`npu-smi info`能正常使用，且支持显示卡上的进程号，否则脚本采集无结果。