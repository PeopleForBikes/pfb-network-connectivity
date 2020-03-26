import logging

import boto3
from botocore.exceptions import BotoCoreError


logger = logging.getLogger(__name__)


class JobState:
    """ AWS Batch Job States

    See: http://docs.aws.amazon.com/batch/latest/userguide/jobs.html

    """
    SUBMITTED = 'SUBMITTED'
    PENDING = 'PENDING'
    RUNNABLE = 'RUNNABLE'
    STARTING = 'STARTING'
    RUNNING = 'RUNNING'
    SUCCEEDED = 'SUCCEEDED'
    FAILED = 'FAILED'

    ACTIVE_STATUSES = (SUBMITTED, PENDING, RUNNABLE, STARTING, RUNNING,)


class NoActiveJobDefinitionRevision(BotoCoreError):
    """ Raised when an AWS Batch Job Definition has no active revision

    Init with kwarg 'job_definition' to display in error
    e.g. raise NoActiveJobDefinitionError(job_definition='foo')

    """
    fmt = '{job_definition}'


def get_latest_job_definition(job_definition_name):
    """ Get the latest revision of an AWS Batch job definition

    Raises NoActiveJobDefinitionRevision if no current active revision for the
        requested job definition

    """
    client = boto3.client('batch')
    response = client.describe_job_definitions(jobDefinitionName=job_definition_name,
                                               status='ACTIVE')
    job_definitions = response.get('jobDefinitions', [])
    while(response.get('nextToken') is not None):
        response = client.describe_job_definitions(jobDefinitionName=job_definition_name,
                                                   status='ACTIVE',
                                                   nextToken=response['nextToken'])
        job_definitions.extend(response.get('jobDefinitions', []))
    sorted_definitions = sorted(job_definitions, key=lambda job: job['revision'])
    try:
        return sorted_definitions.pop()
    except IndexError:
        raise NoActiveJobDefinitionRevision(job_definition=job_definition_name)
