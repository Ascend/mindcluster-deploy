#!/usr/bin/env python3
# coding: utf-8
# Copyright 2023 Huawei Technologies Co., Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===========================================================================

"""
Parse Agent for Auto Fault Diagnoser.
This script can run on both local and remote machines to collect and parse logs.
If master information is provided, it sends results back via SSH.
Otherwise, it outputs results locally.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

DEFAULT_DIR_MODE = 0o644


def command_line():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser("Parse agent to collect and parse logs")
    parser.add_argument("--component", help="The component used in this parse work", required=True)
    parser.add_argument("--process_log", help="The process log path")
    parser.add_argument("--device_log", help="The device log path")
    parser.add_argument("--train_log", help="The train log path")
    parser.add_argument("--host_log", help="The host os log path")
    parser.add_argument("--master_user", help="The master user for SSH transfer")
    parser.add_argument("--master_ip", help="The master IP for SSH transfer")
    parser.add_argument("--remote_ip", help="The ip of the remote worker")
    parser.add_argument("-o", "--output", help="The output directory path", required=True)
    return parser.parse_args()


def collect_device_log(log_path):
    """Collect device log data."""
    if log_path:
        return log_path
    if os.getuid() == 0 and shutil.which("msnpureport") is not None:
        result = subprocess.run(["msnpureport"], capture_output=True, text=True)
        if result.returncode != 0:
            return ""
        export_keywords = "Start exporting logs and files to path: "
        for line in result.stdout.splitlines():
            if export_keywords in line:
                return line.split(export_keywords)[-1].strip()
    return ""


def collect_host_log(log_path):
    """Collect host log data."""
    if log_path:
        return log_path
    if os.getuid() != 0:
        return ""
    default_host_log_path = "/var/log"
    if os.path.exists(default_host_log_path):
        return default_host_log_path
    return ""


def collect_logs(args):
    """Collect all log data based on provided arguments."""
    logs_data = {
        "process_log": args.process_log,
        "train_log": args.train_log,
        "device_log": collect_device_log(args.device_log),
        "host_log": collect_host_log(args.host_log)
    }
    return logs_data


def execute_parse_cmd(cmd: str, output: str):
    cmd += f" -o {output}"
    result = subprocess.run(cmd.split(), capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Parse logs failed: {result.stderr}")
    print(result.stdout)


def parse(args, logs_data):
    """Parse collected logs and generate structured data."""
    cmd = f"{args.component} parse"
    for log_type, path in logs_data.items():
        if not path:
            continue
        cmd += f" --{log_type} {path}"

    if args.master_user and args.master_ip:
        with tempfile.TemporaryDirectory() as temp_dir:
            parse_result_dir = args.remote_ip or "worker-1"
            tmp_parse_result_dir = os.path.join(temp_dir, parse_result_dir)
            os.makedirs(tmp_parse_result_dir, mode=DEFAULT_DIR_MODE)
            execute_parse_cmd(cmd, tmp_parse_result_dir)
            return_to_orchestrator(tmp_parse_result_dir, args.master_user, args.master_ip, args.output)
    else:
        execute_parse_cmd(cmd, args.output)


def return_to_orchestrator(temp_dir, master_user, master_ip, remote_path):
    """Return all files from temp directory to orchestrator via SSH."""
    scp_cmd = ["scp", "-r", f"{temp_dir}", f"{master_user}@{master_ip}:{remote_path}"]
    try:
        subprocess.check_call(scp_cmd)
    except subprocess.CalledProcessError:
        raise RuntimeError("Failed to return results to orchestrator")


def main():
    """Main function to run the parse agent."""
    args = command_line()

    logs_data = collect_logs(args)

    parse(args, logs_data)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[ERROR] parse_agent.py failed due to: {str(e)}", file=sys.stderr)
        sys.exit(1)
