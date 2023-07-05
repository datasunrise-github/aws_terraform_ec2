# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# DataSunrise Cluster for Amazon Web Services
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Please replace xxxxxxxxx with values that correspond to your environment
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

variable "deployment_name" {
  description = "Name that will be used as the prefix to the resources' names that will be created by the Terraform script (only in lower case, not more than 15 symbols and not less than 5 symbols)"
  default     = "xxxxxxxxx"
}

# ------------------------------------------------------------------------------
# Virtual Machine Configuration
# ------------------------------------------------------------------------------

variable "ds_launch_configuration_ec2_keyname" {
  description = "Key pair to attach to every EC2 instance created"
  default     = "xxxxxxxxx"
}

variable "ds_launch_configuration_instance_type" {
  description = "Instance type for DataSunrise instance"
  default     = "t3.medium"
}

# ------------------------------------------------------------------------------
# Network Configuration
# ------------------------------------------------------------------------------

variable "vpc_id" {
  description = "Prefered VPC Id"
  #Must be the VPC Id of an existing Virtual Private Cloud.
  default = "xxxxxxxxx"
}

variable "admin_location_CIDR" {
  description = "IP address range that can be used access port 22, for appliance configuration access to the EC2 instances."
  #Must be a valid IP CIDR range of the form x.x.x.x/x.
  default = "0.0.0.0/0"
}

variable "user_location_CIDR" {
  description = "IP address range that can be used access port 11000, for appliance configuration access to the DataSunrise console and database proxy."
  #Must be a valid IP CIDR range of the form x.x.x.x/x.
  default = "0.0.0.0/0"
}

# ------------------------------------------------------------------------------
# DataSunrise Configuration
# ------------------------------------------------------------------------------

variable "ds_admin_password" {
  description = "DataSunrise admin's password"
  default     = "xxxxxxxxx"
}

variable "ds_dist_url" {
  description = "(Optional) Url of the DataSunrise distribution package."
  #Make sure that this URL will be accessible from your VPC. You may also use the path to the DataSunrise build placed in your S3 bucket, however, make sure to modify the "S3AccessPolicy" section of this template.
  default = ""
}

variable "bucket_key_arn" {
  description = "(Optional) KMS Key ARN that was used for S3 bucket encryption. The key is needed for DSDistribution download possibility. In case the bucket is not encrypted, leave this field empty."
  default     = ""
}

variable "ds_license_type" {
  description = "Preferred licensing type. If you select BYOL licensing, you must enter a valid license key into DSLicenseKey field."
  # AllowedValues : "HourlyBilling", "BYOL"
  default = "HourlyBilling"
}

variable "ds_license_key" {
  description = "The DataSunrise license key."
  default     = "Do not change this field if you are using hourly billing"
}

variable "s3_bucket_name" {
  description = "(Optional) Name of the S3 bucket for DataSunrise backups & logs. If empty, the backup uploading will not be configured."
  default     = ""
}

# ------------------------------------------------------------------------------
# Dictionary & Audit Database Configuration
# ------------------------------------------------------------------------------

variable "dictionary_db_class" {
  description = "Instance class for dictionary database"
  default     = "db.t3.medium"
}

variable "dictionary_db_name" {
  description = "Dictionary DB name"
  default     = "dsdict"
}

variable "dictionary_db_port" {
  description = "Dictionary DB port"
  default     = 5432
}

variable "multi_az_dictionary" {
  description = "Dictionary RDS Multi-AZ"
  # AllowedValues : "true", "false"
  default = "true"
}

variable "dictionary_db_storage_size" {
  description = "The size of the database (Gb), minimum restriction by AWS is 20GB"
  default     = 20
}

variable "audit_db_class" {
  description = "Instance class for dictionary database"
  default     = "db.t3.medium"
}

variable "audit_db_name" {
  description = "Audit DB name"
  default     = "dsaudit"
}

variable "multi_az_audit" {
  description = "Dictionary RDS Multi-AZ"
  # AllowedValues : "true", "false"
  default = "true"
}

variable "audit_db_storage_size" {
  description = "The size of the database (Gb), minimum restriction by AWS is 20GB"
  default     = 20
}

variable "db_username" {
  description = "The database administrator account username. Must begin with a letter and contain only alphanumeric characters."
  default     = "dsuser"
}

variable "db_password" {
  description = "The database administrator account password."
  #The password must contain at least 8 characters, lower and upper case, numbers and special characters.
  default = "xxxxxxxxx"
}

variable "db_subnet_ids" {
  type        = list(string)
  description = "Dictionary and Audit subnets. Must be a part of mentioned VPC. Please be sure that you select at least two subnets."
  #IN CASE YOU NEED TO ADD MORE SUBNET IDS, JUST ADD IT AS NEW ELEMENT OF THE LIST BELOW USING COMMA TO SEPARATE THEM
  #IF NUMBER OF SUBNETS IS MORE THEN DEFAULT YOU HAVE TO ADD THE CORRESPONDING AMOUNT OF VARIABLES IN MAIN.TF
  default = ["xxxxxxxxx", "xxxxxxxxx"]
}

# ------------------------------------------------------------------------------
# Target Database Configuration
# ------------------------------------------------------------------------------

variable "ds_instance_port" {
  description = "Target Database Instance Port"
  default     = "xxxxxxxxx"
}

variable "ds_instance_host" {
  description = "Target Database Instance Host"
  default     = "xxxxxxxxx"
}

variable "ds_instance_type" {
  description = "Target Database Instance Type"
  # Allowed values: "aurora mysql", "aurora postgresql", "db2", "greenplum", "hive", "mariadb", "mysql", "mssql", "netezza", "oracle", "postgresql", "redshift",
  # "teradata", "sap hana", "vertica", "mongo", "dynamo", "impala", "cassandra"
  default = "postgresql"
}

variable "ds_instance_database_name" {
  description = "Target Database internal database name e.g. master for MSSQL or postgres for PostgreSQL"
  default     = "xxxxxxxxx"
}

variable "ds_instance_login" {
  description = "Target Database Login"
  default     = "xxxxxxxxx"
}

variable "ds_instance_password" {
  description = "Target Database Password"
  default     = "xxxxxxxxx"
}

# ------------------------------------------------------------------------------
# Auto Scaling Group Configuration
# ------------------------------------------------------------------------------

variable "ec2_count" {
  description = "Count of EC2 DataSunrise Server to be launched."
  default     = 1
}

variable "health_check_type" {
  description = "The service you want the health status from, Amazon EC2 or Elastic Load Balancer."
  #Allowed values: "EC2", "ELB"
  default = "EC2"
}

variable "ASGLB_subnets" {
  type        = list(string)
  description = "Load Balancer and EC2 instances subnets. Must be a part of mentioned VPC."
  #IN CASE YOU NEED TO ADD MORE SUBNET IDS, JUST ADD IT AS NEW ELEMENT OF THE LIST BELOW USING COMMA TO SEPARATE THEM.
  #IF NUMBER OF SUBNETS IS MORE THEN DEFAULT YOU HAVE TO ADD THE CORRESPONDING AMOUNT OF VARIABLES IN MAIN.TF
  default = ["xxxxxxxxx"]
}

variable "ds_autoscaling_group_hc_grace_period" {
  description = "Time grace period for a new EC2 instance before start checking its health status"
  default     = 600
}

variable "ds_autoscaling_group_cooldown" {
  description = "Seconds to wait, after a scaling activity, to do any further action"
  default     = 300
}

variable "ds_autoscaling_group_estimated_instance_warmup" {
  description = "Seconds to wait for a newly launched instance can start sending metrics to CloudWatch"
  default     = 90
}

variable "ds_autoscaling_group_average_cpu_utilization" {
  description = "Maximum CPU utilization before triggering an autoscaling action"
  default     = 50
}

# ------------------------------------------------------------------------------
# LoadBalancer Configuration
# ------------------------------------------------------------------------------

variable "elb_scheme" {
  description = "For load balancers attached to an Amazon VPC, this parameter can be used to specify the type of load balancer to use. Specify 'true' to create an internal load balancer with a DNS name that resolves to private IP addresses or 'false' to create an internet-facing load balancer with a publicly resolvable DNS name, which resolves to public IP addresses."
  #Allowed values: "true", "false"
  default = "false"
}

variable "ds_load_balancer_idle_timeout" {
  description = "Connection idle timeout"
  default     = 60
}

variable "ds_load_balancer_hc_healthy_threshold" {
  description = "Number of consecutive health probe failure required before flagging the instance as healthy"
  default     = 3
}

variable "ds_load_balancer_hc_unhealthy_threshold" {
  description = "Number of consecutive health probe failure required before flagging the instance as unhealthy"
  default     = 3
}

variable "ds_load_balancer_hc_interval" {
  description = "Health check interval"
  default     = 10
}

variable "ds_load_balancer_hc_timeout" {
  description = "Health check timeout"
  default     = 5
}

variable "ds_load_balancer_hc_target" {
  description = "Instance's protocol and port to check"
  default     = "TCP:11000"
}

# ------------------------------------------------------------------------------
# DataSunrise & CloudWatch Integration
# ------------------------------------------------------------------------------

variable "cloudwatch_log_initial_position" {
  description = "CloudWatch log initial position"
  # AllowedValues : "end_of_file", "start_of_file"
  default = "end_of_file"
}

variable "cloudwatch_log_sync_enabled" {
  description = "Enabling DataSunrise logs integration into CloudWatch"
  # AllowedValues : "OFF", "ON"
  default = "ON"
}

variable "cloudwatch_log_sync_interval" {
  description = "DataSunrise & CloudWatch logs synchronization interval (minutes)"
  default     = 5
}

# ------------------------------------------------------------------------------
# Proxy Options
# ------------------------------------------------------------------------------

variable "aws_cli_proxy" {
  description = "(Optional) In some cases of using private networks it is necessary to set up proxy for AWS CLI (PutMetrics/S3). For example http://[username[:password]@]<proxy host>:<proxy port>"
  default     = ""
}