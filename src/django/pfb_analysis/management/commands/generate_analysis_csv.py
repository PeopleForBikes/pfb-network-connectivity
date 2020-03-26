from builtins import str
from builtins import zip
import csv
from datetime import datetime
import logging
import os
import shutil
import tempfile

import boto3

from django.conf import settings
from django.core.management.base import BaseCommand

from pfb_analysis.filters import AnalysisJobFilterSet
from pfb_analysis.models import AnalysisJob, AnalysisScoreMetadata

logger = logging.getLogger(__name__)


def get_overall_scores_value(job, key, default=''):
    try:
        return job.overall_scores[key]['score_normalized']
    except KeyError:
        logger.warning('Job {} overall_scores missing key: {}'.format(str(job.uuid), key))
        return default


def export_job_details(job):
    return (['neighborhood_uuid', 'neighborhood_name', 'neighborhood_state', 'job_uuid'],
            [
                str(job.neighborhood.uuid),
                job.neighborhood.label,
                job.neighborhood.state_abbrev,
                str(job.uuid)
            ],)


def export_connectivity_metrics(job):
    columns = []
    values = []
    # Iterate over AnalysisScoreMetadata so we can control the output order
    for score in AnalysisScoreMetadata.objects.exclude(pk='population_total').order_by('priority'):
        columns.append(score.name)
        values.append(get_overall_scores_value(job, score.name))

    return (columns, values,)


def export_mileage_low_stress(job):
    value = get_overall_scores_value(job, 'total_miles_low_stress')
    return (['total_low_stress_miles'], [value],)


def export_mileage_high_stress(job):
    value = get_overall_scores_value(job, 'total_miles_high_stress')
    return (['total_high_stress_miles'], [value],)


def export_total_population(job):
    return (['total_population'], [job.population_total],)


def export_boundary_area(job):
    MILES_PER_METER = 0.000621371
    return (['neighborhood_area_m2'],
            [job.neighborhood.geom_utm.area * MILES_PER_METER * MILES_PER_METER],)


def export_bna_site_url(job):
    url = 'https://bna.peopleforbikes.org/#/places/{}/'.format(str(job.neighborhood.uuid))
    return (['bna_site_url'], [url],)


EXPORTS = [
    export_job_details,
    export_connectivity_metrics,
    export_mileage_high_stress,
    export_mileage_low_stress,
    export_total_population,
    export_boundary_area,
    export_bna_site_url,
]


class Command(BaseCommand):
    help = """ Generate a CSV summary of AnalysisJob results and push to AWS S3

    Generates a row in the CSV for each Neighborhood whose last job has status=COMPLETE

    CSV contains the following metrics:
    - Overall score
    - Each connectivity metric
    - Mileage of low-stress segments
    - Mileage of high-stress segments
    - Neighborhood total population
    - Neighborhood boundary land area in square meters

    """

    def add_arguments(self, parser):
        pass

    def handle(self, *args, **options):

        tmpdir = tempfile.mkdtemp()

        try:
            queryset = AnalysisJob.objects.all().filter(status=AnalysisJob.Status.COMPLETE)
            filter_set = AnalysisJobFilterSet()
            queryset = filter_set.filter_latest(queryset, 'latest', True)

            tmp_csv_filename = os.path.join(tmpdir, 'results.csv')
            with open(tmp_csv_filename, 'w') as csv_file:
                writer = None
                fieldnames = []

                for job in queryset:
                    row_data = {}
                    for export in EXPORTS:
                        columns, values = export(job)
                        if writer is None:
                            fieldnames = fieldnames + columns
                        for column, value in zip(columns, values):
                            row_data[column] = value
                    if writer is None:
                        writer = csv.DictWriter(csv_file,
                                                fieldnames=fieldnames,
                                                dialect=csv.excel,
                                                quoting=csv.QUOTE_MINIMAL)
                        writer.writeheader()
                    writer.writerow(row_data)

            s3_client = boto3.client('s3')
            now = datetime.utcnow()
            s3_key = 'analysis-spreadsheets/results-{}.csv'.format(now.strftime('%Y-%m-%dT%H%M'))
            s3_client.upload_file(tmp_csv_filename, settings.AWS_STORAGE_BUCKET_NAME, s3_key)
            logger.info('File uploaded to: s3://{}/{}'
                        .format(settings.AWS_STORAGE_BUCKET_NAME, s3_key))
        finally:
            shutil.rmtree(tmpdir)
