# 故障诊断调度适配层参考设计

此工具旨在一体机场景下提供调度故障诊断组件、双机日志清洗以及汇聚诊断的能力。其主要由两个组件构成：调度器（Orchestrator）和清洗器（Parse
Agent）。

## 系统架构

### Orchestrator 调度器

调度器负责协调整个故障诊断流程。

#### 主要功能：

1. **配置管理**
    - 读取并验证JSON格式的配置文件
    - 包含本地和远程工作节点信息
    - 定义需要分析的日志路径

2. **环境检测**
    - 检测是单节点还是双节点环境
    - 验证远程节点的可访问性
    - 验证SSH免密登录配置

3. **组件安装**
    - 在本地和远程节点自动安装诊断组件
    - 支持通过wheel包安装ascend-fd和alan-fd
    - 验证安装结果

4. **日志处理协调**
    - 部署清洗器（parse_agent）到各个节点
    - 协调日志收集和解析过程
    - 收集解析结果

5. **诊断执行**
    - 运行最终的诊断程序
    - 生成诊断报告

#### 工作流程：

1. 解析命令行参数，获取配置文件和输出目录
2. 读取并验证配置文件
3. 安装所需的诊断组件
4. 在本地和远程工作节点部署并运行清洗器
5. 收集解析后的日志数据
6. 执行诊断程序并生成最终报告

### Parse Agent 清洗器

清洗器是一个轻量级组件，部署在每个工作节点上，用于收集和解析日志。

#### 主要功能：

1. **多源日志收集**
    - CANN应用类日志与CANN系统类日志
    - 设备日志，若未事先提供则自动采集（需要root权限）
    - 主机操作系统日志
    - 训练日志

2. **灵活部署**
    - 由调度器调度在本地运行，或者通过SSH部署到远程节点运行

3. **远程结果传输**
    - 通过SSH将解析结果发送回调排器
    - 支持临时目录管理

#### 运行模式：

1. **独立模式**：直接运行并将结果输出到本地路径
2. **协调模式**：由调度器部署运行，并通过SSH返回结果

## 使用方法

### 文件准备

下载orchestrator.py与parse_agent.py，并将它们放在同一目录下

### 配置文件示例

创建一个JSON格式的配置文件：

```json
{
  "local_worker": {
    "user": "user1",
    "ip": "x.x.x.x"
  },
  "remote_worker": {
    "user": "user2",
    "ip": "x.x.x.x"
  },
  "whl_pkg_path": "/path/to/Ascend-mindxdl-faultdiag_{version}-{arch}.whl",
  "log_path": {
    "process_log": "/path/to/process_log",
    "device_log": "/path/to/device_log",
    "host_log": "/var/log/",
    "train_log": "/path/to/train_log"
  }
}
```

- 节点信息，若配置错误，将执行单节点清洗
    - `local_worker`：本地工作节点信息，包含免密登录的用户和IP地址
    - `remote_worker`：远程工作节点信息，包含免密登录的用户和IP地址
- 组件wheel包
    - `whl_pkg_path`：诊断组件的wheel包路径
- 日志路径，默认两个工作节点各个日志路径均相同
    - `log_path`：日志路径，包含CANN应用类日志与CANN系统类日志、设备日志、主机操作系统日志和训练日志

### 运行命令

```bash
python3 orchestrator.py -i user_config.json -o /output/path
```

系统会自动完成以下操作：

1. 验证配置文件
2. 安装必要的诊断组件
3. 在所有配置的工作节点上部署清洗器
4. 收集和解析各节点日志
5. 生成最终诊断报告

## 环境要求

- Python 3.7+
- 支持使用pip3
- ply已安装，若未安装，请使用`pip3 install ply`安装
- SSH访问权限（用于远程节点通信）
- 已安装故障诊断组件或者对应的wheel包以供安装

## 注意事项

1. 确保所有工作节点具有相同的目录结构，否则清洗器可能会失败
2. 远程节点需要配置SSH免密登录
3. 确保指定的日志路径在对应节点上存在且可访问
4. 双节点使用场景需要网络连接稳定
5. 未提供设备日志路径且配置了root权限时，清洗器会尝试自动采集设备日志
6. orchestrator.py和parse_agent.py需要放在同一目录下才能正常工作

## 常见问题 (FAQ)

### Q1: 安装组件时pip告警“WARNING: The script ... is installed in ... which is not on PATH”应如何处理？

#### 问题描述

工具在执行时会调用`pip3 install`安装故障诊断组件，但可能会出现如下告警（脚本名、路径在不同环境下可能存在差异）：

```
WARNING: The script <script_name> is installed in '<some/path>' which is not on PATH”
```

该提示内容会随系统、Python安装位置、用户配置而变化

#### 原因描述

此告警表示：

- pip将组件安装到系统路径，但系统环境变量PATH未包含该路径
- 用户在终端无法直接通过命令调用组件，也无法检查其安装状态，此举会导致工具无法正确执行

这属于pip的常规提醒，并不表示安装失败

#### 解决方法

将pip安装的目录加入系统环境变量PATH中，编辑系统级环境变量配置文件`/etc/environment`，在文件中添加或扩展PATH，例如：

```
PATH="...:/usr/local/bin"
```

`...`代表已存在的PATH，请根据系统实际情况进行修改

### Q2： 工具无法检测到远端节点已安装的故障诊断组件，应如何处理？

#### 问题描述

工具执行时，无法检测到远端节点已安装的故障诊断组件，即便传输了wheel包到远端节点并成功通过`pip3 install`安装，仍然显示安装失败，报错如下：

```
[ERROR] [Remote] <component_name> installation faield.
```

#### 原因描述

工具执行时，本端会通过SSH远程执行`which`命令检查远程节点是否已安装故障诊断组件。在远程节点环境配置异常时，可能会出现在远端本地执行命令结果与在本端通SSH执行不一致的情况。这是因为SSH远程执行命令默认为
**非交互、非登录shell模式**，此种模式不会读取以下配置文件：

- `/etc/profile`
- `~/.bashrc`（大部分情况下）
- `~/.profile`
- `~/.bash_profile`

因此，PATH、PYTHONPATH、PIP等环境变量不会被加载。

结果可能导致：

- `which`找不到命令导致无法检测组件是否安装，因为PATH不完整。
- 本端远程执行`pip3 install`时，pip3无法检测到远端是否装有组件需要的依赖。

#### 解决方法

将PATH写入系统级环境变量配置文件`/etc/environment`中。

1. 在远端本地执行以下命令检查环境变量PATH

```shell
echo $PATH
```

2. 查看并编辑远端的系统级环境变量配置文件`/etc/environment`，将PATH添加或扩展如下，将在步骤1中查看到的PATH添加或扩展到其中：

```shell
vi /etc/environment
```
