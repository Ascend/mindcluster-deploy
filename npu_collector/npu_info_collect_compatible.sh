#!/bin/bash
save_file=$1
npu_num=${2:-8}

datetime=$(date "+%Y-%m-%d %H:%M:%S.%6N")
echo "Datetime: $datetime">>${save_file}
echo -e "\n">>${save_file}


echo "/usr/local/bin/npu-smi info">>${save_file}
/usr/local/bin/npu-smi info>>${save_file}
echo -e "\n">>${save_file}


echo "cat /usr/local/Ascend/driver/version.info">>${save_file}
cat /usr/local/Ascend/driver/version.info>>${save_file}
echo -e "\n">>${save_file}


echo "/usr/local/Ascend/driver/tools/upgrade-tool --device_index -1 --component -1 --version">>${save_file}
/usr/local/Ascend/driver/tools/upgrade-tool --device_index -1 --component -1 --version>>${save_file}
echo -e "\n">>${save_file}


echo "lspci | grep acce">>${save_file}
lspci | grep acce>>${save_file}
echo -e "\n">>${save_file}


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/bin/npu-smi info -i ${i} -c 0 -t health">>${save_file}
  /usr/local/bin/npu-smi info -i ${i} -c 0 -t health>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -net_health -g">>${save_file}
  /usr/local/Ascend/driver/tools/hccn_tool -i ${i} -net_health -g>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -ip -g">>${save_file}
  /usr/local/Ascend/driver/tools/hccn_tool -i ${i} -ip -g>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -link_stat -g">>${save_file}
  /usr/local/Ascend/driver/tools/hccn_tool -i ${i} -link_stat -g>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -link -g">>${save_file}
  /usr/local/Ascend/driver/tools/hccn_tool -i ${i} -link -g>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -tls -g | grep switch">>${save_file}
  /usr/local/Ascend/driver/tools/hccn_tool -i ${i} -tls -g | grep switch>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -optical -g | grep prese">>${save_file}
  /usr/local/Ascend/driver/tools/hccn_tool -i ${i} -optical -g | grep prese>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -stat -g">>${save_file}
  /usr/local/Ascend/driver/tools/hccn_tool -i ${i} -stat -g>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -fec -g">>${save_file}
  /usr/local/Ascend/driver/tools/hccn_tool -i ${i} -fec -g>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/bin/npu-smi info -i ${i} -t ecc">>${save_file}
  /usr/local/bin/npu-smi info -i ${i} -t ecc>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/bin/npu-smi info -i ${i} -t board">>${save_file}
  /usr/local/bin/npu-smi info -i ${i} -t board>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/bin/npu-smi info -i ${i} -c 0 -t board">>${save_file}
  /usr/local/bin/npu-smi info -i ${i} -c 0 -t board>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/bin/npu-smi info -i ${i} -t usages">>${save_file}
  /usr/local/bin/npu-smi info -i ${i} -t usages>>${save_file}
  echo -e "\n">>${save_file}
done