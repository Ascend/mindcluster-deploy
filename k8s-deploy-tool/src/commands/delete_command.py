import logging
from typing import Dict, Any

from ..core.job_manager import ManagerFactory

class DeleteCommand:
    """删除命令处理器"""
    def __init__(self, kubeconfig_path: str = None):
        self.k8s_manager = ManagerFactory.create(kubeconfig_path)
    
    def execute(self, app_name: str, namespace: str = "default") -> Dict[str, Any]:
        """执行删除命令"""
        try:
            self.k8s_manager.delete_app(app_name, namespace)
            return {
                'deleted': True,
                'app_name': app_name,
                'namespace': namespace,
            }
        except Exception as e:
            logging.error(f"删除应用失败: {str(e)}")
            raise