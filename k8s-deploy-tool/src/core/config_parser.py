import yaml
from typing import Dict, Any

class ConfigParser:
    """配置解析器，负责读取和验证用户参数"""
    def load_config(self, config_path: str) -> Dict[str, Any]:
        """从YAML文件加载配置"""
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)
            return config
        except Exception as e:
            raise ValueError(f"配置加载失败: {str(e)}")