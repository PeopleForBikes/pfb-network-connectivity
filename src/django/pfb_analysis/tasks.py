import logging
import os
import shutil
import tempfile
import zipfile

import boto3

from django.conf import settings
from django.core.exceptions import ObjectDoesNotExist, ValidationError

from pfb_analysis.management.commands.import_results_shapefiles import add_results_geoms
from pfb_analysis.management.commands.load_overall_scores import load_scores
from pfb_analysis.models import AnalysisBatch, AnalysisJob, AnalysisLocalUploadTask
from pfb_network_connectivity.utils import download_file
from users.models import PFBUser

logger = logging.getLogger(__name__)

DESTINATION_ANALYSIS_FILES = set(['neighborhood_{}.geojson'.format(destination)
                                 for destination in settings.PFB_ANALYSIS_DESTINATIONS])

OVERALL_SCORES_FILE = 'neighborhood_overall_scores.csv'

OTHER_RESULTS_FILES = set([
    'neighborhood_score_inputs.csv',
    'neighborhood_ways.zip',
    'neighborhood_census_blocks.zip',
    OVERALL_SCORES_FILE,
    'neighborhood_connected_census_blocks.csv.zip'])

# The set of all the results files from a local analysis run to upload on import
LOCAL_ANALYSIS_FILES = DESTINATION_ANALYSIS_FILES.union(OTHER_RESULTS_FILES)


def create_batch_from_remote_shapefile(shapefile_url):

    tmpdir = tempfile.mkdtemp()
    try:
        local_filename = os.path.join(tmpdir, 'shapefile.zip')
        download_file(shapefile_url, local_filename=local_filename)
        user = PFBUser.objects.get_root_user()
        batch = AnalysisBatch.objects.create_from_shapefile(local_filename, submit=False, user=user)
        batch.submit()
    finally:
        shutil.rmtree(tmpdir)


class LocalAnalysisFetchException(Exception):
    """Holds the message for use as the error on `AnalysisLocalUploadTask` API responses."""
    pass


def upload_local_analysis(local_upload_task_uuid):

    def upload_and_insert_local_results(tmpdir, task):
        try:
            s3_client = boto3.client('s3')

            # Upload the files extracted to the tmp dir to the expected S3 locations for the job
            for results_file in LOCAL_ANALYSIS_FILES:
                s3_key = '{results_path}/{filename}'.format(results_path=task.job.s3_results_path,
                                                            filename=results_file)
                local_file = os.path.join(tmpdir, results_file)
                s3_client.upload_file(local_file, settings.AWS_STORAGE_BUCKET_NAME, s3_key)

            logging.info('Uploaded results files to S3 in {directory}'.format(
                directory=task.job.s3_results_path))

            # Store the neigborhood ways and Census block results back to models
            logging.info('Importing neighborhood ways and Census blocks back to database')
            add_results_geoms(task.job)
        except Exception as ex:
            logging.error('Failed to upload analysis results for task {uuid}'.format(
                uuid=local_upload_task_uuid))
            raise LocalAnalysisFetchException(ex.message)

    def download_and_extract_local_results(tmpdir, task):
        try:
            local_filename = os.path.join(tmpdir, 'analysis_results.zip')
            download_file(task.upload_results_url, local_filename=local_filename)
            with zipfile.ZipFile(local_filename, 'r') as zip_handle:
                zip_handle.extractall(tmpdir)
            results_files = [filename for filename in os.listdir(tmpdir)]

            # Verify all expected results files are in the upload
            missing = LOCAL_ANALYSIS_FILES.difference(set(results_files))
            if missing:
                raise LocalAnalysisFetchException('Missing expected results files: {files}'.format(
                    files=', '.join(missing)))
            logging.info('Results files extracted for upload task {uuid}'.format(
                         uuid=local_upload_task_uuid))
        except Exception as ex:
            msg = 'Failed to fetch analysis results for task {uuid} from {url}: {msg}'.format(
                uuid=local_upload_task_uuid, url=task.upload_results_url, msg=ex.message)
            logging.error(msg)
            raise LocalAnalysisFetchException(ex.message)

    try:
        logging.info('Starting local analysis upload task {uuid}'.format(
            uuid=local_upload_task_uuid))
        tmpdir = tempfile.mkdtemp()

        # First find the upload task to process and mark its status
        task = AnalysisLocalUploadTask.objects.get(uuid=local_upload_task_uuid)
        task.status = AnalysisLocalUploadTask.Status.IMPORTING
        task.save()

        # Run the local analysis download, extract, and upload for the task
        logging.info('Starting local analysis upload {uuid} from {url}'.format(
                     uuid=local_upload_task_uuid, url=task.upload_results_url))
        download_and_extract_local_results(tmpdir, task)
        upload_and_insert_local_results(tmpdir, task)
        # set the overall scores on the job
        local_scores_file = os.path.join(tmpdir, OVERALL_SCORES_FILE)
        load_scores(task.job, local_scores_file, 'score_id', None)

        # Mark this upload task and its associated analysis job as completed.
        task.status = AnalysisLocalUploadTask.Status.COMPLETE
        task.save()

        task.job.update_status(AnalysisJob.Status.COMPLETE)

        logging.info('Successfully completed upload task {uuid}'.format(
            uuid=local_upload_task_uuid))
    except (ObjectDoesNotExist, ValidationError):
        logging.error('No local upload analysis task found for {uuid}.'.format(
                      uuid=local_upload_task_uuid))
        raise
    except Exception as ex:
        task.status = AnalysisLocalUploadTask.Status.ERROR
        task.error = ex.message
        task.save()
        if task.job:
            task.job.update_status(AnalysisJob.Status.ERROR)
            task.job.save()
        raise
    finally:
        shutil.rmtree(tmpdir)
