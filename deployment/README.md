# Amazon Web Services Deployment

Amazon Web Services deployment is driven by [Terraform](https://terraform.io/) and the [AWS Command Line Interface (CLI)](http://aws.amazon.com/cli/).

**NOTE**: Before deploying an AWS stack for the first time, ensure you've created the necessary resources detailed in the [AWS Batch](#aws-batch) section of this README.

## Table of Contents

* [AWS Credentials](#aws-credentials)
* [Terraform](#terraform)
* [AWS Batch](#aws-batch)
* [Tilegarden](#tilegarden)

## AWS Credentials

Using the AWS CLI, create an AWS profile named `pfb`:

```bash
$ vagrant ssh
vagrant@vagrant-ubuntu-trusty-64:~$ aws --profile pfb configure
AWS Access Key ID [****************F2DQ]:
AWS Secret Access Key [****************TLJ/]:
Default region name [us-east-1]: us-east-1
Default output format [None]:
```

You will be prompted to enter your AWS credentials, along with a default region. These credentials will be used to authenticate calls to the AWS API when using Terraform and the AWS CLI.

## Terraform

### Setup

Make sure there is a `terraform/terraform.tfvars` file in the project config bucket on S3 for the
environment you're deploying (i.e. `s3://{environment}-pfb-config-us-east-1/terraform/terraform.tfvars`).
If you're creating a new environment, make a new file via copy/paste/modify or by defining all the
variables specified in [terraform/variables.tf](terraform/variables.tf).  If you're updating an environment and need to
add or change variables, download the file:
```
export ENVIRONMENT="staging|production"
aws s3 cp "s3://${ENVIRONMENT}-pfb-config-us-east-1/terraform/terraform.tfvars" "${ENVIRONMENT}.tfvars"
```
Then edit the file and upload the modified copy, using default server-side encryption:
```
aws s3 cp "${ENVIRONMENT}.tfvars" "s3://${ENVIRONMENT}-pfb-config-us-east-1/terraform/terraform.tfvars" --sse
```

### Deploying
If you're deploying new application code, first set the commit to deploy, then build and push containers:
```bash
vagrant@vagrant-ubuntu-trusty-64:~$ export GIT_COMMIT="<short-commit-to-deploy>"
vagrant@vagrant-ubuntu-trusty-64:~$ export ENVIRONMENT="staging|production"
vagrant@vagrant-ubuntu-trusty-64:~$ export PFB_AWS_ECR_ENDPOINT="<aws-account-id>.dkr.ecr.us-east-1.amazonaws.com"
vagrant@vagrant-ubuntu-trusty-64:~$ ./scripts/cibuild && ./scripts/cipublish
```

Next, use the `infra` wrapper script to lookup the remote state of the infrastructure and assemble a plan for work to be done:

```bash
vagrant@vagrant-ubuntu-trusty-64:~$ export PFB_SETTINGS_BUCKET="${ENVIRONMENT}-pfb-config-us-east-1"
vagrant@vagrant-ubuntu-trusty-64:~$ ./scripts/infra plan
```

Once the plan has been assembled, and you agree with the changes, apply it:

```bash
vagrant@vagrant-ubuntu-trusty-64:~$ ./scripts/infra apply
```
This will attempt to apply the plan assembled in the previous step using Amazon's APIs. In order to change specific attributes of the infrastructure, inspect the contents of the environment's configuration file in Amazon S3.

## AWS Batch

Parts of the AWS Batch stack must be created manually. This includes:
- The Managed Compute Environment
- The appropriate Job Queues for each Compute Environment

Once these are created, the automated deployment handles creation of the latest revision of the appropriate Job Definitions via `./scripts/infra`

### Creating a Batch Compute Environment

Login to the AWS Console and navigate to [AWS Batch: Compute Environments](https://console.aws.amazon.com/batch/home?region=us-east-1#/compute-environments)

Click the 'Create Environment' button, then edit the new form with the inputs below:
- Compute environment type: `unmanaged`
- Compute environment name: `<environment>-pfb-analysis-unmanaged-compute-environment`
- Service role: AWSBatchServiceRole
- Instance role: StagingContainerInstanceRole
- EC2 key pair: your choice
- Enable compute environment: [x]
Click 'Create' and wait for the compute environment to provision.

Next, go to 'Job queues' -> 'Create queue' then edit the form with the inputs below:
- Queue name: `<environment>-pfb-analysis-job-queue`
- Priority: 1
- Enable job queue: [x]
- Select a compute environment: Choose the name of the environment you just created
Click create. The job queue should be ready pretty much immediately.

Once the unmanaged compute environment has a 'VALID' status, navigate to [EC2 Container Service](https://console.aws.amazon.com/ecs/home?region=us-east-1) and copy the full name of the newly created ECS Cluster into the `batch_ecs_cluster_name` tfvar for the appropriate environment.

Congratulations, the necessary resources for your environment are ready. The ECS instance configuration and autoscaling group attached to the compute environment are managed by Terraform.

## Tilegarden

We serve map tiles using [Tilegarden](https://github.com/azavea/tilegarden), a
serverless tile generator that runs on AWS Lambda. Portions of Tilegarden
are deployed separately from the Terraform stack because Tilegarden
is tightly coupled with [Claudia](https://claudiajs.com/), an opinionated
deployment tool for publishing Node code as Lambda functions. The main
components of Tilegarden that are deployed this way include a Lambda function
and an API Gateway.

CI will deploy updates to existing Tilegarden instances automatically, but there are
a few extra steps you'll need to take in order to stand up an entirely new
instance of Tilegarden.

### 1. Create a remote state bucket for Claudia

Remote state for Claudia should exist in the same S3 bucket as Terraform remote
state. For staging, this bucket should be something like `staging-pfb-config-us-east-1`.
In that bucket, create a new folder (that is, an object prefix) for
Tilegarden remote state called `tilegarden/`.

### 2. Configure environment variables for your function

Tilegarden uses an `.env` file in order to pass environment variables into
the Lambda function. Copy over the example file to create a new one:

```
$ cp ./src/tilegarden/.env.example ./src/tilegarden/.env
```

Edit the new file to fill in or adjust variables.  The required variables are:
- `AWS_PROFILE`: the name of the AWS credentials profile you created above, e.g. "pfb"
- `PROJECT_NAME`: a name to identify this deployment, which should include the environment name
- `LAMBDA_REGION`
- `LAMBDA_ROLE`: the role the Lambda function should run under. Use the one created by Terraform, e.g. "pfbStagingTilegardenExecutor"

Other optional variables can be uncommented and edited to reflect your configuration. If you
need Tilegarden to access a database, for example, you'll likely want to set `LAMBDA_SUBNETS` and `LAMBDA_SECURITY_GROUPS` to point to the relevant resources in your VPC.

If you have any additional environment variables (like database connection
strings) that you need access to in your function, add them to `./src/tilegarden/.env`
and they will be passed in during deployment.

### 3. Deploy a new Tilegarden instance with Claudia

Use the Tilegarden Node scripts in the VM to deploy a new Tilegarden instance:

```
vagrant@pfb-network-connectivity:/vagrant$ docker-compose \
                                             -f docker-compose.yml \
                                             -f docker-compose.test.yml \
                                             run --rm --entrypoint yarn \
                                             tilegarden deploy-new
```

### 4. Manually add a scheduled warming event

In the [CloudWatch Rules console](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#rules:),
add a scheduled event to generate warming invocations to prevent users from being subjected to cold starts.
See [issue #714](https://github.com/azavea/pfb-network-connectivity/issues/714).

### 5. Update remote state for Claudia and Terraform

Once the deployment has completed, upload your `.env` file and Claudia metadata
file to the remote state bucket so that CI can update Tilegarden automatically:

```
$ aws s3 cp ./src/tilegarden/.env s3://<remote-state-bucket>/tilegarden/.env
$ aws s3 cp ./src/tilegarden/claudia/claudia.json s3://<remote-state-bucket>/tilegarden/claudia.json
```

In addition, edit the remote Terraform variables in `terraform.tfvars` for your
deployment to point to the domain name for the new API Gateway that Claudia has created.
The variable for the API Gateway should look something like this:

```hcl
# Tilegarden
tilegarden_api_gateway_domain_name = "<api.id>.execute-api.<lambda.region>.amazonaws.com"
```

You can locate this domain name in the Lambda console, or you can construct it
by using the `api.id` and `lambda.region` values stored in the `claudia.json` file
that Claudia created during deployment to format the example string in the
code block above.

### A note about Terraform resources

Certain Terraform and Tilegarden resources are interdependent, in that they expect
IDs of resources created by the other deployment tool as input variables. In particular,
the CloudFront CDN managed by Terraform relies on the `tilegarden_api_gateway_domain_name`
variable in order to point the CDN to the Tilegarden API Gateway endpoint, and the
Tilegarden Claudia deployment tool relies on the `LAMBDA_SUBNETS` and
`LAMBDA_SECURITY_GROUPS` variables in order to give the Tilegarden Lambda
function access to database resources in the VPC.

In order to manage this interdependence, we recommend that you first deploy
Terraform resources using a dummy value for `tilegarden_api_gateway_endpoint`;
this way, all of the Terraform infrastructure should build correctly, but the CDN will
not serve tiles properly. Then, stand up a Tilegarden instance using the relevant
input values from your Terraform-managed resources, and once you're done
deploying Tilegarden you can update `tilegarden_api_gateway_endpoint` to point
to the API Gateway that Claudia has created.

In brief, the anticipated order of resource creation when deploying a new
stack should be:

1. Create Batch resources
2. Create Terraform resources with dummy `tilegarden_api_gateway_domain_name`
   variable
3. Create Tilegarden resources
4. Update Terraform resources with correct `tilegarden_api_gateway_domain_name`
   variable
