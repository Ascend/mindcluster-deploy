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
Auto Fault Diagnoser Orchestrator
This module handles the orchestration of fault diagnosis across single or dual worker environments.
"""

import argparse
import json
import subprocess
import sys
import os
import re
import shutil

from dataclasses import dataclass, asdict
from enum import Enum
from typing import Optional

PARSING_TIMEOUT = 600
DIAGNOSIS_TIMEOUT = 300
PIP_INSTALL_TIMEOUT = 15
REMOTE_AGENT_PATH = "/var/faultdiag_parse_agent"
DEFAULT_DIR_MODE = 0o750
MAX_FILE_SIZE = 100 * 1024 * 1024


# =============================================================================
# Message Handling
# =============================================================================

class MessageHandler:
    """Unified message handler for logging and user communication."""

    @staticmethod
    def info(message: str):
        """Print general information message."""
        print(f"[INFO] {message}.")

    @staticmethod
    def warning(message: str):
        """Print warning message to stderr."""
        print(f"[WARNING] {message}.", file=sys.stderr)

    @staticmethod
    def error(message: str):
        """Print error message to stderr."""
        print(f"[ERROR] {message}.", file=sys.stderr)


# =============================================================================
# Configuration Data Classes
# =============================================================================

@dataclass
class HostInfo:
    """Information about a host including user and IP address."""
    user: Optional[str] = None
    ip: Optional[str] = None


@dataclass
class PathConfig:
    """Configuration for log file paths."""
    process_log: Optional[str] = None
    device_log: Optional[str] = None
    host_log: Optional[str] = None
    train_log: Optional[str] = None

    def __post_init__(self):
        """Initialize PathConfig and validate paths."""
        if not any((self.process_log, self.device_log, self.host_log, self.train_log)):
            raise ValueError("None of the log path is specified, please check the configuration file")
        for path in [self.process_log, self.device_log, self.host_log, self.train_log]:
            if path:
                validate_path(path)


@dataclass
class Config:
    """Main configuration class containing all settings."""
    local_worker: HostInfo = None
    remote_worker: HostInfo = None
    whl_pkg_path: Optional[str] = None
    log_path: PathConfig = None
    dual_worker_scene: bool = False
    international_pkg: bool = False

    def __post_init__(self):
        """Initialize Config and validate configurations."""
        if self.local_worker.ip and self.remote_worker.ip:
            self.validate_dual_ip()
        self.validate_whl_pkg_path()

    @staticmethod
    def from_dict(data: dict):
        """Create Config instance from dictionary."""
        local = data.get("local_worker", {})
        remote = data.get("remote_worker", {})
        log_path = data.get("log_path", {})
        return Config(
            local_worker=HostInfo(local.get("user", ""), local.get("ip", "")),
            remote_worker=HostInfo(remote.get("user", ""), remote.get("ip", "")),
            whl_pkg_path=data.get("whl_pkg_path", ""),
            log_path=PathConfig(
                process_log=log_path.get("process_log", ""),
                device_log=log_path.get("device_log", ""),
                host_log=log_path.get("host_log", ""),
                train_log=log_path.get("train_log", "")
            )
        )

    def validate_dual_ip(self):
        """Validate dual worker IP configuration."""
        if self.local_worker.ip == self.remote_worker.ip:
            MessageHandler.warning("Only the local log would be handled since the local ip and remote ip are the same")
            return
        try:
            validate_ip(self.local_worker.ip)
            validate_ip(self.remote_worker.ip)
        except ValueError as e:
            MessageHandler.warning(f"Only the local log would be handled "
                                   f"since at least one of the ip in the config is invalid: {e}")
        else:
            self.dual_worker_scene = validate_remote_availability(self.remote_worker.ip, self.remote_worker.user)
        if self.dual_worker_scene:
            MessageHandler.info("Dual worker scene detected")
        else:
            MessageHandler.info("Single worker scene detected")

    def validate_whl_pkg_path(self):
        """Validate wheel package path."""
        if not self.whl_pkg_path:
            MessageHandler.warning("No whl package path specified")
            return

        try:
            self.whl_pkg_path = validate_file_path(self.whl_pkg_path)
        except (ValueError, FileNotFoundError) as e:
            MessageHandler.warning(f"Invalid whl package path: {e}.")
        else:
            if not self.whl_pkg_path.endswith(".whl"):
                MessageHandler.warning("Invalid whl package path: The whl package path must ends with '.whl'")


# =============================================================================
# Input Validation Functions
# =============================================================================

def validate_ip(ip: str):
    """Validate IP address format."""
    ipv4_pattern = r"^(\d{1,3}\.){3}\d{1,3}$"

    if not re.match(ipv4_pattern, ip):
        raise ValueError(f"Invalid IP address format: {ip}, please check the IP configuration")

    parts = ip.split('.')
    for part in parts:
        num = int(part)
        if num < 0 or num > 255:
            raise ValueError(f"IP address octet out of range: {part}, please check the IP configuration")


def validate_path(path: str):
    """Validate if path exists and is not a symbolic link."""
    path = path.strip()
    if not os.path.exists(path):
        raise FileNotFoundError(f"Path does not exist: {path}, please check the input or the configuration file")

    if os.path.islink(path):
        raise ValueError(f"Path is a symbolic link: {path}, please check the input or the configuration file")

    return os.path.abspath(path)


def validate_file_path(path: str) -> str:
    """Validate if file path is valid."""
    validate_path(path)
    if not os.path.isfile(path):
        raise argparse.ArgumentTypeError(f"Path is not a file: {path}, "
                                         f"please check the input or the configuration file")
    return path


def validate_output_path(path: str):
    """Validate output path exists and is an empty directory."""

    if not os.path.exists(path):
        os.makedirs(path, mode=DEFAULT_DIR_MODE)
        return os.path.abspath(path)

    validate_path(path)
    if not os.path.isdir(path):
        raise argparse.ArgumentTypeError(f"Output path is not a directory: {path}, please check the input")

    if os.listdir(path):
        raise argparse.ArgumentTypeError(f"Output directory is not empty: {path}, please check the input")

    return os.path.abspath(path)


def validate_schema(data, schema_def, path=""):
    """Recursively validate data according to schema definition."""
    for key, rules in schema_def.items():
        current_path = f"{path}.{key}" if path else key
        if key not in data:
            if rules.get("required", False):
                raise ValueError(f"Required field '{current_path}' is missing")
            continue

        value = data[key]

        expected_type = rules["type"]
        if not isinstance(value, expected_type):
            raise ValueError(f"Invalid value type for field '{current_path}': "
                             f"Expected {expected_type}, got {type(value)}")

        if "structure" in rules:
            validate_schema(value, rules["structure"], current_path)


# =============================================================================
# Configuration File Handling
# =============================================================================

def read_file(file_path: str) -> str:
    """Read file content and check permissions."""
    file_size = os.path.getsize(file_path)
    if file_size > MAX_FILE_SIZE:
        raise ValueError(f"File size exceeds the limit of {MAX_FILE_SIZE} bytes: {file_path}")
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read()
    except PermissionError:
        raise PermissionError(f"Permission denied: Unable to open file {file_path}")
    except IOError as e:
        raise IOError(f"Failed to open file {file_path}: {str(e)}")


def read_cfg(cfg_path: str):
    """Read configuration file."""
    content = read_file(cfg_path)
    try:
        data = json.loads(content)
        return data
    except json.decoder.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON format in {cfg_path}: {str(e)}")


def validation(cfg_data: dict):
    """Validate configuration data."""
    current_dir = os.path.dirname(__file__)
    parse_agent_path = os.path.join(current_dir, "parse_agent.py")
    if not os.path.exists(parse_agent_path):
        raise FileNotFoundError("Required file 'parse_agent.py' not found in the same directory of 'orchestrator.py'")

    schema = {
        "local_worker": {
            "type": dict,
            "structure": {
                "user": {"type": str},
                "ip": {"type": str}
            }
        },
        "remote_worker": {
            "type": dict,
            "structure": {
                "user": {"type": str},
                "ip": {"type": str}
            }
        },
        "whl_pkg_path": {"type": str},
        "log_path": {
            "type": dict,
            "required": True,
            "structure": {
                "process_log": {"type": str},
                "device_log": {"type": str},
                "host_log": {"type": str},
                "train_log": {"type": str}
            }
        }
    }
    validate_schema(cfg_data, schema)
    cfg = Config.from_dict(cfg_data)
    return cfg


# =============================================================================
# Command Line Interface
# =============================================================================

def command_line():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Auto Fault Diagnose")
    parser.add_argument("-i", "--input", help="User config path", type=validate_file_path, required=True)
    parser.add_argument("-o", "--output", help="The path to store parse and diagnosis results",
                        type=validate_output_path, required=True)
    return parser.parse_args()


# =============================================================================
# Component Management
# =============================================================================

class PackageType(Enum):
    """Enumeration of package types."""
    DOMESTIC = "ascend-fd"
    INTERNATIONAL = "alan-fd"
    UNKNOWN = "FaultDiag components"


def is_installed(executable: str):
    """Check if component is installed."""
    return shutil.which(executable) is not None


def detect_package_type(pkg_name: str):
    """Detect wheel package type."""
    if "ascend" in pkg_name:
        return PackageType.DOMESTIC
    elif "alan" in pkg_name:
        return PackageType.INTERNATIONAL
    else:
        return PackageType.UNKNOWN


def detect_package_arch(pkg_name: str):
    """Detect wheel package architecture."""
    if "aarch64" in pkg_name:
        return "aarch64"
    if "x86_64" in pkg_name:
        return "x86_64"
    return "unknown"


def verify_install(pkg_type: PackageType):
    """Verify installation result."""
    verification_strategy = {
        PackageType.DOMESTIC: ["ascend-fd"],
        PackageType.INTERNATIONAL: ["alan-fd"],
        PackageType.UNKNOWN: ["ascend-fd", "alan-fd"]
    }

    for installed_component in verification_strategy[pkg_type]:
        if is_installed(installed_component):
            return installed_component
    return None


def install_local(cfg: Config):
    """Install package locally."""
    pkg_type = detect_package_type(os.path.basename(cfg.whl_pkg_path))
    installed_pkg = verify_install(pkg_type)
    if installed_pkg is not None:
        MessageHandler.info(f"[Local] {installed_pkg} already installed, skip installation")
        return installed_pkg

    run(f"pip3 install {cfg.whl_pkg_path} --disable-pip-version-check", timeout=PIP_INSTALL_TIMEOUT)

    installed_pkg = verify_install(pkg_type)
    if installed_pkg is not None:
        MessageHandler.info(f"[Local] {installed_pkg} installed successfully")
        return installed_pkg

    raise ValueError(f"[Local] {installed_pkg or pkg_type.value} installation failed, "
                     f"please check the configuration file and the whl package")


def install_remote(cfg: Config, component: str):
    """Install package on remote host."""
    whl_pkg_name = os.path.basename(cfg.whl_pkg_path)
    remote_path = os.path.join(REMOTE_AGENT_PATH, whl_pkg_name)
    whl_arch = detect_package_arch(whl_pkg_name)

    MessageHandler.info(f"Checking the availability of the {component} on {cfg.remote_worker.ip}")
    try:
        ssh_run(cfg.remote_worker, f"which {component}")
        MessageHandler.info(f"[Remote] {component} already installed, skip installation")
        return
    except (subprocess.CalledProcessError, RuntimeError):
        pass

    remote_arch = ssh_run(cfg.remote_worker, "uname -m", capture=True)
    if whl_arch and whl_arch not in remote_arch:
        raise ValueError(f"[Remote] {whl_pkg_name} architecture '{whl_arch}' "
                         f"does not match '{remote_arch}' of {cfg.remote_worker.ip}")

    MessageHandler.info(f"[Remote] Copying {whl_pkg_name} to {cfg.remote_worker.ip}...")
    run(f"scp {cfg.whl_pkg_path} {cfg.remote_worker.user}@{cfg.remote_worker.ip}:{remote_path}")

    MessageHandler.info(f"[Remote] Installing {whl_pkg_name}...")
    ssh_run(cfg.remote_worker, f"pip3 install {remote_path} --disable-pip-version-check", timeout=PIP_INSTALL_TIMEOUT)

    try:
        ssh_run(cfg.remote_worker, f"which {component}")
        MessageHandler.info(f"[Remote] {component} installed successfully")
    except subprocess.CalledProcessError:
        raise ValueError(f"[Remote] {component} installation failed")


def install(cfg: Config) -> str:
    """Install components."""
    if not cfg.whl_pkg_path and not is_installed("ascend-fd") and not is_installed("alan-fd"):
        raise ValueError("No whl package path specified and there are no component that is pre-installed")

    component = install_local(cfg)
    if cfg.dual_worker_scene:
        install_remote(cfg, component)
    return component


# =============================================================================
# Command Execution Functions
# =============================================================================

def execute_cmd(cmd: str, timeout: int = 5, capture=False):
    """Execute command with specified timeout."""
    args = cmd.split()
    if capture:
        completed = subprocess.run(args, text=True, capture_output=True, timeout=timeout)
        if completed.returncode != 0:
            error_msg = f"Command '{cmd}' failed with return code {completed.returncode}{os.linesep}"
            if completed.stdout:
                error_msg += f"Output: {completed.stdout.strip()}{os.linesep}"
            if completed.stderr:
                error_msg += f"Error output: {completed.stderr.strip()}"
            raise RuntimeError(error_msg)
        return completed.stdout.strip()
    else:
        completed = subprocess.run(args, timeout=timeout)
        if completed.returncode != 0:
            raise RuntimeError(f"Command '{cmd}' failed with return code {completed.returncode}")
        return None


def run(cmd: str, capture=False, timeout=5):
    """Run local command."""
    try:
        return execute_cmd(cmd, timeout, capture)
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"[Local] Execute command timed out: {cmd}")


def ssh_run(host: HostInfo, cmd, capture=False, timeout=5):
    """Run command on remote host via SSH."""
    ssh_cmd = f"ssh {host.user}@{host.ip} {cmd}"
    try:
        return execute_cmd(ssh_cmd, timeout, capture)
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"[Remote] Execute command timed out: {cmd}")


def validate_remote_availability(host: str, user: str, timeout: int = 1) -> bool:
    """Validate if remote host is accessible."""
    try:
        execute_cmd(f"ping -c 1 {host}", timeout=timeout)
    except subprocess.TimeoutExpired:
        MessageHandler.warning(f"Ping timeout for {host}")
        return False
    except Exception as e:
        MessageHandler.warning(f"Ping failed for {host}: {e}")
        return False
    try:
        execute_cmd(f"ssh {user}@{host} -o BatchMode=yes echo Check passwordless > /dev/null 2>&1", timeout=timeout)
    except subprocess.TimeoutExpired:
        MessageHandler.warning(f"SSH timeout for {user}@{host}")
        return False
    except Exception as e:
        MessageHandler.warning(f"Failed to verify passwordless configuration for {user}@{host}: {e}")
        return False
    MessageHandler.info(f"[Remote] Ping {host} success")
    return True


# =============================================================================
# Log Parsing and Diagnosis Functions
# =============================================================================

def parse_local(local_cmd: str):
    """Parse logs on local machine."""
    MessageHandler.info(f"[Local] Parsing logs on the local machine ...")
    print(run(local_cmd, capture=True, timeout=PARSING_TIMEOUT))


def create_parse_agent_cmd(cfg: Config, cmd: str, output_path: str) -> str:
    for key, value in asdict(cfg.log_path).items():
        if not value:
            continue
        cmd += f" --{key} {value}"

    cmd += f" -o {output_path}"
    return cmd


def parse_remote(agent_path: str, cfg: Config, cmd: str, remote_path: str):
    """Parse logs on remote host."""
    MessageHandler.info(f"[Remote] Creating directory on {cfg.remote_worker.ip} ...")
    ssh_run(cfg.remote_worker, f"mkdir -p {REMOTE_AGENT_PATH}")
    MessageHandler.info(f"[Remote] Deploying parse agent to {cfg.remote_worker.ip} ...")
    run(f"scp {agent_path} {cfg.remote_worker.user}@{cfg.remote_worker.ip}:{remote_path}")
    cmd += f" --master_user {cfg.local_worker.user} --master_ip {cfg.local_worker.ip} " + \
           f"--remote_ip {cfg.remote_worker.ip}"
    MessageHandler.info(f"[Remote] Parsing logs on {cfg.remote_worker.ip} ...")
    MessageHandler.warning("[Remote] Please make sure that the remote worker hold the same directories as "
                           "the local worker, otherwise the parse agent will fail ...")
    try:
        print(ssh_run(cfg.remote_worker, cmd, capture=True, timeout=PARSING_TIMEOUT))
    except RuntimeError as e:
        MessageHandler.warning(f"[Remote] Parsing failed on {cfg.remote_worker.ip}, the reason is: {e}")


def deploy_and_parse(cfg: Config, component: str, output_path):
    """Deploy and parse logs."""
    agent_path = os.path.join(os.path.dirname(__file__), "parse_agent.py")
    if not os.path.exists(agent_path):
        raise FileNotFoundError("Required file 'parse_agent.py' not found in the same directory of 'orchestrator.py'")
    local_worker_dir_name = cfg.local_worker.ip or "worker-0"
    local_worker_dir = os.path.join(output_path, local_worker_dir_name)
    os.makedirs(local_worker_dir, mode=DEFAULT_DIR_MODE)
    local_cmd = create_parse_agent_cmd(cfg, f"python3 {agent_path} --component {component}", local_worker_dir)
    parse_local(local_cmd)

    if cfg.dual_worker_scene:
        remote_path = os.path.join(REMOTE_AGENT_PATH, "parse_agent.py")
        remote_cmd = create_parse_agent_cmd(cfg, f"python3 {remote_path} --component {component}", output_path)
        parse_remote(agent_path, cfg, remote_cmd, remote_path)


def diagnose(component: str, input_path: str, output_path: str):
    """Diagnose logs on local machine."""
    MessageHandler.info(f"[Local] Diagnosing logs on the local machine ...")
    print(run(f"{component} diag -i {input_path} -o {output_path}", capture=True, timeout=DIAGNOSIS_TIMEOUT))


# =============================================================================
# Main Orchestration Function
# =============================================================================

def orchestrate():
    """Main orchestration function."""
    args = command_line()
    data = read_cfg(args.input)

    cfg = validation(data)
    component = install(cfg)
    parse_results_path = os.path.join(args.output, "parse_results")
    deploy_and_parse(cfg, component, parse_results_path)
    diagnose(component, input_path=parse_results_path, output_path=args.output)


if __name__ == "__main__":
    try:
        orchestrate()
    except Exception as err:
        MessageHandler.error(f"orchestrator.py failed due to: {str(err)}")
        sys.exit(1)
