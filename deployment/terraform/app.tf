#
# Security group resources
#
resource "aws_security_group" "pfb_app_alb" {
  vpc_id = "${module.vpc.id}"

  tags {
    Name        = "sgAppServerLoadBalancer"
    Project     = "${var.project}"
    Environment = "${var.environment}"
  }
}

#
# ALB resources
#
resource "aws_alb" "pfb_app" {
  security_groups = ["${aws_security_group.pfb_app_alb.id}"]
  subnets         = ["${module.vpc.public_subnet_ids}"]
  name            = "alb${var.environment}AppServer"

  tags {
    Name        = "albAppServer"
    Project     = "${var.project}"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_target_group" "pfb_app_http" {
  # Name can only be 32 characters long, so we MD5 hash the name and
  # truncate it to fit.
  name = "tf-tg-${replace("${md5("${var.environment}HTTPAppServer")}", "/(.{0,26})(.*)/", "$1")}"

  health_check {
    healthy_threshold   = "3"
    interval            = "60"
    matcher             = "301"
    protocol            = "HTTP"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }

  port     = "80"
  protocol = "HTTP"
  vpc_id   = "${module.vpc.id}"

  tags {
    Name        = "tg${var.environment}HTTPAppServer"
    Project     = "${var.project}"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_target_group" "pfb_app_https" {
  # Name can only be 32 characters long, so we MD5 hash the name and
  # truncate it to fit.
  name = "tf-tg-${replace("${md5("${var.environment}HTTPSAppServer")}", "/(.{0,26})(.*)/", "$1")}"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    timeout             = "3"
    path                = "/healthcheck/"
    unhealthy_threshold = "2"
  }

  port     = "443"
  protocol = "HTTP"
  vpc_id   = "${module.vpc.id}"

  tags {
    Name        = "tg${var.environment}HTTPSAppServer"
    Project     = "${var.project}"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_listener" "pfb_app_http" {
  load_balancer_arn = "${aws_alb.pfb_app.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.pfb_app_http.id}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "pfb_app_https" {
  load_balancer_arn = "${aws_alb.pfb_app.id}"
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = "${var.ssl_certificate_arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.pfb_app_https.id}"
    type             = "forward"
  }
}

data "template_file" "pfb_app_http_ecs_task" {
  template = "${file("task-definitions/nginx.json")}"

  vars = {
    app_server_nginx_url        = "${var.aws_account_id}.dkr.ecr.us-east-1.amazonaws.com/pfb-nginx:${var.git_commit}"
    pfb_app_papertrail_endpoint = "${var.papertrail_host}:${var.papertrail_port}"
  }
}

resource "aws_ecs_task_definition" "pfb_app_http" {
  family                = "${var.environment}HTTPAppServer"
  container_definitions = "${data.template_file.pfb_app_http_ecs_task.rendered}"
}

resource "aws_ecs_service" "pfb_app_http" {
  name                               = "${var.environment}HTTPAppServer"
  task_definition                    = "${aws_ecs_task_definition.pfb_app_http.arn}"
  cluster                            = "${aws_ecs_cluster.app_container_instance.id}"
  desired_count                      = "${var.pfb_app_http_ecs_desired_count}"
  deployment_minimum_healthy_percent = "${var.pfb_app_http_ecs_deployment_min_percent}"
  deployment_maximum_percent         = "${var.pfb_app_http_ecs_deployment_max_percent}"
  iam_role                           = "${aws_iam_role.app_container_instance_ecs.name}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.pfb_app_http.id}"
    container_name   = "nginx"
    container_port   = "80"
  }
}

data "template_file" "pfb_app_https_ecs_task" {
  template = "${file("task-definitions/app.json")}"

  vars = {
    app_server_nginx_url                         = "${var.aws_account_id}.dkr.ecr.us-east-1.amazonaws.com/pfb-nginx:${var.git_commit}"
    app_server_django_url                        = "${var.aws_account_id}.dkr.ecr.us-east-1.amazonaws.com/pfb-app:${var.git_commit}"
    django_env                                   = "${var.django_env}"
    django_secret_key                            = "${var.django_secret_key}"
    rds_host                                     = "${module.database.hostname}"
    rds_password                                 = "${var.rds_password}"
    rds_username                                 = "${var.rds_username}"
    rds_database_name                            = "${var.rds_database_name}"
    s3_static_bucket                             = "${aws_s3_bucket.static.id}"
    s3_storage_bucket                            = "${aws_s3_bucket.storage.id}"
    django_allowed_hosts                         = "${var.django_allowed_hosts}"
    git_commit                                   = "${var.git_commit}"
    pfb_app_papertrail_endpoint                  = "${var.papertrail_host}:${var.papertrail_port}"
    aws_region                                   = "${var.aws_region}"
    batch_analysis_job_queue_name                = "${var.batch_analysis_job_queue_name}"
    batch_analysis_job_definition_name_revision  = "${var.batch_analysis_job_definition_name_revision}"
    tilegarden_root                              = "https://${aws_route53_record.tilegarden.fqdn}"
    tilegarden_cache_bucket                      = "${lower(var.environment)}-pfb-tile-cache-${var.aws_region}}"
  }
}

resource "aws_ecs_task_definition" "pfb_app_https" {
  family                = "${var.environment}HTTPSAppServer"
  container_definitions = "${data.template_file.pfb_app_https_ecs_task.rendered}"
}

resource "aws_ecs_service" "pfb_app_https" {
  name                               = "${var.environment}HTTPSAppServer"
  task_definition                    = "${aws_ecs_task_definition.pfb_app_https.arn}"
  cluster                            = "${aws_ecs_cluster.app_container_instance.id}"
  desired_count                      = "${var.pfb_app_https_ecs_desired_count}"
  deployment_minimum_healthy_percent = "${var.pfb_app_https_ecs_deployment_min_percent}"
  deployment_maximum_percent         = "${var.pfb_app_https_ecs_deployment_max_percent}"
  iam_role                           = "${aws_iam_role.app_container_instance_ecs.name}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.pfb_app_https.id}"
    container_name   = "nginx"
    container_port   = "443"
  }
}

data "template_file" "pfb_app_async_queue_ecs_task" {
  template = "${file("task-definitions/django-q.json")}"

  vars = {
    djangoq_url                                  = "${var.aws_account_id}.dkr.ecr.us-east-1.amazonaws.com/pfb-app:${var.git_commit}"
    django_env                                   = "${var.django_env}"
    django_secret_key                            = "${var.django_secret_key}"
    rds_host                                     = "${module.database.hostname}"
    rds_password                                 = "${var.rds_password}"
    rds_username                                 = "${var.rds_username}"
    rds_database_name                            = "${var.rds_database_name}"
    s3_static_bucket                             = "${aws_s3_bucket.static.id}"
    s3_storage_bucket                            = "${aws_s3_bucket.storage.id}"
    django_allowed_hosts                         = "${var.django_allowed_hosts}"
    git_commit                                   = "${var.git_commit}"
    pfb_app_papertrail_endpoint                  = "${var.papertrail_host}:${var.papertrail_port}"
    aws_region                                   = "${var.aws_region}"
    batch_analysis_job_queue_name                = "${var.batch_analysis_job_queue_name}"
    batch_analysis_job_definition_name_revision  = "${var.batch_analysis_job_definition_name_revision}"
    tilegarden_root                              = "https://${aws_route53_record.tilegarden.fqdn}"
    tilegarden_cache_bucket                      = "${lower(var.environment)}-pfb-tile-cache-${var.aws_region}}"
  }
}

resource "aws_ecs_task_definition" "pfb_app_async_queue" {
  family                = "${var.environment}AsyncQueue"
  container_definitions = "${data.template_file.pfb_app_async_queue_ecs_task.rendered}"
}

resource "aws_ecs_service" "pfb_app_async_queue" {
  name                               = "${var.environment}AsyncQueue"
  task_definition                    = "${aws_ecs_task_definition.pfb_app_async_queue.arn}"
  cluster                            = "${aws_ecs_cluster.app_container_instance.id}"
  desired_count                      = "${var.pfb_app_async_queue_ecs_desired_count}"
  deployment_minimum_healthy_percent = "${var.pfb_app_async_queue_ecs_deployment_min_percent}"
  deployment_maximum_percent         = "${var.pfb_app_async_queue_ecs_deployment_max_percent}"
}

data "template_file" "pfb_app_management_ecs_task" {
  template = "${file("task-definitions/management.json")}"

  vars {
    management_url                               = "${var.aws_account_id}.dkr.ecr.us-east-1.amazonaws.com/pfb-app:${var.git_commit}"
    django_env                                   = "${var.django_env}"
    django_secret_key                            = "${var.django_secret_key}"
    rds_host                                     = "${module.database.hostname}"
    rds_password                                 = "${var.rds_password}"
    rds_username                                 = "${var.rds_username}"
    rds_database_name                            = "${var.rds_database_name}"
    s3_static_bucket                             = "${aws_s3_bucket.static.id}"
    s3_storage_bucket                            = "${aws_s3_bucket.storage.id}"
    django_allowed_hosts                         = "${var.django_allowed_hosts}"
    git_commit                                   = "${var.git_commit}"
    pfb_app_papertrail_endpoint                  = "${var.papertrail_host}:${var.papertrail_port}"
    aws_region                                   = "${var.aws_region}"
    batch_analysis_job_queue_name                = "${var.batch_analysis_job_queue_name}"
    batch_analysis_job_definition_name_revision  = "${var.batch_analysis_job_definition_name_revision}"
    tilegarden_root                              = "https://${aws_route53_record.tilegarden.fqdn}"
    tilegarden_cache_bucket                      = "${lower(var.environment)}-pfb-tile-cache-${var.aws_region}}"
  }
}

resource "aws_ecs_task_definition" "pfb_app_management" {
  family                = "${var.environment}Management"
  container_definitions = "${data.template_file.pfb_app_management_ecs_task.rendered}"
}
