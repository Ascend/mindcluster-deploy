
### npu-exporter集成devkit部署指南

#### 一、说明
   npu-exporter完整步骤请参考社区资料：https://www.hiascend.com/document/detail/zh/mindcluster/72rc1/clustersched/dlug/dlug_installation_012.html

   本说明仅阐述增量修改内容

#### 二、集成devkit修改内容
为适配npu-exporter集成devkit，npu-exporter的Dockfile、npu-exporter.yaml文件需做如下修改：
1. npu-exporter安装包准备
   - 下载npu-exporter安装包,下载地址：https://gitcode.com/Ascend/mind-cluster/releases
   - 将安装包解压到服务器任意目录
2. devkit工具准备
   - 下载devkit工具,下载地址：https://kunpeng-repo.obs.cn-north-4.myhuaweicloud.com/Kunpeng%20DevKit/Kunpeng%20DevKit%2025.3.T110/ksys-25.3.T110-Linux-aarch64.tar.gz
   - 解压devkit工具到任意目录,并将其中的ksys、config_pa.yaml拷贝npu-exporter解压目录下
3. 使用samples/utils/npu-exporter/Dockerfile替换npu-exporter解压目录中的Dockerfile   
4. 下载samples/utils/npu-exporter/npu-exporter.yaml到npu-exporter解压目录
5. 制作镜像
   ```shell
      # 版本号需和npu-exporter.yaml中保持一致
      docker build --no-cache -t npu-exporter:v7.3.0 ./
   ```
6. 启动npu-exporter
   ```shell
      kubectl apply -f npu-exporter.yaml
   ```