# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# DataSunrise Cluster for Amazon Web Services
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.4.0"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

variable "regions_amis" {
  type    = map
  default = {	
		"eu-central-1" = "ami-0d3766a2ab2a1fed2"
		"eu-north-1" = "ami-0ac8bf2e73c9ded7b"
		"ap-south-1" = "ami-0f2103998831d90f6"
		"eu-west-3" = "ami-0196e2d4359981872"
		"eu-west-2" = "ami-03162da2f3cfb662c"
		"eu-west-1" = "ami-038d5cc88510fef11"
		"ap-northeast-2" = "ami-0bce63058c3b0f372"
		"me-south-1" = "ami-0ebf254648c36b05b"
		"ap-northeast-1" = "ami-0a65c0ba827ac8aa6"
		"sa-east-1" = "ami-0800122b87dbba24d"
		"ca-central-1" = "ami-085eba2a3f86faa3b"
		"ap-east-1" = "ami-07ab32ce60e799b6d"
		"ap-southeast-1" = "ami-070f8645a6a2aa277"
		"ap-southeast-2" = "ami-084cb7c0a1de2598a"
		"us-east-1" = "ami-05ac01c900473d20c"
		"us-east-2" = "ami-07c9acc155819afdf"
		"us-west-1" = "ami-021058d87f426c556"
		"us-west-2" = "ami-088dc580ee93a08fc"
  }
}

resource "aws_security_group" "ds_config_sg" {
  name        = "${var.deployment_name}-DataSunrise-Config-SG"
  description = "Enables DataSunrise nodes access to dictionary/audit RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.dictionary_db_port
    to_port         = var.dictionary_db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.deployment_name}-DataSunrise-Config-SG"
  }
  depends_on = [aws_security_group.ec2sg]
}

data "aws_subnet" "targetcidr" {
  id = var.ASGLB_subnets[0]
}

resource "aws_security_group" "ec2sg" {
  name        = "${var.deployment_name}-DataSunrise-EC2-SG"
  description = "Enables SSH and access to DataSunrise console (port 11000)"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = tolist([var.admin_location_CIDR])
  }

  ingress {
    from_port   = 11000
    to_port     = 11000
    protocol    = "tcp"
    cidr_blocks = tolist([var.admin_location_CIDR])
  }

  ingress {
    from_port   = var.ds_instance_port
    to_port     = var.ds_instance_port
    protocol    = "tcp"
    cidr_blocks = tolist([var.admin_location_CIDR])
  }

  ingress {
    from_port   = 11000
    to_port     = 11000
    protocol    = "tcp"
    cidr_blocks = [data.aws_subnet.targetcidr.cidr_block]
  }

  ingress {
    from_port = 11000
    to_port   = 11010
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.deployment_name}-DataSunrise-EC2-SG"
  }
}

resource "aws_db_subnet_group" "ds_db_subnet_group" {
  name        = "${var.deployment_name}-db-subnet-group"
  description = "RDS database subnet group for DataSunrise configuration storage"
  #ENTER-SUBNET-IDS-LIST HERE. YOU CAN SEE AN EXAMPLE HOW TO GET FIRST, SECOND ELEMENT FROM THE LIST DEFINED IN VARIAVLES.TF
  subnet_ids = tolist([var.db_subnet_ids[0], var.db_subnet_ids[1]])
}

resource "aws_db_instance" "dictionary_db" {
  identifier             = "${var.deployment_name}-dictionary"
  db_name                = var.dictionary_db_name
  engine                 = "Postgres"
  engine_version         = "15"
  instance_class         = var.dictionary_db_class
  port                   = var.dictionary_db_port
  username               = var.db_username
  password               = var.db_password
  multi_az               = var.multi_az_dictionary
  allocated_storage      = var.dictionary_db_storage_size
  vpc_security_group_ids = [aws_security_group.ds_config_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.ds_db_subnet_group.name
  storage_encrypted      = true
  storage_type           = "gp2"
  skip_final_snapshot    = true

  depends_on = [aws_db_subnet_group.ds_db_subnet_group, aws_security_group.ds_config_sg]
}

resource "aws_db_instance" "audit_db" {
  identifier             = "${var.deployment_name}-audit"
  db_name                = var.audit_db_name
  engine                 = "Postgres"
  engine_version         = "15"
  instance_class         = var.audit_db_class
  username               = var.db_username
  password               = var.db_password
  multi_az               = var.multi_az_dictionary
  allocated_storage      = var.audit_db_storage_size
  vpc_security_group_ids = [aws_security_group.ds_config_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.ds_db_subnet_group.name
  storage_encrypted      = true
  storage_type           = "gp2"
  skip_final_snapshot    = true

  depends_on = [aws_db_subnet_group.ds_db_subnet_group, aws_security_group.ds_config_sg]
}

data "cloudinit_config" "example" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<EOF
#cloud-config
write_files:
  - content: |
      ${base64encode(file("${path.module}/scripts/vm-creds.sh"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/vm-creds.sh
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/ds-manip.sh"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/ds-manip.sh
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/ds-setup.sh"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/ds-setup.sh
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/aws-ds-setup.sh"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/aws-ds-setup.sh
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/pre-setup.sh"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/pre-setup.sh
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/appfirewall-hb.reg"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/appfirewall-hb.reg
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/backup-prepare.sh"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/backup-prepare.sh
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/backup-upload.sh"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/backup-upload.sh
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/service-mon.sh"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/service-mon.sh
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/push-cwlogs-conf.sh"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/push-cwlogs-conf.sh
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/datasunrise.te"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/datasunrise.te
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/datasunrise.fc"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/datasunrise.fc
    permissions: '0750'
  - content: |
      ${base64encode(file("${path.module}/scripts/datasunrise.if"))}
    encoding: b64
    owner: root:root
    path: /opt/cooked/datasunrise.if
    permissions: '0750'
EOF
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/scripts/cf-params.sh", {
      DSDISTURL            = var.ds_dist_url
      STACKNAME            = "${var.deployment_name}-launch-configuration"
      DeploymentName       = var.deployment_name
      EC2REGION            = data.aws_region.current.name
      DSLICTYPE            = var.ds_license_type
      AWSCLIProxy          = var.aws_cli_proxy
      AlarmEmail           = ""
      AMinSize             = var.ec2_count
      ASG_NAME             = "${var.deployment_name}-auto-scaling-group"
      BackupS3BucketName   = var.s3_bucket_name
      DSSGroupId           = aws_security_group.ec2sg.id
      DNSName              = aws_lb.ds_ntwrk_load_balancer.dns_name
      AdminLocationCIDR    = var.admin_location_CIDR
      TRG_DBTYPE           = var.ds_instance_type
      TRG_DBHOST           = var.ds_instance_host
      TRG_DBPORT           = var.ds_instance_port
      TRG_DBNAME           = var.ds_instance_database_name
      TRG_DBUSER           = var.ds_instance_login
      HA_DBTYPE            = "postgresql"
      HA_DBHOST            = aws_db_instance.dictionary_db.address
      HA_DBPORT            = aws_db_instance.dictionary_db.port
      HA_DBNAME            = aws_db_instance.dictionary_db.db_name
      HA_DBUSER            = aws_db_instance.dictionary_db.username
      HA_AUTYPE            = "1"
      HA_AUHOST            = aws_db_instance.audit_db.address
      HA_AUPORT            = aws_db_instance.audit_db.port
      HA_AUNAME            = aws_db_instance.audit_db.db_name
      HA_AUUSER            = aws_db_instance.audit_db.username
      CWLOGUPLOAD_ENABLED  = var.cloudwatch_log_sync_enabled
      CWLOGUPLOAD_INTERVAL = var.cloudwatch_log_sync_interval
    })
  }

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/scripts/user-data.sh")
  }
}

resource "aws_launch_template" "ds_launch_template" {
  name_prefix            = "${var.deployment_name}-launch-template"
  image_id               = lookup(var.regions_amis, data.aws_region.current.name)
  instance_type          = var.ds_launch_template_instance_type
  vpc_security_group_ids = [aws_security_group.ec2sg.id]
  key_name               = var.ds_launch_temlate_ec2_keyname
  user_data              = data.cloudinit_config.example.rendered

  iam_instance_profile {
    name = aws_iam_instance_profile.ds_node_profile.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  depends_on = [aws_db_instance.dictionary_db, aws_db_instance.audit_db]
}

resource "aws_lb_target_group" "nlb_webui_tg" {
  name     = "${var.deployment_name}-dswebui-tg"
  port     = "11000"
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    interval            = var.ds_load_balancer_hc_interval
    port                = "11000"
    protocol            = "TCP"
    healthy_threshold   = var.ds_load_balancer_hc_healthy_threshold
    unhealthy_threshold = var.ds_load_balancer_hc_unhealthy_threshold
  }
}

resource "aws_lb_target_group" "nlb_proxy_tg" {
  name     = "${var.deployment_name}-dsproxy-tg"
  port     = var.ds_instance_port
  protocol = "TCP"
  vpc_id   = var.vpc_id

}

resource "aws_lb_listener" "nlb_webui_listener" {
  load_balancer_arn = aws_lb.ds_ntwrk_load_balancer.arn
  port              = "11000"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.nlb_webui_tg.arn
    type             = "forward"
  }

  depends_on = [aws_lb.ds_ntwrk_load_balancer, aws_lb_target_group.nlb_webui_tg]
}

resource "aws_lb_listener" "nlb_proxy_listener" {
  load_balancer_arn = aws_lb.ds_ntwrk_load_balancer.arn
  port              = var.ds_instance_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.nlb_proxy_tg.arn
    type             = "forward"
  }

  depends_on = [aws_lb.ds_ntwrk_load_balancer, aws_lb_target_group.nlb_proxy_tg]
}

resource "aws_lb" "ds_ntwrk_load_balancer" {
  internal = var.elb_scheme
  name     = "${var.deployment_name}-ntwrk-lb"
  #ENTER-SUBNET-IDS-LIST HERE. YOU CAN SEE AN EXAMPLE HOW TO GET FIRST, SECOND ELEMENT FROM THE LIST DEFINED IN VARIAVLES.TF
  subnets                          = tolist([var.ASGLB_subnets[0]])
  enable_cross_zone_load_balancing = "true"
  load_balancer_type               = "network"
}

resource "aws_autoscaling_attachment" "asg_attachment_webui_tg" {
  autoscaling_group_name = aws_autoscaling_group.ds_autoscaling_group.id
  lb_target_group_arn   = aws_lb_target_group.nlb_webui_tg.arn

  depends_on = [aws_lb_target_group.nlb_webui_tg]
}

resource "aws_autoscaling_attachment" "asg_attachment_proxy_tg" {
  autoscaling_group_name = aws_autoscaling_group.ds_autoscaling_group.id
  lb_target_group_arn   = aws_lb_target_group.nlb_proxy_tg.arn

  depends_on = [aws_lb_target_group.nlb_proxy_tg]
}


resource "aws_autoscaling_group" "ds_autoscaling_group" {
  name                 = "${var.deployment_name}-auto-scaling-group"

  launch_template {
    name    = aws_launch_template.ds_launch_template.name
    version = "$Latest"
  }

  max_size             = var.ec2_count
  min_size             = var.ec2_count
  #ENTER-SUBNET-IDS-LIST HERE. YOU CAN SEE AN EXAMPLE HOW TO GET FIRST, SECOND ELEMENT FROM THE LIST DEFINED IN VARIABLES.TF
  vpc_zone_identifier       = tolist([var.ASGLB_subnets[0]])
  health_check_type         = var.health_check_type
  health_check_grace_period = var.ds_autoscaling_group_hc_grace_period
  default_cooldown          = var.ds_autoscaling_group_cooldown
  target_group_arns         = [aws_lb_target_group.nlb_webui_tg.arn, aws_lb_target_group.nlb_proxy_tg.arn]

  lifecycle       { 
   create_before_destroy = true 
  }

  tag {
    key                 = "Name"
    value               = "${var.deployment_name}-virtual-machine"
    propagate_at_launch = true
  }

  depends_on = [aws_launch_template.ds_launch_template, aws_lb_target_group.nlb_webui_tg, aws_lb_target_group.nlb_proxy_tg]
}

resource "aws_autoscaling_policy" "ds_autoscaling_policy" {
  name                      = "${var.deployment_name}-auto-scaling-policy"
  autoscaling_group_name    = aws_autoscaling_group.ds_autoscaling_group.name
  estimated_instance_warmup = var.ds_autoscaling_group_estimated_instance_warmup
  policy_type               = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.ds_autoscaling_group_average_cpu_utilization
  }

}


resource "aws_secretsmanager_secret" "ds_secret_admin_password" {
  name                    = "${var.deployment_name}-secret-admin-password"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "ds_secret_admin_password" {
  secret_id     = aws_secretsmanager_secret.ds_secret_admin_password.id
  secret_string = var.ds_admin_password
}

resource "aws_secretsmanager_secret" "ds_secret_target_db_password" {
  name                    = "${var.deployment_name}-secret-tdb-password"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "ds_secret_target_db_password" {
  secret_id     = aws_secretsmanager_secret.ds_secret_target_db_password.id
  secret_string = var.ds_instance_password
}

resource "aws_secretsmanager_secret" "ds_secret_config_db_password" {
  name                    = "${var.deployment_name}-secret-config-password"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "ds_secret_config_db_password" {
  secret_id     = aws_secretsmanager_secret.ds_secret_config_db_password.id
  secret_string = var.db_password
}

resource "aws_secretsmanager_secret" "ds_secret_license_key" {
  name                    = "${var.deployment_name}-secret-license-key"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "ds_secret_license_key" {
  secret_id     = aws_secretsmanager_secret.ds_secret_license_key.id
  secret_string = var.ds_license_key
}

resource "aws_iam_instance_profile" "ds_node_profile" {
  name = "${var.deployment_name}-DataSunrise-VM-Profile"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "${var.deployment_name}-DataSunrise-EC2-Role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name = "${var.deployment_name}-DataSunrise-VM-Policy"
  path = "/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "secretsmanager:DescribeSecret", 
        "secretsmanager:GetSecretValue", 
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage" 
      ],
      "Effect": "Allow",
      "Resource": [
            "${aws_secretsmanager_secret.ds_secret_admin_password.id}", 
            "${aws_secretsmanager_secret.ds_secret_target_db_password.id}", 
            "${aws_secretsmanager_secret.ds_secret_config_db_password.id}",
            "${aws_secretsmanager_secret.ds_secret_license_key.id}"
        ]
    },  
    {
        "Effect" : "Allow",
        "Action" : [ 
            "secretsmanager:GetSecretValue"
        ],
        "Resource" : [ 
            "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:db-password-*" 
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "cloudwatch:PutMetric*",
            "events:PutEvents",
            "events:PutRule",
            "sts:DecodeAuthorizationMessage",
            "ec2:DescribeInstanceStatus",
            "ec2:DescribeInstances",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:Put*",
            "logs:DescribeLogStreams",
            "ssm:UpdateInstanceInformation",
            "cloudwatch:GetMetricStatistics"
        ],
        "Resource": [
            "*"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "ec2:*SecurityGroup*"
        ],
        "Resource": [ 
            "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-group/${aws_security_group.ec2sg.id}" 
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "autoscaling:SetDesiredCapacity",
            "autoscaling:UpdateAutoScalingGroup"
        ],
        "Resource": [ 
            "arn:aws:autoscaling:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.deployment_name}-auto-scaling-group"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "aws-marketplace:MeterUsage"
        ],
        "Resource": "*"
    }
    ]
}
EOF
}

resource "aws_iam_policy" "s3_access_policy" {
  name  = "${var.deployment_name}-S3AccessPolicy"
  path  = "/"
  count = var.s3_bucket_name != "" ? 1 : 0

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [ 
                "arn:aws:s3:::${var.s3_bucket_name}/*",
                "arn:aws:s3:::${var.s3_bucket_name}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "s3_get_distribution_policy" {
  name  = "${var.deployment_name}-S3GetDistributionPolicy"
  path  = "/"
  count = element(split("//", "${var.ds_dist_url}"), 0) == "s3:" ? 1 : 0

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject*"
            ],
            "Resource": [ 
                "arn:aws:s3:::${element(split("//", "${var.ds_dist_url}"), 1)}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "cw_access_policy" {
  name = "${var.deployment_name}-CWAccessPolicy"
  path = "/"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:DeleteAlarms"
            ],
            "Resource": [ 
                "*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "kms_access_policy" {
  name  = "${var.deployment_name}-KMSAccessPolicy"
  path  = "/"
  count = var.bucket_key_arn != "" ? 1 : 0

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt",
                "kms:Encrypt",
                "kms:DescribeKey"
            ],
            "Resource": [ 
                "${var.bucket_key_arn}" 
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "rds_describe_instances_policy" {
  name = "${var.deployment_name}-RDSDescribeInstancesPolicy"
  path = "/"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:DescribeDBInstances"
            ],
            "Resource": [ 
                "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:${aws_db_instance.audit_db.identifier}" 
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "dsvm-role-attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_role_policy_attachment" "s3-role-attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.s3_access_policy[count.index].arn
  count      = var.s3_bucket_name != "" ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "s3-get-distribution-role-attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.s3_get_distribution_policy[count.index].arn
  count      = element(split("//", "${var.ds_dist_url}"), 0) == "s3:" ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "cw-role-attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.cw_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "kms-role-attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.kms_access_policy[count.index].arn
  count      = var.bucket_key_arn != "" ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "rds-describe-role-attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.rds_describe_instances_policy.arn
}