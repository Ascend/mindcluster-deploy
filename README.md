# mindxdl-deploy
-   [免责声明](#免责声明)
-   [代码仓配套](#代码仓版本配套)
-   [支持的产品形态](#支持的产品形态)
-   [目录说明](#目录说明)

# 免责声明
本代码仓库提供[Mind Cluster]示例代码和脚本, 不建议直接用于生产环境.

**免责范围**:
- 使用本仓库示例代码和脚本导致的任何直接/间接损失(包括数据损坏、业务中断、安全漏洞等);
- 因用户自行修改代码、集成三方组件或配置不当引发的问题和风险;
- 本项目及贡献者不承担任何法律责任及赔偿义务.

[Mind Cluster]: https://www.hiascend.com/document/detail/zh/mindcluster/600/clustersched/introduction/schedulingsd/mxdlug_201.html

# 代码仓版本配套
| Mind Cluster版本               | mindxdl-deploy仓配套分支 |
|------------------------------|---------------------|
| 7.0.RC1                      | branch_v7.0.0-RC1   | 
| 6.0.0                        | branch_v6.0.0       | 
| 6.0.RC3                      | branch_v6.0.0-RC3   |
| 6.0.RC2                      | branch_v6.0.0-RC2   |
| 6.0.RC1, 5.0.1, 5.0.0, 3.0.0 | branch_v6.0.0-RC1   |

# 支持的产品形态

- 支持以下产品使用：
    - Atlas 训练系列产品
    - Atlas A2 训练系列产品
    - Atlas A3 训练系列产品
    - 推理服务器（插Atlas 300I 推理卡）
    - Atlas 推理系列产品
    - Atlas 800I A2 推理服务器

# 目录说明
``` 
├─appliance
│  └─faultdiag_orchestrator                # 故障诊断调度适配层工具
├─mindie                                   # mindie任务日志采集脚本
├─npu_collector                            # npu相关信息采集脚本
│  └─log_rotate_sample
├─samples                                  # 训练、推理使用的启动脚本、yaml配置demo文件
│  ├─fault
│  │  └─1
│  ├─inference
│  │  ├─volcano
│  │  │  └─mindie-ms
│  │  └─without-volcano
│  ├─train
│  │  ├─basic-training
│  │  │  ├─ranktable
│  │  │  │  └─yaml
│  │  │  │      ├─910
│  │  │  │      └─910b
│  │  │  └─without-ranktable
│  │  │      ├─mindspore
│  │  │      ├─pytorch
│  │  │      └─tensorflow
│  │  └─resumable-training
│  │      ├─fault-rescheduling
│  │      │  ├─withoutRanktable
│  │      │  │  ├─mindspore
│  │      │  │  │  ├─pangu_alpha
│  │      │  │  │  │  └─yamls
│  │      │  │  │  └─resnet50
│  │      │  │  │      └─yamls
│  │      │  │  ├─pytorch
│  │      │  │  │  ├─gpt-3
│  │      │  │  │  │  └─yamls
│  │      │  │  │  └─resnet50
│  │      │  │  │      └─yamls
│  │      │  │  └─tensorflow
│  │      │  │      └─yamls
│  │      │  └─withRanktable
│  │      │      ├─mindspore
│  │      │      │  ├─lenet5
│  │      │      │  │  ├─scripts
│  │      │      │  │  └─src
│  │      │      │  ├─pangu_alpha
│  │      │      │  │  └─yamls
│  │      │      │  ├─pangu_alpha_13B
│  │      │      │  │  └─yamls
│  │      │      │  └─resnet50
│  │      │      │      └─yamls
│  │      │      └─pytorch
│  │      │          ├─gpt-3
│  │      │          │  └─yamls
│  │      │          │      └─910B
│  │      │          └─resnet50
│  │      │              └─yamls
│  │      │                  ├─910
│  │      │                  └─910B
│  │      └─fault-tolerance
│  │          ├─ranktable
│  │          │  ├─mindspore
│  │          │  │  ├─llama2
│  │          │  │  │  └─yamls
│  │          │  │  ├─pangu_alpha
│  │          │  │  │  └─yamls
│  │          │  │  ├─Qwen3
│  │          │  │  │  └─yamls
│  │          │  │  └─resnet50
│  │          │  │      └─yamls
│  │          │  └─pytorch
│  │          │      ├─gpt-3
│  │          │      │  └─yamls
│  │          │      │      └─910B
│  │          │      └─resnet50
│  │          │          └─yamls
│  │          │              ├─910
│  │          │              └─910B
│  │          └─without-ranktable
│  │              ├─mindspore
│  │              │  ├─pangu_alpha
│  │              │  │  └─yamls
│  │              │  └─resnet50
│  │              │      └─yamls
│  │              └─pytorch
│  │                  ├─gpt-3
│  │                  │  └─yamls
│  │                  ├─llama2
│  │                  │  └─yamls
│  │                  ├─Qwen3
│  │                  │  └─yamls
│  │                  ├─resnet50
│  │                  │  └─yamls
│  │                  └─verl
│  └─utils
│      ├─env_validation
│      └─prometheus
│          ├─base
│          └─prometheus_operator
└─super_pod_diag
```