#
# IAM Resources
#
data "aws_iam_policy_document" "container_instance_ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "container_instance_ecs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "ses_send_email" {
  statement {
    effect = "Allow"

    resources = ["*"]

    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
  }
}

data "aws_iam_policy_document" "batch_manage_jobs" {
  statement {
    effect = "Allow"

    resources = ["*"]

    actions = [
      "batch:CancelJob",
      "batch:DescribeJobDefinitions",
      "batch:DescribeJobQueues",
      "batch:DescribeJobs",
      "batch:ListJobs",
      "batch:SubmitJob",
      "batch:TerminateJob",
    ]
  }
}

data "aws_iam_policy_document" "anonymous_read_storage_bucket_policy" {
  policy_id = "S3StorageAnonymousReadPolicy"

  statement {
    sid = "S3ReadOnly"

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:GetObject"]

    resources = [
      "arn:aws:s3:::${lower("${var.environment}")}-pfb-storage-${var.aws_region}/*",
    ]
  }
}

data "aws_iam_policy_document" "anonymous_read_tile_cache_bucket_policy" {
  policy_id = "S3TileCacheAnonymousReadPolicy"

  statement {
    sid = "S3ReadOnly"

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:GetObject"]

    resources = [
      "arn:aws:s3:::${lower(var.environment)}-pfb-tile-cache-${var.aws_region}/*",
    ]
  }
}

#
# Custom policies
#
resource "aws_iam_policy" "batch_manage_jobs" {
  name   = "${var.environment}BatchManageJobs"
  policy = "${data.aws_iam_policy_document.batch_manage_jobs.json}"
}

#
# ECS roles
#
resource "aws_iam_role" "app_container_instance_ecs" {
  name               = "ecs${var.environment}AppInstanceRole"
  assume_role_policy = "${data.aws_iam_policy_document.container_instance_ecs_assume_role.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_for_ec2_policy_pfb_app_ecs_role" {
  role       = "${aws_iam_role.app_container_instance_ecs.name}"
  policy_arn = "${var.aws_ecs_for_ec2_service_role_policy_arn}"
}

resource "aws_iam_role_policy_attachment" "ecs_policy" {
  role       = "${aws_iam_role.app_container_instance_ecs.name}"
  policy_arn = "${var.aws_ecs_service_role_policy_arn}"
}

resource "aws_iam_role_policy_attachment" "sqs_read_write" {
  role       = "${aws_iam_role.app_container_instance_ecs.name}"
  policy_arn = "${var.aws_sqs_read_write_policy_arn}"
}

#
# App EC2 roles
#
resource "aws_iam_role" "app_container_instance_ec2" {
  name               = "${var.environment}AppContainerInstanceProfile"
  assume_role_policy = "${data.aws_iam_policy_document.container_instance_ec2_assume_role.json}"
}

resource "aws_iam_role_policy" "ec2_ses_send_email" {
  name   = "${var.environment}EC2SESSendEmail"
  role   = "${aws_iam_role.app_container_instance_ec2.id}"
  policy = "${data.aws_iam_policy_document.ses_send_email.json}"
}

resource "aws_iam_role_policy_attachment" "batch_manage_jobs_policy_container_instance_role" {
  role       = "${aws_iam_role.app_container_instance_ec2.name}"
  policy_arn = "${aws_iam_policy.batch_manage_jobs.arn}"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy_container_instance_role" {
  role       = "${aws_iam_role.app_container_instance_ec2.name}"
  policy_arn = "${var.aws_cloudwatch_logs_policy_arn}"
}

resource "aws_iam_role_policy_attachment" "app_ec2_s3_policy" {
  role       = "${aws_iam_role.app_container_instance_ec2.name}"
  policy_arn = "${var.aws_s3_policy_arn}"
}

resource "aws_iam_role_policy_attachment" "ecs_for_ec2_policy_container_instance_role" {
  role       = "${aws_iam_role.app_container_instance_ec2.name}"
  policy_arn = "${var.aws_ecs_for_ec2_service_role_policy_arn}"
}

resource "aws_iam_instance_profile" "app_container_instance" {
  name = "${aws_iam_role.app_container_instance_ec2.name}"
  role = "${aws_iam_role.app_container_instance_ec2.name}"
}

#
# Batch EC2 roles
#
resource "aws_iam_role" "batch_container_instance_ec2" {
  name               = "${var.environment}BatchInstanceProfile"
  assume_role_policy = "${data.aws_iam_policy_document.container_instance_ec2_assume_role.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_for_ec2_policy_batch_container_instance_role" {
  role       = "${aws_iam_role.batch_container_instance_ec2.name}"
  policy_arn = "${var.aws_ecs_for_ec2_service_role_policy_arn}"
}

resource "aws_iam_role_policy_attachment" "batch_ec2_s3_policy" {
  role       = "${aws_iam_role.batch_container_instance_ec2.name}"
  policy_arn = "${var.aws_s3_policy_arn}"
}

resource "aws_iam_instance_profile" "batch_container_instance" {
  name = "${aws_iam_role.batch_container_instance_ec2.name}"
  role = "${aws_iam_role.batch_container_instance_ec2.name}"
}

#
# Tilegarden executor
#
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_invoke" {
  statement {
    effect = "Allow"
    resources = ["arn:aws:lambda:*:*:function:${var.tilegarden_function_name}"]
    actions = [
      "lambda:InvokeFunction",
    ]
  }
}

data "aws_iam_policy_document" "logs_create_and_write" {
  statement {
    effect = "Allow"
    resources = ["arn:aws:logs:*:*:*"],
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

data "aws_iam_policy_document" "vpc_access" {
  statement {
    effect = "Allow"
    resources = ["*"],
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
    ]
  }
}

data "aws_iam_policy_document" "s3_write_tile_cache" {
  statement {
    effect = "Allow"
    resources = [
      "arn:aws:s3:::${lower(var.environment)}-pfb-tile-cache-${var.aws_region}",
      "arn:aws:s3:::${lower(var.environment)}-pfb-tile-cache-${var.aws_region}/*",
    ]
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:GetBucketWebsite",
    ]
  }
}

resource "aws_iam_role" "tilegarden_executor" {
  name               = "${var.tilegarden_function_name}Executor"
  assume_role_policy = "${data.aws_iam_policy_document.lambda_assume_role.json}"
}

resource "aws_iam_role_policy" "executor_role_lambda_invoke_policy" {
  name   = "${var.environment}InvokeLambda"
  role   = "${aws_iam_role.tilegarden_executor.id}"
  policy = "${data.aws_iam_policy_document.lambda_invoke.json}"
}

resource "aws_iam_role_policy" "executor_role_logs_create_and_write_policy" {
  name   = "${var.environment}WriteLogs"
  role   = "${aws_iam_role.tilegarden_executor.id}"
  policy = "${data.aws_iam_policy_document.logs_create_and_write.json}"
}

resource "aws_iam_role_policy" "executor_role_vpc_access_policy" {
  name   = "${var.environment}AccessVPC"
  role   = "${aws_iam_role.tilegarden_executor.id}"
  policy = "${data.aws_iam_policy_document.vpc_access.json}"
}

resource "aws_iam_role_policy" "executor_role_s3_write_tile_cache_policy" {
  name   = "${var.environment}WriteTileCache"
  role   = "${aws_iam_role.tilegarden_executor.id}"
  policy = "${data.aws_iam_policy_document.s3_write_tile_cache.json}"
}
