#!/bin/bash

output_dir="."
bmc_log=""
lcne_log=""
host_log=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bmc_log)
            bmc_log="$2"
            shift 2
            ;;
        --lcne_log)
            lcne_log="$2"
            shift 2
            ;;
        --host_log)
            host_log="$2"
            shift 2
            ;;
        --output)
            output_dir="$2"
            shift 2
            ;;
        *)
            echo "未知选项: $1"
            exit 1
            ;;
    esac
done
rm -rf "$output_dir/parse_input"
# 创建输出目录结构
mkdir -p "$output_dir/parse_input/bmc" \
         "$output_dir/parse_input/lcne" \
         "$output_dir/parse_input/host"

# 处理BMC日志
if [ -n "$bmc_log" ]; then
    if [[ "$bmc_log" == *.zip ]]; then
        unzip -oq "$bmc_log" -d "$output_dir/parse_input/bmc"
    elif [[ "$bmc_log" == *.tar.gz ]]; then
        tar -xzf "$bmc_log" -C "$output_dir/parse_input/bmc/"
    else
        echo "BMC日志格式不支持: $bmc_log"
        exit 1
    fi
fi

# 处理LCNE日志
if [ -n "$lcne_log" ]; then
    if [[ "$lcne_log" == *.zip ]]; then
        unzip -oq "$lcne_log" -d "$output_dir/parse_input/lcne/"
    elif [[ "$lcne_log" == *.tar.gz ]]; then
        tar -xzf "$lcne_log" -C "$output_dir/parse_input/lcne/"
    else
        echo "LCNE日志格式不支持: $lcne_log"
        exit 1
    fi
fi

# 处理主机日志
if [ -n "$host_log" ]; then
    cp -rf "$host_log"/* "$output_dir/parse_input/host/"
fi

# 递归解压函数
# 增强型递归解压函数（解决无限循环问题）
recursive_unzip() {
    local target_dir="$1"
    local -A processed_files  # 关联数组记录已处理文件

    while : ; do
        local found=0
        # 查找所有未处理的压缩文件
        while IFS= read -r -d '' file; do
            if [[ -z "${processed_files["$file"]}" ]]; then
                found=1
                processed_files["$file"]=1

                echo "解压中: $file"
                local base_dir="$(dirname "$file")"
                local file_name="$(basename "$file")"
                local extract_dir="${file%.*}"

                # 创建与压缩文件同名的目录
                mkdir -p "$extract_dir"

                if [[ "$file" == *.zip ]]; then
                    unzip -q "$file" -d "$extract_dir" 2>/dev/null
                elif [[ "$file" == *.tar.gz ]]; then
                    tar -xzf "$file" -C "$extract_dir" 2>/dev/null
                fi
            fi
        done < <(find "$target_dir" \( -name "*.zip" -o -name "*.tar.gz" \) -print0 2>/dev/null)

        [[ $found -eq 0 ]] && break
    done
}

# 处理BMC和LCNE目录
recursive_unzip "$output_dir/parse_input/bmc"
recursive_unzip "$output_dir/parse_input/lcne"

# 清理压缩文件和Excel文件
find "$output_dir/parse_input/bmc" \( -name "*.zip" -o -name "*.xlsx" \) -delete
find "$output_dir/parse_input/lcne" \( -name "*.zip" -o -name "*.xlsx" \) -delete

echo "日志解压完成"

shopt -s nullglob  # 处理空目录时不展开通配符

# 定义目录和对应的参数列表
dirs=("$output_dir/parse_input/host" "$output_dir/parse_input/lcne" "$output_dir/parse_input/bmc")
rm -rf "$output_dir/parse_output"
opts=("-i" "--lcne_log" "--bmc_log")
start=$(date +%s.%N)
for index in "${!dirs[@]}"; do
    dir="${dirs[index]}"
    options="${opts[index]}"

    for path in "$dir"/*; do
        filename=$(basename "$path")
          echo "Processing: $filename"
          parse_out_put="$output_dir/parse_output/$(basename "$dir")/$filename"
          mkdir -p "$parse_out_put"
          echo "ascend-fd parse $options  \"$path\" -o \"$parse_out_put\" "

          #echo ' ascend-fd parse -i "$path" -o "$parse_out_putr" $options'
          ascend-fd parse $options "$path" -o "$parse_out_put"
    done
done
end1=$(date +%s.%N)
echo "清洗耗时: $(echo "$end1 $start" | awk '{printf "%.2f分钟", ($1-$2)/60}')"
echo "ascend-fd diag -i \"$output_dir/parse_output\" -o \"$output_dir\" -s super_pod"
ascend-fd diag -i "$output_dir/parse_output" -o "$output_dir" -s super_pod
exit 0