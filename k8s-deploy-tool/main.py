#!/usr/bin/env python3
import click
import logging

from src.commands.deploy_command import DeployCommand
from src.commands.delete_command import DeleteCommand
from src.commands.status_command import StatusCommand

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(), logging.FileHandler('k8s_deploy_tool.log', mode='a', encoding='utf-8')],
    encoding='utf-8',
)

@click.group()
def cli():
    """Kubernetes部署工具"""
    pass

@cli.command()
@click.option('--config', '-c', required=True, help='配置文件路径')
@click.option('--dry-run', is_flag=True, help='试运行模式，不实际部署')
@click.option('--kubeconfig', '-k', default='~/.kube/config', help='Kubeconfig文件路径')
def deploy(config, kubeconfig, dry_run):
    """部署应用到Kubernetes"""
    try:
        command = DeployCommand(kubeconfig)
        result = command.execute(config, dry_run)
    
        if dry_run:
            click.echo("=== 生成的YAML配置 ===")
            for resource_type, yaml_content in result['rendered_templates'].items():
                click.echo(f"\n--- {resource_type} ---")
                click.echo(yaml_content)
        else:
            click.echo("✅ 应用部署成功!")
            click.echo(f"应用名称: {result['config']['app_name']}")
            
    except Exception as e:
        click.echo(f"❌ 部署失败: {str(e)}", err=True)

@cli.command()
@click.option('--app-name', '-n', required=True, help='要删除的应用名称')
@click.option('--namespace', '-ns', default='default', help='Kubernetes命名空间')
@click.option('--kubeconfig', '-k', default='~/.kube/config', help='Kubeconfig文件路径')
def delete(app_name, namespace, kubeconfig):
    """从Kubernetes删除应用"""
    try:
        command = DeleteCommand(kubeconfig)
        result = command.execute(app_name, namespace)
        
        if result['deleted']:
            click.echo("✅ 应用删除成功!")
        else:
            click.echo("ℹ️ 删除操作已取消")
            
    except Exception as e:
        click.echo(f"❌ 删除失败: {str(e)}", err=True)

@cli.command()
@click.option('--app-name', '-n', required=True, help='应用名称')
@click.option('--namespace', '-ns', default='default', help='Kubernetes命名空间')
@click.option('--kubeconfig', '-k', default='~/.kube/config', help='Kubeconfig文件路径')
def status(app_name, namespace, kubeconfig):
    """查看应用部署状态"""
    try:
        command = StatusCommand(kubeconfig)
        command.execute(app_name, namespace)
    except Exception as e:
        click.echo(f"❌ 获取状态失败: {str(e)}", err=True)

if __name__ == '__main__':
    cli()