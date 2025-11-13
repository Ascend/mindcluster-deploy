from ..core.job_manager import ManagerFactory
        

class StatusCommand:
    """部署命令处理器"""
    def __init__(self, kubeconfig_path: str = None):
        self.k8s_manager = ManagerFactory.create(kubeconfig_path)

    def execute(self, app_name: str, namespace: str = "default"):
        """执行部署命令"""
        self.k8s_manager.show_app_status(app_name, namespace)

