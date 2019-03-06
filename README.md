# pfb-network-connectivity

PFB Bicycle Network Connectivity

## Getting Started

Requirements:
- Vagrant 1.8.3+
- VirtualBox 4.3+
- [AWS CLI](https://aws.amazon.com/cli/)

#### Notes for Windows users

1. Ensure all project files checkout with LF (unix) line endings. The easiest way is to run `git config --global core.autocrlf false` before checking out the project. Alternatively, you can checkout the project, then run `git config core.autocrlf false` within the project dir, then manually fix all remaining CRLF line endings before running `vagrant up`.
2. Run all commands in a **shell with administrator permissions**. It's highly recommended to run all commands within the "Git for Windows" Git Bash shell, as that already includes an SSH client, and allows running the commands below as-is.
3. Before starting the VM, ensure the ENV variable `PFB_SHARED_FOLDER_TYPE=virtualbox` is set. NFS is not supported on windows, so we need to ensure that Vagrant ignores our request for it.
4. Do not use `vagrant reload`. In some cases it will create a new VM rather than autodetecting that the old one exists

#### Notes for non-Windows users

1. An NFS daemon must be running on the host machine. This should be enabled by default on MacOS. Linux computers may require the installation of an additional package such as nfs-kernel-server on Ubuntu.

### Setting up AWS credentials

**Note:** If you do not have AWS credentials, this step can be skipped if you just want to run local analyses.
Continue below at [Provisioning the VM](#provisioning-the-vm)

As noted above, ensure the AWS CLI is installed on your host machine. Once it is, you can configure your PFB account credentials by running:
```
aws configure --profile pfb
```

### Provisioning the VM

First you'll need to copy the example ansible group_vars file:
```
cp deployment/ansible/group_vars/all.example deployment/ansible/group_vars/all
```

If you want to run the full development application and you've configured AWS credentials, copy the appropriate values at the links below into `deployment/ansible/group_vars/all`, choosing the resources with 'staging' in the name:
- [AWS Batch Job Queue](https://console.aws.amazon.com/batch/home?region=us-east-1#/queues): Copy the staging `analysis` job queue name to the equivalent group var setting.

If you don't have access to the console, or just want to run a local analysis, copying the values into `group_vars/all` can be skipped.

Run `./scripts/setup` to install project dependencies and prepare the development environment. Then, SSH into the VM:
```
vagrant ssh
```

Once in the VM, if you added AWS credentials above, run the following commands to configure your development S3 buckets:
```
aws s3api create-bucket --bucket "${DEV_USER}-pfb-storage-us-east-1"
aws s3api put-bucket-policy --bucket "${DEV_USER}-pfb-storage-us-east-1" --policy "{\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::${DEV_USER}-pfb-storage-us-east-1/*\"}]}"
```

At this point, if you only intend to run the 'Bike Network Analysis', skip directly to [Running the Analysis](#running-the-analysis)

To start the application containers:
```
./scripts/server
```

In order to use the API, you'll need to run migrations on the Django app server:
```
./scripts/django-manage migrate

This will add a default admin user that can log in to http://localhost:9200/api/ as:
systems+pfb@azavea.com / root
```


## Ports

| Port | Service | Notes |
| ---- | ------- | ----- |
| 9200 | Nginx ||
| 9202 | Gunicorn ||
| 9203 | Django Runserver | Not running by default. Must be started manually via `scripts/django-manage` |
| 9214 | Postgresql | Allows direct connections to the database where an analysis run is stored |
| 9301 | Gulp | Gulp server for analysis angular app |
| 9302 | Browsersync | Browsersync for analysis angular app |
| 9400 | Tilegarden | Tilegarden development server |
| 9401 | Browsersync | Node debugger for Tilegarden development server |


## Scripts

| Name | Description |
| ---- | ----------- |
| setup | Bring up a dev VM, and perform initial installation steps |
| update | Re-build application Docker containers and run database migrations |
| server | Start the application containers |
| console | Start a bash shell on one of the running Docker containers |
| django-manage | Run a Django management command on the django container |


## Running the Analysis

On creating a local anaylsis job in the admin UI, the Django logs will print the appropriate command
to run in the VM console to actually run the analysis jobs locally.

See [Running the Analysis Locally](README.LOCAL-ANALYSIS.md) for details.


## Verifying the Analysis

The output from the analysis run may be compared to previous output to see if it has changed. See the section below for the input parameters used to generate the verified output.

Build the docker container for the verification tool within the VM:
```
cd src/verifier
docker-compose build
```

Ensure the exported output from the analysis to check exists in the `data/output` directory. It will be there by default if the `data` directory was used for the neighborhood input shapefile.

To compare the analysis output for Boulder, run the verification tool with:
```
docker-compose run verifier boulder.csv
```

Any output in the `verified_output` directory may be used for comparison.

To compare to analysis output that has a non-default filename (`analysis_neighborhood_score_inputs.csv`), run the verification tool with the name of the file in `data/output` as the second argument:
```
docker-compose run verifier boulder.csv my_output_to_verify.csv
```

If there are any differences in the outputs, a summary of the differences will be output to console.

### Verified Output Parameters

The analysis output in the `verified_output` directory was generated using the following input parameters and files:

Boulder:
- BOUNDARY_BUFFER=50
- https://s3.amazonaws.com/test-pfb-inputs/boulder/boulder.osm
- https://s3.amazonaws.com/test-pfb-inputs/boulder/boulder.zip
