terraform-demo/
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
├── backend.tf
└── modules/
    └── vpc/
        └── main.tf


terraform init       
terraform plan          
terraform apply        
terraform output         
terraform state list   
terraform destroy      
terraform destroy -auto-approve


terraform state list              
terraform state show aws_instance.web

terraform output                 
terraform output public_ip        

#  Workspace
terraform workspace list
terraform workspace new dev
terraform workspace select dev







# key word
block_type           terraform,provider,resource, variable,output,module

label1/label2        name after terraform(type,name)
label                name    

block body           {} 

argument             key=value

value                


# graph 
terraform graph | Out-File -Encoding ASCII graph.dot
dot -Tpng graph.dot -o graph.png





Terraform is an immutable, declarative, Infrastructure as Code provisioning language based on HashiCorp Configuration Language, or optionally JSON.
| 模块                                        | 占比     | 内容                                                                                 |
| ----------------------------------------- | ------ | ---------------------------------------------------------------------------------- |
## | 核心概念 (Understand Infrastructure as Code)  | 15–20% | Terraform 是 IaC、声明式 vs 命令式、state、plan/apply 流程                                     |

## | CLI 基础命令 (Use Terraform CLI)              | 15–20% | `init`, `plan`, `apply`, `destroy`, `fmt`, `validate`, `output`, `state`, `import` |


terraform destroy -target=azurerm_resource_group.production   # remove the target only

terraform init -upgrade Terraform 会主动检查模块源，看有没有新版本

terraform destroy -auto-approve    To force the destruction of resources without being prompted for confirmation, 

terraform init -migrate-state :
初始化新的后端（backend）。检测当前本地是否已有状态文件（terraform.tfstate）。询问是否要将本地状态迁移到新后端。将状态复制（迁移）到 S3 存储桶中。之后，Terraform 就会自动从远程 backend 读取/更新状态。

terraform plan -destroy="aws_instance.database"

### 
The prefix -/+ means that Terraform will destroy and recreate the resource, rather than updating it in-place. Some attributes and resources can be updated in-place and are shown with the ~ prefix.

### dynamic block
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow web traffic"

  dynamic "ingress" {
    for_each = var.ports

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

terraform plan -out=bryan

.terraform/providers

“You have manually created an EC2 instance in AWS.
How can you bring it under Terraform management?”
terraform import

terraform taint:
terraform taint aws_instance.web
terraform apply
意思是先 手动标记某个资源为“已损坏”（tainted）,destroy 再 create。

terraform state:
| 命令                                | 作用                            |
| --------------------------------- | ----------------------------- |
| `terraform state list`            | 查看当前 state 文件中有哪些资源           |
| `terraform state show <resource>` | 查看具体资源属性                      |
| `terraform state rm <resource>`   | 从 state 中移除某个资源（不会删 AWS 上的资源） |
| `terraform state mv <old> <new>`  | 改资源在 state 中的路径或名字            | the name is only in terraform,not in aws.

terraform show:
查看当前状态：

The terraform apply -replace command manually marks a Terraform-managed resource for replacement, forcing it to be destroyed and recreated on the apply execution.


## | 配置文件结构 (Write & Understand Configuration) | 20–25% | provider, variable, output, data, module, resource, dependencies                   |

module  -----  Supports versioning to maintain compatibility

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.90.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "xxxxx"
  tenant_id       = "yyyyy"
}

resource "azurerm_resource_group" "example" {
  name     = "demo-rg"
  location = "West Europe"
}



dependencies

.terraform.lock.hcl
Terraform 会自动生成 .terraform.lock.hcl 文件，
用于锁定 Provider 的版本号，确保团队环境一致。
## | State 管理 (Manage Terraform State)         | 10–15% | local vs remote backend、S3 + DynamoDB、drift、refresh     


terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "btk"
 
  workspaces {
    name = "bryan-prod"
  }
 }
}


lock:
Terraform state locking prevents concurrent modifications to the same state file.
If a process crashes or fails to release the lock, you can manually remove it using
* terraform force-unlock   <LOCK_ID>. *
Be cautious — only use this when no other Terraform process is running.


terraform plan -refresh-only command is used to create a plan whose goal is only to update the Terraform state to match any changes made. 'terraform refresh not recommand' 

In Terraform, the variable type `float` is not a valid type. Terraform supports variable types such as `string`, `map`, `bool`, and `number`, but not `float`.


variable "instance_count" {
  type = number 
  validation {
    condition     = var.instance_count >= 2
    error_message = "You must request at least two web instances."
  }
}

HCP Terraform 的变量体系
| 层级                     | 使用场景                      | 示例                                                       |
| ---------------------- | ------------------------- | -------------------------------------------------------- |
| **Run level**          | 仅本次执行有效（CLI 传参）           | `terraform apply -var="region=eu-west-2"`                |
| **Workspace level**    | 固定在单个 workspace 内         | 在 UI 中配置 “Terraform Variables” 或 “Environment Variables” |
| **Variable Set level** | 多个 workspace 共享           | 比如所有 dev 环境的 workspace 共用同一组 AWS credentials             |
| **Organization level** | 全 org 通用（全局 variable set） | 可选，在 org 内所有 workspace 生效（但不能跨 org）                      |

HCP Terraform can be managed from the CLI by using an API token. The API token serves as a secure way to authenticate and authorize CLI access to HCP Terraform resources and operations.


## | 模块与重用 (Modules)                           | 10%    | module source、本地模块、传参、output 共享                                                    |
### 如何解决 .tf 文件中的敏感信息问题
使用 Terraform 变量 + 环境变量
可以把密码放在单独的 .tfvars 文件
使用 HashiCorp Vault 集成


| 命令                     | 全称             | 作用范围                    |
| ---------------------- | -------------- | ----------------------- |
| `terraform state list` | 查看当前状态文件中有哪些资源 | 列出资源的“名字”列表（简要）         |
| `terraform show`       | 查看详细状态（所有属性）   | 展示所有资源的完整内容或 plan 的详细内容 |



Module repositories must use this three-part name format, terraform-<PROVIDER>-<NAME>.

The two Terraform commands used to download and update modules are:
terraform init: This command downloads and updates the required modules for the Terraform configuration.
terraform get: This command is used to download and update modules 


You can set TF_LOG to one of the log levels TRACE, DEBUG, INFO, WARN or ERROR to change the verbosity of the logs. 

## | Terraform Cloud & Workflow                | 10%    | workspace、remote execution、team governance   
Terraform Workspace
✅ 作用
在同一个配置中创建多个独立环境（state 隔离）。
比如你想在同一个项目里同时部署 dev / prod 环境。

| 命令                               | 功能             |
| -------------------------------- | -------------- |
| `terraform workspace list`       | 列出现有 workspace |
| `terraform workspace new dev`    | 新建 workspace   |
| `terraform workspace select dev` | 切换 workspace   |
| `terraform workspace show`       | 显示当前 workspace |

Terraform Cloud / Sentinel（简单了解）
Terraform Cloud

是 HashiCorp 官方的托管服务：

远程执行 Terraform；

存储状态文件；

团队协作；

工作空间（workspace）与权限管理。

Sentinel Policy:
Plan → Run Tasks → OPA → Cost Estimation → Sentinel → Apply
是 Terraform Cloud 的 策略引擎（Policy as Code）。用来定义规则，比如：不允许使用太大的实例；所有资源必须有标签；不能删除生产数据库。
“What is Sentinel used for?”
✅ 答案：Enforce governance policies in Terraform Cloud.




| 功能                            | Terraform Community | HCP Terraform |
| ----------------------------- | ------------------- | ------------- |
| 本地运行                          | ✅                   | ✅             |
| **远程运行（Remote Run）**          | ❌                   | ✅             |
| **私有模块注册表（Private Registry）** | ❌                   | ✅             |
| **VCS 自动集成（VCS Connection）**  | ❌                   | ✅             |
| 公共 Registry                   | ✅                   | ✅             |
| Providers                     | ✅                   | ✅             |
| 状态文件托管 (Remote State)         | ❌（需自己设 S3）          | ✅（自动）         |
| 团队访问控制                        | ❌                   | ✅             |
| 运行日志 & 审计                     | ❌                   | ✅             |
| Sentinel Policy               | ❌                   | ✅（商业版）        |



## | 生命周期与策略                                   | 5%     | lifecycle、depends_on、create_before_destroy、prevent_destroy、ignore_changes          |

#life
| 参数                      | 作用                         | 示例                |
| ----------------------- | -------------------------- | ----------------- |
| `create_before_destroy` | 先创建新资源，再销毁旧资源（避免中断）        | 常用于替换负载均衡、ASG 等   |
在 Terraform 替换资源时（比如修改了一个字段会导致资源重建）， 默认顺序是：先销毁旧的，再创建新的。 但有时候这样会中断服务（比如删除负载均衡、删除实例组）。

| `prevent_destroy`       | 防止被 `terraform destroy` 删除 | 常用于数据库、VPC、生产实例   |
| `ignore_changes`        | 忽略某些字段变化，不触发重建             | 常用于自动生成字段、外部修改的属性 |
Terraform 默认行为是“检测配置文件与实际资源不一致就改”。
但有时候资源的某些属性是：
被 AWS 自动生成的；
被其他进程或脚本修改的；
不希望 Terraform 去强制同步的。
| 场景                        | 理由                    |
| ------------------------- | --------------------- |
| AWS Security Group        | AWS 会自动添加规则（例如 LB）    |
| Auto Scaling Group        | desired_capacity 动态变化 |
| EKS / ECS 管理节点            | 自动扩缩容不应触发 plan        |
| EC2 实例标签                  | 允许外部加标签不触发 apply      |
| CloudWatch Alarm / Lambda | 自动化调整频繁更新             |

Terraform Registry use github


# parent pass var to child
父模块 main.tf
variable "region" {
  default = "eu-west-2"
}

module "server" {
  source = "./modules/server"
  region = var.region    # 👈 必须显式传入
}

子模块 ./modules/server/variables.tf
variable "region" {}

子模块 ./modules/server/main.tf
resource "aws_instance" "app" {
  ami           = "ami-123456"
  instance_type = "t3.micro"
  availability_zone = "${var.region}a"
}