# Variables stored in S3 for each environment
# This file defines which variables must be
# defined in order to run terraform

variable "project" {
  default = "PFB Network Connectivity"
}

variable "aws_account_id" {
  default = "950872791630"
}

variable "aws_region" {}

# Must be one of release, staging, production
variable "environment" {}

variable "bastion_ami" {
  default = "ami-f5f41398"
}

variable "r53_private_hosted_zone" {}
variable "r53_public_hosted_zone" {}

# Scaling
variable "app_container_instance_asg_desired_capacity" {}

variable "app_container_instance_asg_min_size" {}
variable "app_container_instance_asg_max_size" {}
variable "app_container_instance_type" {}
variable "aws_key_name" {}
variable "ecs_instance_ami_id" {}

# ECS
## HTTP API server
variable "pfb_app_http_ecs_desired_count" {}

variable "pfb_app_http_ecs_deployment_min_percent" {}
variable "pfb_app_http_ecs_deployment_max_percent" {}

## HTTPS API server
variable "pfb_app_https_ecs_deployment_max_percent" {}

variable "pfb_app_https_ecs_desired_count" {}
variable "pfb_app_https_ecs_deployment_min_percent" {}

## Async Queue
variable "pfb_app_async_queue_ecs_desired_count" {}

variable "pfb_app_async_queue_ecs_deployment_min_percent" {}
variable "pfb_app_async_queue_ecs_deployment_max_percent" {}

# IAM
variable "aws_ecs_for_ec2_service_role_policy_arn" {
  default = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

variable "aws_ecs_service_role_policy_arn" {
  default = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

variable "aws_s3_policy_arn" {
  default = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

variable "aws_sqs_read_write_policy_arn" {
  default = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

# Variables that must be defined for VPC
variable "vpc_cidr_block" {}

variable "vpc_private_subnet_cidr_blocks" {
  type = "list"
}

variable "vpc_public_subnet_cidr_blocks" {
  type = "list"
}

variable "vpc_external_access_cidr_block" {}
variable "vpc_bastion_instance_type" {}

variable "vpc_availibility_zones" {
  type = "list"
}

#variable "ecs_iam_role" {}
#variable "ecs_iam_profile" {}
variable "git_commit" {}

# RDS
variable "rds_storage_size_gb" {}

variable "rds_engine_version" {}
variable "rds_instance_type" {}
variable "rds_storage_type" {}
variable "rds_database_identifier" {}
variable "rds_database_name" {}
variable "rds_username" {}
variable "rds_password" {}
variable "rds_database_port" {}
variable "rds_backup_retention_period" {}
variable "rds_parameter_group_family" {}
variable "rds_backup_window" {}
variable "rds_maintenance_window" {}
variable "rds_multi_availability_zone" {}
variable "rds_sorage_encrypted" {}
variable "rds_auto_minor_version_upgrade" {}
variable "rds_alarm_cpu_threshold" {}
variable "rds_alarm_disk_queue_threshold" {}
variable "rds_alarm_free_disk_threshold" {}
variable "rds_alarm_free_memory_threshold" {}

# Batch ECS Cluster
variable "batch_ecs_cluster_name" {}

variable "batch_container_instance_type" {
  description = "Must be one of the instance types in the AWS EC2 'i3' family"
}

variable "batch_container_instance_asg_desired_capacity" {}
variable "batch_container_instance_asg_min_size" {}
variable "batch_container_instance_asg_max_size" {}

variable "batch_ecs_engine_task_cleanup_wait_duration" {
  default = "5m"
}

variable "batch_ecs_image_cleanup_interval" {
  default = "10m"
}

variable "batch_ecs_image_minimum_cleanup_age" {
  default = "30m"
}

# Django
variable "django_env" {}

variable "django_secret_key" {}
variable "django_allowed_hosts" {}
variable "batch_analysis_job_queue_name" {}
variable "batch_analysis_job_definition_name_revision" {} # format: 'name:revision'

variable "papertrail_host" {}
variable "papertrail_port" {}

variable "ssl_certificate_arn" {}

variable "aws_cloudwatch_logs_policy_arn" {
  default = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

variable "pfb_app_alb_ingress_cidr_block" {
  type = "list"
}

# Tilegarden tiler
variable "tilegarden_api_gateway_domain_name" {}

variable "cloudfront_price_class" {
  default = "PriceClass_100"
}

# Should be environment-specific and match the value in the Tilegarden .env file
variable "tilegarden_function_name" {}
