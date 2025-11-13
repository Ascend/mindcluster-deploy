from typing import Dict, Any

from jinja2 import Environment, FileSystemLoader

class TemplateEngine:
    """模板引擎，负责渲染YAML模板"""
    def __init__(self, template_dir: str = "src/templates"):
        self.template_dir = template_dir
        self.env = Environment(
            loader=FileSystemLoader(template_dir),
            trim_blocks=True,
            lstrip_blocks=True
        )
    
    def render_template(self, template_name: str, params: Dict[str, Any]) -> Dict[str, str]:
        """渲染指定模板"""
        try:
            resource_type = template_name.replace('.yaml.j2', '')
            template = self.env.get_template(template_name)
            return {resource_type: template.render(**params)}
        except Exception as e:
            raise ValueError(f"模板渲染失败: {str(e)}")
