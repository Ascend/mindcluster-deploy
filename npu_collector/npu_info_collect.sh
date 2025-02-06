#!/bin/bash
save_file=$1
npu_num=${2:-8}
chip_num=${3:-1}
hccn_tool_num=$((npu_num * chip_num))

datetime=$(date "+%Y-%m-%d %H:%M:%S.%6N")
echo "Datetime: $datetime">>"${save_file}"
echo -e "\n">>"${save_file}"

echo "/usr/local/bin/npu-smi info -m">>"${save_file}"
/usr/local/bin/npu-smi info -m>>"${save_file}"
echo -e "\n">>"${save_file}"


echo "/usr/local/bin/npu-smi info">>"${save_file}"
/usr/local/bin/npu-smi info>>"${save_file}"
echo -e "\n">>"${save_file}"

if [ -e "/usr/local/Ascend/driver/version.info" ]; then
  echo "cat /usr/local/Ascend/driver/version.info">>"${save_file}"
  cat /usr/local/Ascend/driver/version.info>>"${save_file}"
  echo -e "\n">>"${save_file}"
fi


if [ -e "/usr/local/Ascend/firmware/version.info" ]; then
  echo "cat /usr/local/Ascend/firmware/version.info">>"${save_file}"
  cat /usr/local/Ascend/firmware/version.info>>"${save_file}"
  echo -e "\n">>"${save_file}"
fi


if [ -e "/usr/local/Ascend/nnae/latest/ascend_nnae_install.info" ]; then
  echo "cat /usr/local/Ascend/nnae/latest/ascend_nnae_install.info">>"${save_file}"
  cat /usr/local/Ascend/nnae/latest/ascend_nnae_install.info>>"${save_file}"
  echo -e "\n">>"${save_file}"
fi


if [ -e "/usr/local/Ascend/ascend-toolkit/latest/aarch64-linux/ascend_toolkit_install.info" ]; then
  echo "cat /usr/local/Ascend/ascend-toolkit/latest/aarch64-linux/ascend_toolkit_install.info">>"${save_file}"
  cat /usr/local/Ascend/ascend-toolkit/latest/aarch64-linux/ascend_toolkit_install.info>>"${save_file}"
  echo -e "\n">>"${save_file}"
fi


if [ -e "/usr/local/Ascend/ascend-toolkit/latest/x86_84-linux/ascend_toolkit_install.info" ]; then
  echo "cat /usr/local/Ascend/ascend-toolkit/latest/x86_84-linux/ascend_toolkit_install.info">>"${save_file}"
  cat /usr/local/Ascend/ascend-toolkit/latest/x86_84-linux/ascend_toolkit_install.info>>"${save_file}"
  echo -e "\n">>"${save_file}"
fi


echo "pip list | grep \"torch \"">>"${save_file}"
pip list | grep "torch ">>"${save_file}"
echo -e "\n">>"${save_file}"


echo "pip list | grep torch-npu">>"${save_file}"
pip list | grep torch-npu>>"${save_file}"
echo -e "\n">>"${save_file}"


echo "pip list | grep \"mindspore \"">>"${save_file}"
pip list | grep "mindspore ">>"${save_file}"
echo -e "\n">>"${save_file}"


echo "/usr/local/Ascend/driver/tools/upgrade-tool --device_index -1 --component -1 --version">>"${save_file}"
/usr/local/Ascend/driver/tools/upgrade-tool --device_index -1 --component -1 --version>>"${save_file}"
echo -e "\n">>"${save_file}"


echo "lspci | grep acce">>"${save_file}"
lspci | grep acce>>"${save_file}"
echo -e "\n">>"${save_file}"


for((i=0;i<npu_num;i++));
do
  for((j=0;j<chip_num;j++));
  do
    echo "/usr/local/bin/npu-smi info -i ${i} -c ${j} -t health">>"${save_file}"
    /usr/local/bin/npu-smi info -i "${i}" -c "${j}" -t health>>"${save_file}"
    echo -e "\n">>"${save_file}"
  done
done


for((i=0;i<hccn_tool_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -net_health -g">>"${save_file}"
  /usr/local/Ascend/driver/tools/hccn_tool -i "${i}" -net_health -g>>"${save_file}"
  echo -e "\n">>"${save_file}"
done


for((i=0;i<hccn_tool_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -ip -g">>"${save_file}"
  /usr/local/Ascend/driver/tools/hccn_tool -i "${i}" -ip -g>>"${save_file}"
  echo -e "\n">>"${save_file}"
done


for((i=0;i<hccn_tool_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -link_stat -g">>"${save_file}"
  /usr/local/Ascend/driver/tools/hccn_tool -i "${i}" -link_stat -g>>"${save_file}"
  echo -e "\n">>"${save_file}"
done


for((i=0;i<hccn_tool_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -link -g">>"${save_file}"
  /usr/local/Ascend/driver/tools/hccn_tool -i "${i}" -link -g>>"${save_file}"
  echo -e "\n">>"${save_file}"
done


for((i=0;i<hccn_tool_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -tls -g | grep switch">>"${save_file}"
  /usr/local/Ascend/driver/tools/hccn_tool -i "${i}" -tls -g | grep switch>>"${save_file}"
  echo -e "\n">>"${save_file}"
done


for((i=0;i<npu_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -optical -g | grep prese">>${save_file}
  /usr/local/Ascend/driver/tools/hccn_tool -i ${i} -optical -g | grep prese>>${save_file}
  echo -e "\n">>${save_file}
done


for((i=0;i<hccn_tool_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -optical -g">>"${save_file}"
  /usr/local/Ascend/driver/tools/hccn_tool -i "${i}" -optical -g>>"${save_file}"
  echo -e "\n">>"${save_file}"
done


for((i=0;i<hccn_tool_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -stat -g">>"${save_file}"
  /usr/local/Ascend/driver/tools/hccn_tool -i "${i}" -stat -g>>"${save_file}"
  echo -e "\n">>"${save_file}"
done


for((i=0;i<hccn_tool_num;i++));
do
  echo "/usr/local/Ascend/driver/tools/hccn_tool -i ${i} -fec -g">>"${save_file}"
  /usr/local/Ascend/driver/tools/hccn_tool -i "${i}" -fec -g>>"${save_file}"
  echo -e "\n">>"${save_file}"
done


for((i=0;i<npu_num;i++));
do
  for((j=0;j<chip_num;j++));
  do
    echo "/usr/local/bin/npu-smi info -i ${i} -c ${j} -t ecc">>"${save_file}"
    /usr/local/bin/npu-smi info -i "${i}" -c "${j}" -t ecc>>"${save_file}"
    echo -e "\n">>"${save_file}"
  done
done


for((i=0;i<npu_num;i++));
do
  for((j=0;j<chip_num;j++));
  do
    echo "/usr/local/bin/npu-smi info -i ${i} -c ${j} -t board">>"${save_file}"
    /usr/local/bin/npu-smi info -i "${i}" -c "${j}" -t board>>"${save_file}"
    echo -e "\n">>"${save_file}"
  done
done


for((i=0;i<npu_num;i++));
do
  for((j=0;j<chip_num;j++));
  do
    echo "/usr/local/bin/npu-smi info -i ${i} -c ${j} -t usages">>"${save_file}"
    /usr/local/bin/npu-smi info -i "${i}" -c "${j}" -t usages>>"${save_file}"
    echo -e "\n">>"${save_file}"
  done
done