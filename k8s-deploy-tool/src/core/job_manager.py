import yaml
import os
import logging
from typing import Dict
from abc import ABC, abstractmethod

from kubernetes import client, config, dynamic
from kubernetes.client import ApiClient
from kubernetes.client.rest import ApiException

from ..core.template_engine import TemplateEngine
from ..core.utils import print_pod_table, print_dict


class JobManager(ABC):
    """Kubernetes集群管理类"""
    def __init__(self, kubeconfig_path: str = "~/.kube/config"):
        self.kubeconfig_path = kubeconfig_path
        self.template_engine = TemplateEngine()

    def init_k8s_client(self):
        try:
            if self.kubeconfig_path:
                config.load_kube_config(self.kubeconfig_path)
            else:
                config.load_kube_config()

            self.core_v1 = client.CoreV1Api()
            self.apps_v1 = client.AppsV1Api()
            self.dynamic_client = dynamic.DynamicClient(ApiClient())
        except Exception as e:
            raise Exception(f"Kubernetes客户端初始化失败: {str(e)}")
            
    def create_or_update_deployment(self, deployment_manifest: dict, namespace: str = "default") -> Dict:
        """创建或更新Deployment"""        
        try: 
            result = self.apps_v1.create_namespaced_deployment(
                            namespace=namespace, 
                            body=deployment_manifest
                        )
        except ApiException as e:
            if e.status != 409:  
                raise Exception(f"创建Deployment失败: {e}")
            logging.info(f"更新已存在的Deployment: {deployment_manifest['metadata']['name']}")
            result = self.apps_v1.patch_namespaced_deployment(
                name=deployment_manifest['metadata']['name'],
                namespace=namespace,
                body=deployment_manifest
            )
        return result
    
    def create_or_update_service(self, service_manifest: dict, namespace: str = "default") -> Dict:
        """创建或更新Service"""
        try: 
            result = self.core_v1.create_namespaced_service(
                            namespace=namespace, 
                            body=service_manifest
                        )
        except ApiException as e:
            if e.status != 409:  
                raise Exception(f"创建Service失败: {e}")
            logging.info(f"更新已存在的Service: {service_manifest['metadata']['name']}")
            result = self.core_v1.patch_namespaced_service(
                name=service_manifest['metadata']['name'],
                namespace=namespace,
                body=service_manifest
            )
        return result
    
    @abstractmethod
    def render_template(self, config) -> dict:
        """渲染模板"""
        raise NotImplementedError

    @abstractmethod
    def deploy_app(self, rendered_templates: dict, namespace: str) -> dict:
        """部署应用"""
        raise NotImplementedError
    
    @abstractmethod
    def delete_app(self, app_name: str, namespace: str = "default", delete_ns: bool = False):
        """删除指定应用的所有资源"""
        raise NotImplementedError

    @abstractmethod
    def show_app_status(self, app_name: str, namespace: str = "default"):
        """显示指定应用的状态"""
        raise NotImplementedError
    
    def validate_config(self, config: dict) -> None:
        """验证配置文件"""
        if len(config) == 0:
            raise ValueError("配置文件不能为空")

        if "app_name" not in config:
            raise ValueError("配置文件中缺少app_name字段")
        
    def list_pods(self, namespace: str = "default", label_selector: str = ""):
        """列出指定命名空间下的Pod"""
        try:
            pod_list =  self.core_v1.list_namespaced_pod(namespace=namespace, label_selector=label_selector)
            pods = []
            for pod in pod_list.items:
                pods.append(pod)
            return pods
        except ApiException as e:
            raise Exception(f"列出Pod失败: {e.reason}")
    
    def get_deployment(self, app_name: str, namespace: str = "default"):
        """获取Deployment对象"""
        try:
            deploy = self.apps_v1.read_namespaced_deployment(name=app_name, namespace=namespace)
            return deploy
        except ApiException as e:
            raise Exception(f"获取Deployment失败: {e.reason}")
        
    def delete_deployment(self, deployment_name: str, namespace: str):
        """删除Deployment资源"""
        self.init_k8s_client()
        logging.info(f"删除Deployment资源: namespace={namespace}, name={deployment_name}")
        try:
            self.apps_v1.delete_namespaced_deployment(
                name=deployment_name,
                namespace=namespace
            )
        except ApiException as e:
            if e.status != 404:
                raise Exception(f"删除Deployment失败: {e.reason}")
            else:
                logging.info("Deployment不存在，跳过删除")
    
    def delete_service(self, service_name: str, namespace: str):
        """删除Service资源"""
        self.init_k8s_client()
        logging.info(f"删除Service资源: namespace={namespace}, name={service_name}")
        try:
            self.core_v1.delete_namespaced_service(
                name=service_name,
                namespace=namespace
            )
        except ApiException as e:
            if e.status != 404:
                raise Exception(f"删除Service失败: {e.reason}")
            else:
                logging.info("Service不存在，跳过删除")


class ISVCManager(JobManager):
    group="ome.io"
    version="v1beta1"
    plural="InferenceService"
    app_label_key="ome.io/inferenceservice"
    component_label_key="component"

    def __init__(self, kubeconfig_path: str = "~/.kube/config"):
        super().__init__(kubeconfig_path)
        self.custom_api = None
        self.deploy_funcs = {
            'inferenceservice': self._create_or_update_isvc,
            'service': self.create_or_update_service,
            'deployment': self.create_or_update_deployment
        }

    def init_k8s_client(self):
        super().init_k8s_client()
        try:
            self.custom_api = self.dynamic_client.resources.get(
                api_version=f"{self.group}/{self.version}",
                kind=self.plural,
            )
        except Exception as e:
            logging.error(f"初始化{self.group}/{self.version}/{self.plural}客户端失败: {e}")

    def validate_config(self, config: dict) -> None:
        """验证配置文件"""
        super().validate_config(config)
        if "inference_service" not in config:
            raise ValueError("缺少inference_service配置")
        isvc = config["inference_service"]
        if "model_name" not in isvc:
            raise ValueError("inference_service缺少model_name字段")
        if "engine" not in isvc:
            raise ValueError("inference_service缺少engine字段")
        engine = isvc["engine"]
        self._validate_instance(engine)
        if "decoder" in isvc:
            decoder = isvc["decoder"]
            self._validate_instance(decoder)
    
    def _validate_instance(self, instance: dict) -> None:
        """验证实例配置"""
        if "min_replicas" in instance:
            if not isinstance(instance["min_replicas"], int) or instance["min_replicas"] < 1:
                raise ValueError("min_replicas必须为大于0的整数")

        if "max_replicas" in instance:
            if not isinstance(instance["max_replicas"], int) or instance["max_replicas"] < 1 or instance["max_replicas"] < instance["min_replicas"] or instance["max_replicas"] > 64:
                raise ValueError("max_replicas必须为大于0的整数, 且不小于min_replicas, 不大于512")
        
        if "pod_num" not in instance:
            raise ValueError("engine缺少pod_num字段")
        
        if not isinstance(instance["pod_num"], int) or instance["pod_num"] < 1 or instance["pod_num"] > 128:
            raise ValueError("pod_num必须为大于0的整数, 且不大于128")

        if "image" in instance:
            if not isinstance(instance["image"], str) or not instance["image"] :
                raise ValueError("image必须为非空字符串")
            image = instance["image"]
            if ":" not in image:
                raise ValueError("image格式不正确, 需包含tag信息")
            image_name, image_tag = image.rsplit(":", 1)
            if not image_name or not image_tag:
                raise ValueError("image格式不正确, 镜像名或tag不能为空")
        
        if "npu_num" in instance:
            if not isinstance(instance["npu_num"], int) or instance["npu_num"] < 0 or instance["npu_num"] > 16:
                raise ValueError("npu_num必须为大于等于0的整数, 且不大于16")
        
    def render_template(self, config) -> dict:
        """渲染模板"""
        rendered_templates = self.template_engine.render_template("ome/inference_service.yaml.j2", config)
        logging.info("渲染ISVC模板完成")
        if "decoder" in config["inference_service"]:
            rendered_templates.update(self.template_engine.render_template("kv_cache/memfabric_store.yaml.j2", config))
            logging.info("渲染MF_deploy模板完成")
            rendered_templates.update(self.template_engine.render_template("kv_cache/memfabric_service.yaml.j2", config))
            logging.info("渲染MF_service模板完成")
        return rendered_templates
    
    def deploy_app(self, rendered_templates: dict, namespace: str) -> dict:
        """部署应用到Kubernetes集群"""
        self.init_k8s_client()
        logging.info("部署到Kubernetes集群...")

        results = {}
        for resource_type, yaml_content in rendered_templates.items():
            yaml_documents = list(yaml.safe_load_all(yaml_content))
            for doc in yaml_documents:
                if not doc:
                    continue
                kind = doc.get('kind', '').lower()
                name = doc['metadata']['name']
                logging.info(f"创建资源: kind={kind}, name={name}, namespace={namespace}")

                deploy_func = self.deploy_funcs.get(kind)
                if not deploy_func:
                    logging.warning(f"不支持的资源类型: {kind}")
                    continue           
                results[f"{kind}/{name}"] = deploy_func(doc, namespace) 
                
        return results

    def _create_or_update_isvc(self, isvc_manifest: dict, namespace: str) -> dict:
        logging.info(f"创建InferenceService资源: namespace={namespace}, name={isvc_manifest['metadata']['name']}")
        try:
            result = self.custom_api.create(body=isvc_manifest)
        except ApiException as e:
            if e.status != 409:  
                raise Exception(f"创建InferenceService失败: {e}")
            try:
                flag = input("资源已存在，确认是否更新[y/n]: ")
                if flag.lower() == 'n':
                    return {}
                logging.info(f"更新InferenceService资源: namespace={namespace}, name={isvc_manifest['metadata']['name']}")
                result = self.custom_api.patch(
                    name=isvc_manifest['metadata']['name'],
                    namespace=namespace,
                    body=isvc_manifest,
                    content_type="application/merge-patch+json")     
            except ApiException as e:
                raise Exception(f"更新InferenceService失败: {e}")
        return result

    def _delete_isvc(self, isvc_name: str, namespace: str):
        logging.info(f"删除InferenceService资源: namespace={namespace}, name={isvc_name}")
        try:
            self.custom_api.delete(name=isvc_name, namespace=namespace)
        except ApiException as e:
            if e.status != 404:
                raise Exception(f"删除InferenceService失败: {e.reason}")
            else:
                logging.info("InferenceService不存在，跳过删除")\
                
    def _delete_mf_store(self, mf_name: str, namespace: str):
        logging.info(f"删除MemFabric资源: namespace={namespace}, name={mf_name}")
        self.delete_deployment(mf_name, namespace)
        self.delete_service(mf_name, namespace)

    def delete_app(self, app_name: str, namespace: str = "default"):
        """删除应用"""
        self.init_k8s_client()
        logging.info(f"删除应用: namespace={namespace}, name={app_name}")
        self._delete_isvc(app_name, namespace)
        self._delete_mf_store(f"{app_name}-mf-store", namespace)
        self._wait_for_deletion(app_name, namespace)
    
    def _wait_for_deletion(self, app_name: str, namespace: str, timeout: int = 300):
        """等待资源完全删除"""
        import time
        
        start_time = time.time()
        label_selector = f"{self.app_label_key}={app_name}"
        
        while time.time() - start_time < timeout:
            # 检查是否还有Pod在运行
            pods = self.core_v1.list_namespaced_pod(
                namespace=namespace, 
                label_selector=label_selector
            )
            
            if not pods.items:
                logging.info("所有资源已成功删除")
                return
            
            logging.info(f"等待资源删除... 剩余Pod数量: {len(pods.items)}")
            time.sleep(5)
        
        raise TimeoutError("资源删除超时")
    
    def show_app_status(self, app_name: str, namespace: str = "default") -> Dict:
        """显示应用状态"""
        self.init_k8s_client()
        self._show_isvc_status(app_name, namespace)
        self._show_mf_store_status(app_name, namespace)
        self._show_pods_status(app_name, namespace)

    def _get_isvc(self, app_name: str, namespace: str = "default"):
        try:
            isvc = self.custom_api.get(namespace=namespace, name=app_name)
            return isvc
        except ApiException as e:
            raise Exception(f"获取InferenceService失败: {e.reason}")
    
    def _show_isvc_status(self, app_name: str, namespace: str = "default"):
        isvc = self._get_isvc(app_name, namespace)
        print(f"=== InferenceService 状态 ===")
        print_dict(isvc.status.to_dict())
        print("\n")

    def _show_mf_store_status(self, app_name: str, namespace: str = "default"):
        deploy = self.get_deployment(f"{app_name}-mf-store", namespace)
        print(f"=== MemFabric Store Deployment 状态 ===")
        deploy_status = {
                'available_replicas': deploy.status.available_replicas,
                'ready_replicas': deploy.status.ready_replicas,
                'replicas': deploy.status.replicas,
                'updated_replicas': deploy.status.updated_replicas
            }
        print(deploy_status)
        print("\n")
        
    def _show_pods_status(self, app_name: str, namespace: str = "default"):
        pods = self.list_pods(namespace=namespace, label_selector=f"{self.app_label_key}={app_name}")
        pod_component = {}
        for pod in pods:
            component = pod.metadata.labels.get('component')
            if component not in pod_component:
                pod_component[component] = []
            pod_component[component].append(pod)
        
        for component, pods in pod_component.items():
            print(f"=== {component} Pods 状态 ===")
            print_pod_table(pods, wide=True)
            print("\n")


class SSVCManager(JobManager):
    plural = "StormService"
    group = "orchestration.aibrix.ai"
    version = "v1alpha1"
    app_label_key="storm-service-name"
    component_label_key="role-name"

    def __init__(self, kubeconfig_path: str = "~/.kube/config"):
        super().__init__(kubeconfig_path)
        self.custom_api = None
        self.deploy_funcs = {
            'stormservice': self._create_or_update_ssvc,
            'service': self.create_or_update_service,
        }
    
    def init_k8s_client(self):
        super().init_k8s_client()
        try:
            self.custom_api = self.dynamic_client.resources.get(
                api_version=f"{self.group}/{self.version}",
                kind=self.plural,
            )
        except Exception as e:
            logging.error(f"初始化{self.group}/{self.version}/{self.plural}客户端失败: {e}")

    def validate_config(self, config: dict) -> None:
        """验证配置文件"""
        super().validate_config(config)
        if "storm_service" not in config:
            raise ValueError("缺少storm_service配置")
        isvc = config["storm_service"]
        if "model_name" not in isvc:
            raise ValueError("inference_service缺少model_name字段")
        if "model_path" not in isvc:
            raise ValueError("inference_service缺少model_path字段")
        if "prefill" not in isvc:
            raise ValueError("inference_service缺少prefill字段")
        prefill = isvc["prefill"]
        if "image" not in prefill:
            raise ValueError("prefill缺少image字段")
        decode = isvc["decode"]
        if "image" not in decode:
            raise ValueError("decode缺少image字段")
        if "decode" not in isvc:
            raise ValueError("inference_service缺少decode字段")
        if "distributed_dp" in isvc:
            if isvc["distributed_dp"] != "true" and isvc["distributed_dp"] != "false":
                raise ValueError("distributed_dp字段值只能是true或false")
            if isvc["distributed_dp"] == "true" and "routing" not in isvc:
                raise ValueError("distributed_dp为\"true\", inference_service缺少routing字段")
        
    def render_template(self, config) -> dict:
        """渲染模板"""
        logging.info("渲染模板...")
        rendered_templates = self.template_engine.render_template("aibrix/stormservice.yaml.j2", config)
        logging.info("渲染stormservice模板完成")
        rendered_templates.update({"sever_services": []})
        self._render_svc_template("prefill", config, rendered_templates)
        self._render_svc_template("decode", config, rendered_templates)
        return rendered_templates
    
    def _render_svc_template(self, role_name, config, rendered_templates):
        storm_service = config["storm_service"]
        sever_services = rendered_templates["sever_services"]
        inst = storm_service[role_name]
        replicas = inst.get("replicas", 1)
        pg_size = inst.get("podGroupSize", 1)
        dp_size = inst.get("dp_size", 1)
        dp_size_local = dp_size // pg_size
        distributed_dp = storm_service.get("distributed_dp", "true")
        
        config["distributed_dp"] = distributed_dp
        app_name = config["app_name"]
        config["role_name"] = role_name
        for role_index in range(replicas):
            config["role_index"] = role_index
            service_name  = f"{app_name}-{role_name}-{role_index}"
            config["service_name"] = service_name
            if distributed_dp == "false":
                if pg_size > 1:
                    config["pg_index"] = 0
                    config["service_name"] = f"{service_name}-0"
                logging.info(f"渲染{service_name}模板, replicas={replicas}, pg_size={pg_size}, dp_size={dp_size}, dp_size_local={dp_size_local}, distributed_dp={distributed_dp}")
                sever_services.append(self.template_engine.render_template("aibrix/server_service.yaml.j2", config))
            else:
                config["dp_size_local"] = dp_size_local
                for pg_index in range(pg_size):
                    if pg_size > 1:
                        config["pg_index"] = pg_index
                        config["service_name"] = f"{service_name}-{pg_index}"
                    logging.info(f"渲染{service_name}模板, replicas={replicas}, pg_size={pg_size}, dp_size={dp_size}, dp_size_local={dp_size_local}, distributed_dp={distributed_dp}")
                    sever_services.append(self.template_engine.render_template("aibrix/server_service.yaml.j2", config))
        config.pop("role_index", None)
        config.pop("pg_index", None)
        config.pop("dp_size_local", None)
        config.pop("role_name", None)
    
    def deploy_app(self, rendered_templates: dict, namespace: str) -> dict:
        """部署应用到Kubernetes集群"""
        self.init_k8s_client()
        logging.info("部署到Kubernetes集群...")
        results = {}
        for _, yaml_content in rendered_templates.items():
            self._deploy_component(yaml_content, namespace, results)                
        return results
    
    def _deploy_component(self, yaml_content, namespace: str, results: dict) -> dict:
        if isinstance(yaml_content, str):
            yaml_documents = list(yaml.safe_load_all(yaml_content))
            for doc in yaml_documents:
                if not doc:
                    continue
                
                kind = doc.get('kind', '').lower()
                name = doc['metadata']['name']
                logging.info(f"创建资源: kind={kind}, name={name}, namespace={namespace}")

                deploy_func = self.deploy_funcs.get(kind)
                if not deploy_func:
                    logging.warning(f"不支持的资源类型: {kind}")
                    continue           
                results[f"{kind}/{name}"] = deploy_func(doc, namespace)
        if isinstance(yaml_content, list):
            for item in yaml_content:
                for _, value in item.items():
                    self._deploy_component(value, namespace, results)

    def delete_app(self, app_name: str, namespace: str = "default"):
        """删除应用"""
        self.init_k8s_client()
        logging.info(f"删除应用: namespace={namespace}, name={app_name}")
        self._delete_ssvc(app_name, namespace)
        self.delete_service(app_name, namespace)
        self._wait_for_deletion(app_name, namespace)

    def delete_service(self, service_name: str, namespace: str):
        """删除Service资源"""
        self.init_k8s_client()
        label_selector = f"{self.app_label_key}={service_name}"
        try:
            service_list = self.core_v1.list_namespaced_service(namespace=namespace, label_selector=label_selector)
            if not service_list.items:
                print(f"在命名空间 '{namespace}' 中未找到标签为 '{label_selector}' 的 Service。")
                return
        except ApiException as e:
            print(f"获取 Service 列表时发生 API 异常: {e}")
            return

        logging.info(f"删除Service资源: namespace={namespace}, name={service_name}")
        for service in service_list.items:
            super().delete_service(service.metadata.name, namespace)

    def show_app_status(self, app_name: str, namespace: str = "default") -> Dict:
        """显示应用状态"""
        self.init_k8s_client()
        self._show_ssvc_status(app_name, namespace)
        self._show_pods_status(app_name, namespace)

    def _create_or_update_ssvc(self, isvc_manifest: dict, namespace: str) -> dict:
        logging.info(f"创建StormService资源: namespace={namespace}, name={isvc_manifest['metadata']['name']}")
        try:
            result = self.custom_api.create(body=isvc_manifest)
        except ApiException as e:
            if e.status != 409:  
                raise Exception(f"创建StormService失败: {e}")
            try:
                flag = input("资源已存在，确认是否更新[y/n]: ")
                if flag.lower() == 'n':
                    return {}
                logging.info(f"更新StormService资源: namespace={namespace}, name={isvc_manifest['metadata']['name']}")
                result = self.custom_api.patch(
                    name=isvc_manifest['metadata']['name'],
                    namespace=namespace,
                    body=isvc_manifest,
                    content_type="application/merge-patch+json")     
            except ApiException as e:
                raise Exception(f"更新StormService失败: {e}")
        return result
    
    def _delete_ssvc(self, isvc_name: str, namespace: str):
        logging.info(f"删除StormService资源: namespace={namespace}, name={isvc_name}")
        try:
            self.custom_api.delete(name=isvc_name, namespace=namespace)
        except ApiException as e:
            if e.status != 404:
                raise Exception(f"删除StormService失败: {e.reason}")
            else:
                logging.info("StormService不存在，跳过删除")
    
    def _wait_for_deletion(self, app_name: str, namespace: str, timeout: int = 300):
        """等待资源完全删除"""
        import time
        
        start_time = time.time()
        label_selector = f"{self.app_label_key}={app_name}"
        
        while time.time() - start_time < timeout:
            # 检查是否还有Pod在运行
            pods = self.core_v1.list_namespaced_pod(
                namespace=namespace, 
                label_selector=label_selector
            )
            
            if not pods.items:
                logging.info("所有资源已成功删除")
                return
            
            logging.info(f"等待资源删除... 剩余Pod数量: {len(pods.items)}")
            time.sleep(5)
        
        raise TimeoutError("资源删除超时")
    
    def _get_ssvc(self, app_name: str, namespace: str) -> dict:
        try:
            isvc = self.custom_api.get(namespace=namespace, name=app_name)
            return isvc
        except ApiException as e:
            raise Exception(f"获取StormService失败: {e.reason}")
    
    def _show_ssvc_status(self, app_name: str, namespace: str = "default"):
        isvc = self._get_ssvc(app_name, namespace)
        print(f"=== StormService 状态 ===")
        print_dict(isvc.status.to_dict())
        print("\n")

    def _show_pods_status(self, app_name: str, namespace: str = "default"):
        pods = self.list_pods(namespace=namespace, label_selector=f"{self.app_label_key}={app_name}")
        pod_component = {}
        for pod in pods:
            component = pod.metadata.labels.get(self.component_label_key, "unknown")
            if component not in pod_component:
                pod_component[component] = []
            pod_component[component].append(pod)
        
        for component, pods in pod_component.items():
            print(f"=== {component} Pods 状态 ===")
            print_pod_table(pods, wide=True)
            print("\n")


class ManagerFactory:
    @staticmethod
    def create(kubeconfig_path: str = "~/.kube/config") -> JobManager:
        """根据环境变量创建JobManager实例"""
        cr_type = os.getenv("SERVING_FRAMEWORK", "ome")
        if cr_type == "ome":
            return ISVCManager(kubeconfig_path=kubeconfig_path)
        elif cr_type == "aibrix":
            return SSVCManager(kubeconfig_path=kubeconfig_path)
        else:
            raise ValueError("Unknown serving framework")