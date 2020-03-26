from builtins import str
from django.core.management.base import BaseCommand

from copy import deepcopy
import logging
import os
import shutil
import tempfile
import zipfile

import boto3

from django.conf import settings
from django.contrib.gis.utils import LayerMapping
from django.core.exceptions import ValidationError
from django.db import transaction

from pfb_analysis.models import (
    AnalysisJob,
    CensusBlocksResults,
    Neighborhood,
    NeighborhoodWaysResults
)

logger = logging.getLogger(__name__)


CENSUS_BLOCK_LAYER_MAPPING = {
    'geom': 'POLYGON',
    'overall_score': 'OVERALL_SC',
}

NEIGHBORHOOD_WAYS_LAYER_MAPPING = {
    'geom': 'LINESTRING',
    'tf_seg_str': 'TF_SEG_STR',
    'ft_seg_str': 'FT_SEG_STR',
    'xwalk': 'XWALK',
    'ft_bike_in': 'FT_BIKE_IN',
    'tf_bike_in': 'TF_BIKE_IN',
    'functional': 'FUNCTIONAL',
}


def geom_from_results_url(shapefile_key):
    """ Downloads and extracts a zipped shapefile and returns the containing temporary directory.
    """
    logger.info('Importing results back from shapefile: {sfile}'.format(sfile=shapefile_key))
    tmpdir = tempfile.mkdtemp()
    local_zipfile = os.path.join(tmpdir, 'shapefile.zip')
    s3_client = boto3.client('s3')
    s3_client.download_file(settings.AWS_STORAGE_BUCKET_NAME,
                            shapefile_key,
                            local_zipfile)
    with zipfile.ZipFile(local_zipfile, 'r') as zip_handle:
        zip_handle.extractall(tmpdir)
    return tmpdir


def s3_job_url(job, filename):
    return 'results/{uuid}/{filename}'.format(uuid=job.uuid, filename=filename)


def add_results_geoms(job):

    @transaction.atomic
    def import_shapefile(job, shpfile_name, model, layer_mapping):
        # Clear existing geometries, in case this is a re-import
        model.objects.filter(job=job).delete()
        import_tmpdir = ''
        try:
            import_tmpdir = geom_from_results_url(s3_job_url(job, shpfile_name))
            import_shpfiles = [filename for filename in
                               os.listdir(import_tmpdir) if filename.endswith('shp')]
            import_file = os.path.join(import_tmpdir, import_shpfiles[0])
            import_layer_map = LayerMapping(model,
                                            import_file,
                                            layer_mapping)
            import_layer_map.save()
            # Set job ID on the objects we just imported. Since we're in a transaction, there
            # should be no potential for conflict between simultaneous imports.
            model.objects.filter(job=None).update(job=job)
        except Exception:
            logger.exception('Error importing {} shapefile for job: {}'.format(str(model),
                                                                               str(job.uuid)))
            raise
        finally:
            if import_tmpdir:
                shutil.rmtree(import_tmpdir, ignore_errors=True)

    import_shapefile(job, 'neighborhood_census_blocks.zip',
                     CensusBlocksResults, CENSUS_BLOCK_LAYER_MAPPING)

    # Mask imported Census block results to neighborhood bounds to exclude null results
    # out of bounds, as all nulls are read as zeroes from the shapefile, and so
    # indistinguishable from actual zero scores.
    CensusBlocksResults.objects.filter(job=job,
                                       overall_score=0,
                                       geom__disjoint=job.neighborhood.geom).delete()

    import_shapefile(job, 'neighborhood_ways.zip',
                     NeighborhoodWaysResults, NEIGHBORHOOD_WAYS_LAYER_MAPPING)


class Command(BaseCommand):
    help = """Import back results and geometries from exported shapefiles for an analysis job.

    If job UUID not specified, will run for all analysis jobs.
    """

    def add_arguments(self, parser):
        # Positional arguments
        parser.add_argument('job_id', nargs='?')

    def handle(self, *args, **options):
        try:
            job_id = options['job_id']
            if job_id:
                job = AnalysisJob.objects.get(pk=job_id)
                logger.info('Running import for analysis job {job_id}.'.format(job_id=job.uuid))
                add_results_geoms(job)
            else:
                logger.info('Running import for all current analysis jobs.')
                imported = 0
                failed = 0
                for neighborhood in Neighborhood.objects.all():
                    job = neighborhood.last_job
                    if not job or not job.status == AnalysisJob.Status.COMPLETE:
                        continue
                    try:
                        add_results_geoms(job)
                        imported += 1
                    except Exception:
                        logger.exception('ERROR: Failed re-importing results for job '
                                         '{job_id}'.format(**options))
                        failed += 1
                logger.info('Successfully imported {imported} job(s)'.format(imported=imported))
                if failed > 0:
                    logger.error('Failed to import {failed} job(s)'.format(failed=failed))
            logger.info('import_results_shapefiles completed')
        except (AnalysisJob.DoesNotExist, ValueError, KeyError, ValidationError):
            logger.exception('ERROR: Tried to re-import results for invalid job UUID '
                             '{job_id}'.format(**options))
