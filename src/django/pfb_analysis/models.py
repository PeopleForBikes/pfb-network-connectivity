from __future__ import unicode_literals
from __future__ import division

from builtins import next
from builtins import str
from builtins import range
from past.builtins import basestring
from datetime import datetime
import io
import json
import logging
import math
import os
import shutil
import tempfile
import uuid
import zipfile

from django.conf import settings
from django.contrib.gis.db.models import LineStringField, MultiPolygonField, PointField
from django.contrib.gis.geos import GEOSGeometry, MultiPolygon, Polygon
from django.contrib.postgres.fields import JSONField
from django.core.files import File
from django.db import models
from django.db.models.signals import post_delete
from django.dispatch import receiver
from django.utils.text import slugify

import botocore
import boto3
from django_countries.fields import CountryField
import fiona
from fiona.crs import from_epsg
import us

from pfb_network_connectivity.models import PFBModel
from pfb_network_connectivity.utils import download_file
from users.models import Organization, PFBUser
from .functions import ObjectAtPath


logger = logging.getLogger(__name__)

# degree to which to simplify boundaries
# https://docs.djangoproject.com/en/1.11/ref/contrib/gis/geos/#django.contrib.gis.geos.GEOSGeometry.simplify
SIMPLIFICATION_TOLERANCE_MORE = 0.001
SIMPLIFICATION_TOLERANCE_LESS = 0.0001
SIMPLIFICATION_MIN_VALID_AREA_RATIO = 0.95

CITY_FIPS_LENGTH = 7  # place FIPS codes size


def get_neighborhood_file_upload_path(obj, filename):
    """Upload each boundary file to its own directory

    Upload file path should be unique for the organization.

    To maintain backwards compatibility for previously-uploaded bounds when there was no country
    field, US cities are under their two-letter state abbreviations and non-US cities are under
    their 3-letter country codes (to avoid conflicts like CA being both Canada and California).

    For non-US neighborhoods with state/province set, both country and state go in the path,
    with country still the 3-letter code.

    So the formats will be:
    US neighborhoods: org/ST/name.zip
    Non-US with no state: org/CRY/name.zip  (pretend that's the alpha_3 for "Country")
    Non-US with state: org/CRY/ST/name.zip
    """
    if obj.country == 'US' or not obj.state_abbrev:
        return 'neighborhood_boundaries/{0}/{1}/{2}{3}'.format(
            slugify(obj.organization.name),
            obj.state_abbrev or obj.country.alpha3,
            obj.name,
            os.path.splitext(filename)[1]
        )
    else:
        return 'neighborhood_boundaries/{0}/{1}/{2}/{3}{4}'.format(
            slugify(obj.organization.name),
            obj.country.alpha3,
            obj.state_abbrev,
            obj.name,
            os.path.splitext(filename)[1]
        )


def get_batch_shapefile_upload_path(organization_name, filename):
    """  """
    return 'batch_shapefiles/{0}/{1}'.format(slugify(organization_name), filename)


def simplify_geom(geom):
    """Slightly more robust geometry simplification, only for polygons with srid=4326

    Will attempt to simplify first without preserve topology at two different tolerances,
    then fall back to the higher simplification tolerance, but with topology preserved

    Returns original geom if not a polygon or multipolygon.
    """

    def is_simple_polygon_valid(simple_geom, geom):
        return (simple_geom and
                not simple_geom.empty and
                simple_geom.valid and
                # Checking a min area ratio against the original ensure we didn't oversimplify
                simple_geom.area / geom.area > SIMPLIFICATION_MIN_VALID_AREA_RATIO)

    if not (isinstance(geom, Polygon) or isinstance(geom, MultiPolygon)):
        return geom
    try:
        simple = MultiPolygon([geom.simplify(SIMPLIFICATION_TOLERANCE_MORE)])
        if is_simple_polygon_valid(simple, geom):
            logger.debug('pfb_analysis.models.simplify_geom used ' +
                         'geom.simplify(SIMPLIFICATION_TOLERANCE_MORE)')
            return simple
    except Exception:
        pass
    try:
        # sometimes an empty geometry may result, likely due to
        # https://trac.osgeo.org/geos/ticket/741
        simple = MultiPolygon([geom.simplify(SIMPLIFICATION_TOLERANCE_LESS)])
        if is_simple_polygon_valid(simple, geom):
            logger.debug('pfb_analysis.models.simplify_geom used ' +
                         'geom.simplify(SIMPLIFICATION_TOLERANCE_LESS)')
            return simple
    except Exception:
        pass
    # If both simplifications fail, fallback to preserve topology, which should always succeed
    logger.debug('pfb_analysis.models.simplify_geom used ' +
                 'geom.simplify(SIMPLIFICATION_TOLERANCE_MORE, preserve_topology=True)')
    simple = geom.simplify(SIMPLIFICATION_TOLERANCE_MORE, preserve_topology=True)
    if isinstance(simple, MultiPolygon):
        return simple
    elif isinstance(simple, Polygon):
        return MultiPolygon([simple])
    else:
        logger.warning('pfb_analysis.models.simplify_geom failed to simplify')
        return geom


def create_environment(**kwargs):
    """ Format args for AWS environment

    Writes argument pairs to an array {name, value} objects, which is what AWS wants for
    environment overrides.
    """
    return [{'name': k, 'value': v} for k, v in kwargs.items()]


class Neighborhood(PFBModel):
    """Neighborhood boundary used for an AnalysisJob """

    def __str__(self):
        return "<Neighborhood: {} ({})>".format(self.name, self.organization.name)

    class Visibility:
        PUBLIC = 'public'
        PRIVATE = 'private'
        HIDDEN = 'hidden'

        CHOICES = (
            (PUBLIC, 'Public',),
            (PRIVATE, 'Private',),
            (HIDDEN, 'Hidden',),
        )

    uuid = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.SlugField(max_length=256, help_text='Unique slug for neighborhood')
    label = models.CharField(max_length=256, help_text='Human-readable label for neighborhood, ' +
                                                       'should not include State')
    geom = MultiPolygonField(srid=4326, blank=True, null=True)
    geom_simple = MultiPolygonField(srid=4326, blank=True, null=True)
    geom_pt = PointField(srid=4326, blank=True, null=True)
    organization = models.ForeignKey(Organization,
                                     related_name='neighborhoods',
                                     on_delete=models.CASCADE)
    country = CountryField(default='US',
                           help_text='The country of the uploaded neighborhood')
    state_abbrev = models.CharField(help_text='The state/province of the uploaded neighborhood',
                                    blank=True, null=True, max_length=10)
    city_fips = models.CharField(max_length=CITY_FIPS_LENGTH, blank=True, default='')
    boundary_file = models.FileField(max_length=1024,
                                     upload_to=get_neighborhood_file_upload_path,
                                     help_text='A zipped shapefile boundary to run the '
                                               'bike network analysis on')
    visibility = models.CharField(max_length=10,
                                  choices=Visibility.CHOICES,
                                  default=Visibility.PUBLIC)
    last_job = models.ForeignKey('AnalysisJob',
                                 related_name='last_job_neighborhood',
                                 on_delete=models.SET_NULL, blank=True, null=True)

    def save(self, *args, **kwargs):
        """ Override to do validation checks before saving """
        self.name = self.name_for_label(self.label)
        self.full_clean()
        self._set_geom_from_boundary_file()
        super(Neighborhood, self).save(*args, **kwargs)

    def set_boundary_file(self, geom):
        """ Create a new boundary shapefile that mirrors geom, upload and save

        geom must be either a Polygon or MultiPolygon

        """
        boundary_file = None
        try:
            tmpdir = tempfile.mkdtemp()
            file_name = self.name
            local_shpfile = os.path.join(tmpdir, '{}.shp'.format(file_name))
            schema = {'geometry': 'MultiPolygon', 'properties': {}}
            with fiona.open(local_shpfile, 'w',
                            driver='ESRI Shapefile',
                            crs=from_epsg(4326),
                            schema=schema) as source:
                if geom.geom_type == 'Polygon':
                    geom = MultiPolygon([geom])
                feature = {
                    'geometry': json.loads(geom.json),
                    'properties': {}
                }
                source.write(feature)

            zip_filename = os.path.join(tmpdir, '{}.zip'.format(file_name))
            shpfiles = os.listdir(tmpdir)
            with zipfile.ZipFile(zip_filename, 'w') as zip_handle:
                for shpfile in shpfiles:
                    if shpfile.startswith(file_name):
                        zip_handle.write(os.path.join(tmpdir, shpfile), shpfile)
            boundary_file = File(open(zip_filename, 'rb'))
            self.boundary_file = boundary_file
            self.geom = geom
            self.geom_simple = simplify_geom(geom)
            self.geom_pt = geom.centroid
            self.save()
        finally:
            if boundary_file:
                boundary_file.close()
            shutil.rmtree(tmpdir, ignore_errors=True)

    @property
    def geom_utm(self):
        """Return the Neighborhood geometry, as a clone transformed to the appropriate UTM zone."""

        def get_zone(coord):
            """ Finds the UTM zone of a WGS84 coordinate """
            # There are 60 longitudinal projection zones numbered 1 to 60 starting at 180W
            # So that's -180 = 1, -174 = 2, -168 = 3
            zone = ((coord - -180) / 6.0)
            return int(math.ceil(zone))

        bbox = self.geom.extent
        avg_longitude = ((bbox[2] - bbox[0]) / 2) + bbox[0]
        utm_zone = get_zone(avg_longitude)
        avg_latitude = ((bbox[3] - bbox[1]) / 2) + bbox[1]

        # convert UTM zone to SRID
        # SRID for a given UTM ZONE: 32[6 if N|7 if S]<zone>
        srid = '32'
        if avg_latitude < 0:
            srid += '7'
        else:
            srid += '6'

        srid += str(utm_zone)
        return self.geom.transform(srid, clone=True)

    @property
    def state(self):
        """ Return the us.states.State object associated with this boundary

        https://github.com/unitedstates/python-us

        """
        return us.states.lookup(self.state_abbrev)

    @property
    def label_suffix(self):
        """ State/province (if applicable) and country suffix for display label.

        State/province isn't collected for some countries, and is optional for others, so
        sometimes this is just the country.
        """
        elements = [self.country.code]
        if self.state_abbrev:
            elements.insert(0, self.state_abbrev)
        return ', '.join(elements)

    @classmethod
    def name_for_label(cls, label):
        return slugify(label)

    def _set_geom_from_boundary_file(self, overwrite=False):
        """ Opens a local copy of the boundary file and sets geom field

        Does not save model
        Copies the geom of the first feature found in the shapefile into geom, to be consistent
        with the rest of the app
        No explicit error handling/logging, will raise original exception if failure

        """
        if self.geom and not overwrite and self.boundary_file and self.boundary_file._committed:
            # If the geometry already exists, 'overwrite' isn't true, and the boundary file was
            # already saved, there's nothing to do.
            # Using a private property of the FileField to figure out if there has been a change
            # to the boundary isn't ideal, but the alternative seems like it would require a lot
            # of overloading DRF internals to get that information all the way from the request
            # to the model save method.
            return
        try:
            tmpdir = tempfile.mkdtemp()
            local_zipfile = os.path.join(tmpdir, '{}.zip'.format(self.name))
            with open(local_zipfile, 'wb') as zip_handle:
                zip_handle.write(self.boundary_file.read())
            with zipfile.ZipFile(local_zipfile, 'r') as zip_handle:
                zip_handle.extractall(tmpdir)
            shpfiles = [filename for filename in os.listdir(tmpdir) if filename.endswith('shp')]
            shp_filename = os.path.join(tmpdir, shpfiles[0])
            with fiona.open(shp_filename, 'r') as shp_handle:
                feature = next(shp_handle)
                geom = GEOSGeometry(json.dumps(feature['geometry']))
                if geom.geom_type == 'Polygon':
                    geom = MultiPolygon([geom])
                self.geom = geom
                self.geom_simple = simplify_geom(geom)
                self.geom_pt = geom.centroid
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)

    class Meta:
        # Note that uniqueness fields should also be used in the upload file path
        unique_together = ('name', 'country', 'state_abbrev', 'organization',)


@receiver(post_delete, sender=Neighborhood)
def delete_boundary_file(sender, instance, **kwargs):
    instance.boundary_file.delete(save=False)
    logger.info("Deleted boundary file for {}, {}".format(instance.label, instance.label_suffix))


class AnalysisBatchManager(models.Manager):

    def create_from_shapefile(self, shapefile, submit=False, user=None, *args, **kwargs):
        """ Create a new AnalysisBatch from a well-formatted shapefile.

       shapefile can be one of:
        - HTTP URL to remote, publicly accessible zip file
        - local path to zipfile containing shapefile (must end with .zip extension)
        - local path to unzipped shapefile (must end with .shp extension)
          - will search for associated files in same dir as the shpfile

        """
        if not user:
            user = PFBUser.objects.get_root_user()
        batch = AnalysisBatch.objects.create(created_by=user, modified_by=user)
        tmpdir = tempfile.mkdtemp()
        source = None

        shapefile_input = shapefile
        try:
            logger.debug('AnalysisBatch.create_from_shapefile using temp dir: {}'.format(tmpdir))

            if isinstance(shapefile_input, basestring) and os.path.splitext(shapefile_input)[1] == '.zip':
                # If we need to download the zipped shapefile, do that and update the input path
                if shapefile_input.startswith('http'):
                    local_zipfile = os.path.join(tmpdir, 'boundary.zip')
                    download_file(shapefile_input, local_zipfile)
                    shapefile_input = local_zipfile

                # Extract the zipfile (whether downloaded or local) and find shp filename
                local_zipfile = shapefile_input
                with zipfile.ZipFile(local_zipfile) as zip:
                    files = zip.namelist()
                    zip.extractall(tmpdir)
                    local_shapefile = next(filename
                                           for filename in files if filename.endswith('.shp'))
                local_shapefile = os.path.join(tmpdir, local_shapefile)
                shapefile_input = local_shapefile

            # Open the shapefile
            if isinstance(shapefile_input, basestring) and os.path.splitext(shapefile_input)[1] == '.shp':
                source = fiona.open(shapefile_input, 'r')
            else:
                raise TypeError('Must provide shapefile to AnalysisBatch.create_from_shapefile')

            for feature in source:
                city = feature['properties']['city']
                state = feature['properties']['state']
                city_fips = feature['properties'].get('city_fips', '')
                osm_extract_url = feature['properties'].get('osm_url', None)
                label = city
                name = Neighborhood.name_for_label(label)

                # Get or create neighborhood for feature
                neighborhood_dict = {
                    'name': name,
                    'label': label,
                    'state_abbrev': state,
                    'city_fips': city_fips,
                    'organization': user.organization,
                    'created_by': user,
                    'modified_by': user,
                }
                geom = GEOSGeometry(json.dumps(feature['geometry']))
                try:
                    neighborhood = Neighborhood.objects.get(**neighborhood_dict)
                except Neighborhood.DoesNotExist:
                    neighborhood = Neighborhood(**neighborhood_dict)
                    logger.info('AnalysisBatch.create_from_shapefile CREATED: {}'
                                .format(neighborhood))

                neighborhood.set_boundary_file(geom)

                # Create new job
                job = AnalysisJob.objects.create(neighborhood=neighborhood,
                                                 batch=batch,
                                                 osm_extract_url=osm_extract_url,
                                                 created_by=user,
                                                 modified_by=user)
                logger.info('AnalysisBatch.create_from_shapefile ID: {} -- {}'
                            .format(str(job.uuid), str(job)))
        except Exception as e:
            logger.exception(e)
            # If job creation failed, delete the batch
            batch.delete()
            raise
        finally:
            logger.debug('AnalysisBatch.create_from_shapefile removing temporary files...')
            shutil.rmtree(tmpdir, ignore_errors=True)
            if isinstance(source, io.IOBase):
                source.close()

        if submit:
            logger.info('AnalysisBatch.create_from_shapefile starting all jobs...')
            batch.submit()
            logger.info('AnalysisBatch.create_from_shapefile started {} jobs.'
                        .format(batch.jobs.count()))
        return batch


class AnalysisBatch(PFBModel):
    """ Container for a grouping of AnalysisJobs that are run together

    Allows us to track whether each job in a batch succeeded

    An AnalysisJob does not need to belong to an AnalysisBatch

    """

    objects = AnalysisBatchManager()

    def __str__(self):
        return '<AnalysisBatch: {} -- {}>'.format(str(self.uuid), self.created_at)

    def submit(self):
        """ Start all jobs in the batch """
        for job in self.jobs.all():
            job.run()

    def cancel(self, reason=None):
        """ Cancel all still-running jobs in the batch """
        def chunks(l, n):
            for i in range(0, len(l), n):
                yield l[i:i + n]

        if not reason:
            reason = 'AnalysisBatch terminated by user at {}'.format(datetime.utcnow())
        for job in self.jobs.all():
            try:
                job.cancel(reason=reason)
            except Exception as e:
                if job.batch_job_id:
                    logger.warning('Cancelling {} failed'.format(job.batch_job_id))
                logger.exception('Cancelling job {} failed: {}'.format(job, e))


class AnalysisJobManager(models.Manager):
    def get_queryset(self):
        qs = super(AnalysisJobManager, self).get_queryset()
        qs = (qs.annotate(overall_score=ObjectAtPath('overall_scores',
                                                     ('overall_score', 'score_normalized')))
                .annotate(population_total=ObjectAtPath('overall_scores',
                                                        ('population_total', 'score_original'),
                          output_field=models.PositiveIntegerField())))
        return qs


def generate_analysis_job_def():
    return settings.PFB_AWS_BATCH_ANALYSIS_JOB_DEFINITION_NAME_REVISION


class AnalysisJob(PFBModel):

    def __str__(self):
        return "<AnalysisJob: {status} {neighborhood}>".format(status=self.status,
                                                               neighborhood=self.neighborhood.label)

    class Status:
        CREATED = 'CREATED'
        QUEUED = 'QUEUED'
        IMPORTING = 'IMPORTING'
        BUILDING = 'BUILDING'
        CONNECTIVITY = 'CONNECTIVITY'
        METRICS = 'METRICS'
        EXPORTING = 'EXPORTING'
        COMPLETE = 'COMPLETE'
        CANCELLED = 'CANCELLED'
        ERROR = 'ERROR'

        ACTIVE_STATUSES = (CREATED, QUEUED, IMPORTING, BUILDING, CONNECTIVITY,
                           METRICS, EXPORTING,)
        SUCCESS_STATUS = COMPLETE
        DONE_STATUSES = (SUCCESS_STATUS, CANCELLED, ERROR,)

        CHOICES = (
            (CREATED, 'Created',),
            (QUEUED, 'Queued',),
            (IMPORTING, 'Importing Data',),
            (BUILDING, 'Building Network Graph',),
            (CONNECTIVITY, 'Calculating Connectivity',),
            (METRICS, 'Calculating Graph Metrics',),
            (EXPORTING, 'Exporting Results',),
            (COMPLETE, 'Complete',),
            (CANCELLED, 'Cancelled',),
            (ERROR, 'Error',),
        )

    batch_job_id = models.CharField(max_length=256, blank=True, null=True)
    neighborhood = models.ForeignKey(Neighborhood,
                                     related_name='analysis_jobs',
                                     on_delete=models.CASCADE)
    osm_extract_url = models.URLField(max_length=2048, null=True, blank=True, help_text=(
        'Load OSM data for this neighborhood from a URL rather than pulling from Goefabrik '
        'extracts. The url must be to an uncompressed OSM file (with .osm extension) or a '
        'compressed OSM file (with .osm.zip, .osm.gzip, .osm.bz2, or .osm.pbf extension). '
        'e.g. http://a.com/foo.osm or http://a.com/foo.osm.bz2'
    ))
    overall_scores = JSONField(db_index=True, default=dict)
    census_block_count = models.PositiveIntegerField(blank=True, null=True)

    analysis_job_definition = models.CharField(max_length=50, default=generate_analysis_job_def)
    _analysis_job_name = models.CharField(max_length=50, default='')
    start_time = models.DateTimeField(null=True, blank=True)
    final_runtime = models.PositiveIntegerField(default=0)
    status = models.CharField(choices=Status.CHOICES, max_length=12, default=Status.CREATED)

    objects = AnalysisJobManager()

    @property
    def batch_job_status(self):
        """ Return current AWS Batch job status for this job

        List of available statuses: http://docs.aws.amazon.com/batch/latest/userguide/jobs.html
        TODO: Refactor to cache in db?
        """
        if not self.batch_job_id:
            return None
        client = boto3.client('batch')
        try:
            jobs = client.describe_jobs(jobs=[self.batch_job_id])['jobs']
            return jobs[0]['status']
        except (KeyError, IndexError):
            logger.exception('Error retrieving AWS Batch job status for job'.format(self.uuid))
            return None

    batch = models.ForeignKey(AnalysisBatch,
                              related_name='jobs',
                              on_delete=models.CASCADE,
                              null=True, blank=True)

    @property
    def analysis_job_name(self):
        if not self._analysis_job_name:
            job_definition = self.analysis_job_definition
            # Due to CloudWatch logs limits, job name must be no more than 50 chars
            # so force truncate to that to keep jobs from failing
            definition_name, revision = job_definition.split(':')
            job_name = '{}--{}--{}'.format(definition_name[:30], revision, str(self.uuid)[:8])
            self._analysis_job_name = job_name
            self.save()
        return self._analysis_job_name

    @property
    def census_blocks_url(self):
        return self._s3_url_for_result_resource('neighborhood_census_blocks.zip')

    @property
    def connected_census_blocks_url(self):
        return self._s3_url_for_result_resource('neighborhood_connected_census_blocks.csv.zip')

    @property
    def destinations_urls(self):
        """ Return a dict of the available destinations files for this job """
        return [{
            'name': destination,
            'url': self._s3_url_for_result_resource('neighborhood_{}.geojson'.format(destination))
        } for destination in settings.PFB_ANALYSIS_DESTINATIONS]

    def tile_url_for_layer(self, layer):
        tile_template = '{z}/{x}/{y}.png'
        return '{root}/tile/{job_id}/{layer}/{tile_template}'.format(
            root=settings.TILEGARDEN_ROOT,
            job_id=self.uuid,
            layer=layer,
            tile_template=tile_template
        )

    @property
    def tile_urls(self):
        return [{'name': layer, 'url': self.tile_url_for_layer(layer)}
                for layer in ('ways', 'census_blocks', 'bike_infrastructure')]

    @property
    def overall_scores_url(self):
        return self._s3_url_for_result_resource('neighborhood_overall_scores.csv')

    @property
    def score_inputs_url(self):
        return self._s3_url_for_result_resource('neighborhood_score_inputs.csv')

    @property
    def logs_url(self):
        url = ('https://console.aws.amazon.com/cloudwatch/home?region={aws_region}' +
               '#logStream:group=/aws/batch/job;prefix={batch_job_name}/{batch_job_id}' +
               ';streamFilter=typeLogStreamPrefix')
        return url.format(aws_region=settings.AWS_REGION,
                          batch_job_name=self.analysis_job_name,
                          batch_job_id=self.batch_job_id)

    @property
    def running_time(self):
        """ Return the running time of the job in seconds """
        if self.final_runtime or not self.start_time:
            # already calculated for a job that's done, or 0 if not started yet
            return self.final_runtime

        last_update = self.status_updates.last()
        if last_update is None:
            return 0
        diff = last_update.timestamp - self.start_time
        return int(diff.total_seconds())

    @property
    def ways_url(self):
        return self._s3_url_for_result_resource('neighborhood_ways.zip')

    def cancel(self, reason=None):
        """ Cancel the analysis job, if its running """
        if not reason:
            reason = 'AnalysisJob terminated by user at {}'.format(datetime.utcnow())

        if self.status in self.Status.ACTIVE_STATUSES:
            logger.info('Cancelling job: {}'.format(self))
            old_status = self.status
            self.update_status(self.Status.CANCELLED)
            if self.batch_job_id is not None:
                try:
                    client = boto3.client('batch')
                    client.terminate_job(jobId=self.batch_job_id, reason=reason)
                except:
                    self.update_status(old_status,
                                       'REVERTED',
                                       'Reverted due to failure cancelling job in AWS Batch')
                    raise

    def base_environment(self):
        """ Convenience method for copying the environment to hand to batch jobs """

        # Since we run django manage commands in the analysis container, it needs a copy of
        # all the environment variables that this app needs, most of which are conveniently
        # prefixed with 'PFB_'
        # Set these first so they can be overridden by job specific settings below
        environment = {key: val for (key, val) in list(os.environ.items())
                       if key.startswith('PFB_') and val is not None}
        # For the ones without the 'PFB_' prefix, send the settings rather than the original
        # environment variables because the environment variables might be None, which is not
        # acceptable as a container override environment value, but the settings values will be set
        # to whatever they default to in settings.
        environment.update({
            'DJANGO_ENV': settings.DJANGO_ENV,
            'DJANGO_LOG_LEVEL': settings.DJANGO_LOG_LEVEL,
            'AWS_DEFAULT_REGION': settings.AWS_REGION,
        })
        return environment

    def run(self):
        """ Run the analysis job, configuring ENV appropriately """
        if self.status != self.Status.CREATED:
            logger.warning('Attempt to re-run job: {}. Skipping.'.format(self.uuid))
            return

        # TODO: #614 remove this check on adding support for running international jobs
        if not self.neighborhood.state:
            logger.warning('Running jobs outside the US is not supported yet. Skipping {}.'.format(
                self.uuid))
            self.update_status(self.Status.ERROR)
            return

        # Provide the base environment to enable runnin Django commands in the container
        environment = self.base_environment()
        # Job-specific settings
        environment.update({
            'NB_TEMPDIR': os.path.join('/tmp', str(self.uuid)),
            'PGDATA': os.path.join('/pgdata', str(self.uuid)),
            'PFB_SHPFILE_URL': self.neighborhood.boundary_file.url,
            'PFB_STATE': self.neighborhood.state_abbrev,
            'PFB_STATE_FIPS': self.neighborhood.state.fips,
            'PFB_CITY_FIPS': self.neighborhood.city_fips,
            'PFB_JOB_ID': str(self.uuid),
            'AWS_STORAGE_BUCKET_NAME': settings.AWS_STORAGE_BUCKET_NAME,
            'PFB_S3_RESULTS_PATH': self.s3_results_path
        })

        if self.osm_extract_url:
            environment['PFB_OSM_FILE_URL'] = self.osm_extract_url

        # Workaround for not being able to run development jobs on the actual batch cluster:
        # bail out with a helpful message
        if settings.DJANGO_ENV == 'development':
            self.update_status(self.Status.QUEUED)
            logger.warning("Can't actually run development analysis jobs on AWS. Try this:"
                        "\nPFB_JOB_ID='{PFB_JOB_ID}' PFB_CITY_FIPS='{PFB_CITY_FIPS}' PFB_S3_RESULTS_PATH='{PFB_S3_RESULTS_PATH}' "
                        "./scripts/run-local-analysis "
                        "'{PFB_SHPFILE_URL}' {PFB_STATE} {PFB_STATE_FIPS}".format(**environment))
            return

        client = boto3.client('batch')
        container_overrides = {
            'environment': create_environment(**environment),
        }
        try:
            response = client.submit_job(
                jobName=self.analysis_job_name,
                jobDefinition=self.analysis_job_definition,
                jobQueue=settings.PFB_AWS_BATCH_ANALYSIS_JOB_QUEUE_NAME,
                containerOverrides=container_overrides)
            self.batch_job_id = response['jobId']
            self.save()
            self.update_status(self.Status.QUEUED)
        except (botocore.exceptions.BotoCoreError, KeyError):
            logger.exception('Error starting AnalysisJob {}'.format(self.uuid))

    def update_status(self, status, step='', message=''):
        if self.status == self.Status.CANCELLED:
            return

        update = self.status_updates.create(job=self, status=status, step=step, message=message)
        self.status = status
        # neighborhood last job is last completed, or last updated
        if (status == self.Status.COMPLETE or not self.neighborhood.last_job or
                self.neighborhood.last_job.status != self.Status.COMPLETE):
            self.neighborhood.last_job = self
            self.neighborhood.save()

        if status == self.Status.IMPORTING and not self.start_time:
            self.start_time = update.timestamp
        elif status in self.Status.DONE_STATUSES:
            self.final_runtime = self.running_time
        self.save()

    @property
    def s3_results_path(self):
        return 'results/{jobId}'.format(jobId=str(self.uuid))

    @property
    def s3_tiles_path(self):
        return '{}/tiles'.format(self.s3_results_path)

    def _s3_url_for_result_resource(self, filename):
        return 'https://s3.amazonaws.com/{bucket}/{path}/{filename}'.format(
            bucket=settings.AWS_STORAGE_BUCKET_NAME,
            path=self.s3_results_path,
            filename=filename,
        )


@receiver(post_delete, sender=AnalysisJob)
def delete_analysisjob_s3_results(sender, instance, **kwargs):
    s3 = boto3.resource('s3')
    bucket = s3.Bucket(settings.AWS_STORAGE_BUCKET_NAME)
    path = instance.s3_results_path
    delete_result = bucket.objects.filter(Prefix=path).delete()
    try:
        logger.info("Deleted {} results files from {}".format(
            sum(len(batch['Deleted']) for batch in delete_result),
            path,
        ))
    except KeyError:
        # If the delete_result isn't as expected, still log a message
        logger.info("Deleted S3 files from {}".format(path))


class NeighborhoodWaysResults(models.Model):
    """ Stores geometries and results from the neighborhood ways shapefile.

    """
    uuid = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    geom = LineStringField(srid=4326, blank=True, null=True)
    job = models.ForeignKey(AnalysisJob,
                            related_name='neighborhood_way_results',
                            on_delete=models.CASCADE,
                            null=True,
                            blank=True)

    tf_seg_str = models.PositiveSmallIntegerField(blank=True, null=True)
    ft_seg_str = models.PositiveSmallIntegerField(blank=True, null=True)
    xwalk = models.PositiveSmallIntegerField(blank=True, null=True)
    ft_bike_in = models.CharField(blank=True, null=True, max_length=20)
    tf_bike_in = models.CharField(blank=True, null=True, max_length=20)
    functional = models.CharField(blank=True, null=True, max_length=20)


class CensusBlocksResults(models.Model):
    """ Stores geometries and results from the Census blocks shapefile.

    """
    uuid = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    geom = MultiPolygonField(srid=4326, blank=True, null=True)
    job = models.ForeignKey(AnalysisJob,
                            related_name='census_block_results',
                            on_delete=models.CASCADE,
                            null=True,
                            blank=True)

    overall_score = models.FloatField(blank=True, null=True)


class AnalysisJobStatusUpdate(models.Model):
    """ Related model for AnalysisJob, to provide record of status updates as job progresses

    Rather than creating these objects directly, they should be created using:
        AnalysisJob.update_status()

    """
    job = models.ForeignKey(AnalysisJob, related_name='status_updates', on_delete=models.CASCADE)
    status = models.CharField(choices=AnalysisJob.Status.CHOICES, max_length=12)
    step = models.CharField(max_length=50)
    message = models.CharField(max_length=256, null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        # NOTE: Changing ordering=timestamp would invalidate assumptions about the ordering of
        #       these objects elsewhere in the model. Proceed with caution.
        ordering = ('timestamp',)

    def save(self, *args, **kwargs):
        """ Override to update `modified_at` on the related AnalysisJob """
        super(AnalysisJobStatusUpdate, self).save(*args, **kwargs)
        # The modified_at field is auto_now=True, so just saving updates it
        self.job.save()


class AnalysisScoreMetadata(models.Model):
    """ Used to hold metadata for each of the scores saved in AnalysisJob.overall_scores

    The unique name field here is matched against the top-level keys in the
    AnalysisJob.overall_scores field so that we only have to store score metadata in one place

    """
    name = models.CharField(max_length=128, primary_key=True)
    label = models.CharField(max_length=256, blank=True, null=True,
                             help_text='Short descriptive name')
    category = models.CharField(max_length=128, blank=True, null=True,
                                help_text='Used to group scores with the same category together')
    description = models.CharField(max_length=1024, blank=True, null=True,
                                   help_text='Long description of the metric')
    priority = models.PositiveSmallIntegerField(blank=True, null=True,
                                                help_text='Determines sort order in response, ' +
                                                          'lower numbers sort first')

    class Meta:
        ordering = ('name',)


class AnalysisLocalUploadTask(PFBModel):

    # Front-end expects upload task status choicees to be a subest of analysis job statuses
    class Status:
        CREATED = 'CREATED'
        QUEUED = 'QUEUED'
        IMPORTING = 'IMPORTING'
        COMPLETE = 'COMPLETE'
        ERROR = 'ERROR'

        CHOICES = (
            (CREATED, 'Created',),
            (QUEUED, 'Queued',),
            (IMPORTING, 'Importing',),
            (COMPLETE, 'Complete',),
            (ERROR, 'Error',),
        )

    status = models.CharField(max_length=16, choices=Status.CHOICES, default=Status.CREATED)
    error = models.CharField(max_length=8192, blank=True, null=True)
    job = models.OneToOneField(AnalysisJob, related_name='local_upload_task',
                               on_delete=models.CASCADE)
    upload_results_url = models.URLField(max_length=8192)
