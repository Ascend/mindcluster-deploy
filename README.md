# mindxdl-deploy
-   [免责申明](#免责申明)
-   [支持的产品形态](#支持的产品形态)
-   [目录说明](#目录说明)
-   [更新日志](#更新日志)

# 免责申明
- 本代码仓库中包含多个开发分支，这些分支可能包含未完成、实验性或未测试的功能。在正式发布之前，这些分支不应被用于任何生产环境或依赖关键业务的项目中。请务必仅使用我们的正式发行版本，以确保代码的稳定性和安全性。
  使用开发分支所导致的任何问题、损失或数据损坏，本项目及其贡献者概不负责。

# 支持的产品形态

- 支持以下产品使用：
    - Atlas 训练系列产品
    - Atlas A2 训练系列产品
    - Atlas A3 训练系列产品
    - 推理服务器（插Atlas 300I 推理卡）
    - Atlas 推理系列产品（Ascend 310P AI处理器）
    - Atlas 800I A2 推理服务器

# 目录说明
``` 
├─conf                                     # kubeconfig文件生成脚本
├─dashboard_json                           # grafana部署dashboard的json配置demo文件
├─doc                                       
├─npu_collector                            # npu相关信息采集脚本
│  └─log_rotate_sample
├─python_examples                          # python语言编写的对接demo代码
├─samples                                  # 训练、推理使用的启动脚本、yaml配置demo文件
│  ├─fault
│  │  └─1
│  ├─inference
│  │  ├─volcano
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
│  │          │  │  ├─pangu_alpha
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
│  │                  └─resnet50
│  │                      └─yamls
│  └─utils
│      ├─env_validation
│      └─prometheus
│          ├─base
│          └─prometheus_operator
└─training_toolkit                            # 配合MindXDL使用的训练工具
    ├─docs
    └─training_toolkit
        ├─config
        ├─framework_tester
        ├─logger
        ├─monitor
        └─utils

```

# 更新日志

| 版本               | 发布日期      | 修改说明              |
|------------------|-----------|-------------------|
| 20240720-V6.0.RC2 | 2024-720  | 配套MindX 6.0.RC2版本 |
| 20240520-V6.0.RC1 | 2024-520  | 配套MindX 6.0.RC1版本 |
| 20240105-V5.0.0  | 2024-015  | 配套MindX 5.0.0版本   |
| 2023930-V5.0.RC3 | 2023-930  | 配套MindX 5.0.RC3版本 |
| 2023630-V5.0.RC2 | 2023-630  | 配套MindX 5.0.RC2版本 |
| 2023330-V5.0.RC1 | 2023-330  | 配套MindX 5.0.RC1版本 |
| 20221230-V3.0.0  | 2022-1230 | 配套MindX 3.0.0版本   |
