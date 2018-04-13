import os.path
import json
from haikunator import Haikunator
from azure.common.credentials import ServicePrincipalCredentials
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.resource.resources.models import DeploymentMode


# setup your Azure
# subsription id
my_subscription_id = '%%%%%%%%%%%%%%%%%%%%%%%%%'
# id azure ad
tenant = '%%%%%%%%%%%%%%%%%%%%%%%%%'
# id app
client_id = '%%%%%%%%%%%%%%%%%%%%%%%%%'
# key of app
secret = '%%%%%%%%%%%%%%%%%%%%%%%%%'


class Deployer(object):
    name_generator = Haikunator()

    def __init__(self, subscription_id, resource_group, pub_ssh_key_path='~/.ssh/id_rsa.pub'):
        self.subscription_id = subscription_id
        self.resource_group = resource_group
        self.dns_label_prefix = self.name_generator.haikunate()

        pub_ssh_key_path = os.path.expanduser(pub_ssh_key_path)
        # Will raise if file not exists or not enough permission
        with open(pub_ssh_key_path, 'r') as pub_ssh_file_fd:
            self.pub_ssh_key = pub_ssh_file_fd.read()

        self.credentials = ServicePrincipalCredentials(
            client_id=client_id,
            secret=secret,
            tenant=tenant
        )

        self.client = ResourceManagementClient(self.credentials, self.subscription_id)

    def deploy(self):
        """Deploy the template to a resource group."""
        self.client.resource_groups.create_or_update(
            self.resource_group,
            {
                'location': 'westeurope'
            }
        )

        template_path = os.path.join(os.path.dirname(__file__), 'tpl.json')
        with open(template_path, 'r') as template_file_fd:
            template = json.load(template_file_fd)

        parameters = {
            'sshKeyData': self.pub_ssh_key,
            'vmName': 'telegram-socks-vm',
            'dnsLabelPrefix': self.dns_label_prefix
        }
        parameters = {k: {'value': v} for k, v in parameters.items()}

        deployment_properties = {
            'mode': DeploymentMode.incremental,
            'template': template,
            'parameters': parameters
        }

        deployment_async_operation = self.client.deployments.create_or_update(
            self.resource_group,
            'telegram',
            deployment_properties
        )
        deployment_async_operation.wait()

    def destroy(self):
        """Destroy the given resource group"""
        self.client.resource_groups.delete(self.resource_group)



my_resource_group = 'telegram-socks-rg'
my_pub_ssh_key_path = os.path.expanduser('~/.ssh/id_rsa.pub')

msg = "\nИнициализируем Нагибатор РКН 3000. Ваш Subscription ID: {}, resource group: {}" \
    "\npublic ключ для ssh: {}...\n\n"
msg = msg.format(my_subscription_id, my_resource_group, my_pub_ssh_key_path)
print(msg)

# Initialize the deployer class
deployer = Deployer(my_subscription_id, my_resource_group, my_pub_ssh_key_path)

print("Старт деплоя Нагибатора РКН 3000... \n\n")
my_deployment = deployer.deploy()

print("Done deploying!!\n\nYou can connect via: `ssh telegram@{}.westeurope.cloudapp.azure.com`".format(deployer.dns_label_prefix))

# Destroy the resource group

# deployer.destroy()
