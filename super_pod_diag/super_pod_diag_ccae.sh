
#!/bin/bash

output_dir="."
bmc_logs=()
lcne_logs=()
host_log=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bmc_log)
            IFS=',' read -ra files <<< "$2"
            bmc_logs+=("${files[@]}")
            shift 2
            ;;
        --lcne_log)
            IFS=',' read -ra files <<< "$2"
            lcne_logs+=("${files[@]}")
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
mkdir -p "$output_dir/parse_input/bmc" \
         "$output_dir/parse_input/lcne" \
         "$output_dir/parse_input/host"

# 处理BMC日志
for log in "${bmc_logs[@]}"; do
    if [[ "$log" == *.zip ]]; then
        unzip -oq "$log" -d "$output_dir/parse_input/bmc/"
    elif [[ "$log" == *.tar.gz ]]; then
        tar -xzf "$log" -C "$output_dir/parse_input/bmc/"
    else
        echo "BMC日志格式不支持: $log"
        exit 1
    fi
done

# 处理LCNE日志
for log in "${lcne_logs[@]}"; do
    if [[ "$log" == *.zip ]]; then
        unzip -oq "$log" -d "$output_dir/parse_input/lcne/"
    elif [[ "$log" == *.tar.gz ]]; then
        tar -xzf "$log" -C "$output_dir/parse_input/lcne/"
    else
        echo "LCNE日志格式不支持: $log"
        exit 1
    fi
done

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
                if [[ $file == *.zip ]]; then
                    extract_dir="${file%.zip}"
                elif [[ $file == *.tar.gz ]]; then
                    extract_dir="${file%.tar.gz}"
                else
                    extract_dir="${file%.*}"
                fi
                extract_dir="${extract_dir//(*)/}"

                # 创建与压缩文件同名的目录
                mkdir -p "$extract_dir"

                if [[ "$file" == *.zip ]]; then
                    unzip -q "$file" -d "$extract_dir" 2>/dev/null
                elif [[ "$file" == *.tar.gz ]]; then
                    tar -xvzf "$file" -C "$extract_dir" 2>/dev/null
                    rm "$file"
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

# 设置最大并发数
max_jobs=10
job_count=0

for index in "${!dirs[@]}"; do
    dir="${dirs[index]}"
    options="${opts[index]}"

    for path in "$dir"/*; do
        # 等待空闲进程槽位
        while (( job_count >= max_jobs )); do
            wait -n
            ((job_count--))
        done

        filename=$(basename "$path")
        echo "Processing: $filename"
        parse_out_put="$output_dir/parse_output/$(basename "$dir")/$filename"
        mkdir -p "$parse_out_put"
        (
            ascend-fd parse $options "$path" -o "$parse_out_put"
        ) &

        ((job_count++))
    done
done

# 等待所有剩余后台任务完成
wait
end1=$(date +%s.%N)
echo "清洗耗时: $(echo "$end1 $start" | awk '{printf "%.2f分钟", ($1-$2)/60}')"
echo "ascend-fd diag -i \"$output_dir/parse_output\" -o \"$output_dir\" -s super_pod"
ascend-fd diag -i "$output_dir/parse_output" -o "$output_dir" -s super_pod
exit 0