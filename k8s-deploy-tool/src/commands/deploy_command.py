import logging
from typing import Dict, Any

from ..core.config_parser import ConfigParser
from ..core.job_manager import ManagerFactory


class DeployCommand:
    """部署命令处理器"""
    def __init__(self, kubeconfig_path: str = "~/.kube/config"):
        self.config_parser = ConfigParser()
        self.kubeconfig_path = kubeconfig_path
    
    def execute(self, config_path: str, dry_run: bool = False) -> Dict[str, Any]:
        """执行部署命令"""
        logging.info("加载配置文件...")
        config = self.config_parser.load_config(config_path)
        self.job_manager = ManagerFactory.create(kubeconfig_path=self.kubeconfig_path)
        self.job_manager.validate_config(config)
        rendered_templates = self.job_manager.render_template(config)

        if dry_run:
            return {
                'config': config,
                'rendered_templates': rendered_templates,
                'deployed': False
            }
        
        results = self.job_manager.deploy_app(rendered_templates, config.get('app_namespace', 'default')) 

        return {
            'config': config,
            'results': results,
            'deployed': True
        }
