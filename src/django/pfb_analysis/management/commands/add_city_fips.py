from django.core.management.base import BaseCommand

import csv
import logging
import os
import sys

import boto3
from botocore.exceptions import ClientError
import fiona
from fiona.crs import from_epsg

logger = logging.getLogger(__name__)

FIPS_CSV = 'national_places.csv'
# local path to cached FIPS CSV
FIPS_PATH = '/data/{csv}'.format(csv=FIPS_CSV)
# S3 bucket where FIPS CSV should exist
FIPS_BUCKET = 'pfb-public-documents'


def add_city_fips(input_path, output_path, fips_csv):
    logger.info("""Writing city FIPS Shapefile for {input}
                to {output} using FIPS from {fips}""".format(input=input_path,
                                                             output=output_path,
                                                             fips=fips_csv))
    # ensure Unicode will be handled properly
    reload(sys)
    sys.setdefaultencoding('utf8')

    # map states to place names and their FIPS, for fast lookup
    lookup = {}
    with open(FIPS_PATH) as inf:
        rdr = csv.DictReader(inf)
        for place in rdr:
            fips = '{state}{place}'.format(state=place['STATEFP'], place=place['PLACEFP'])
            if not (place['STATE']) in lookup:
                lookup[place['STATE']] = {place['PLACENAME'].upper(): fips}
            else:
                lookup[place['STATE']][place['PLACENAME'].upper()] = fips

    with fiona.open(input_path) as shp:
        schema = shp.schema.copy()
        # CRS not set on input, so explicitly set it here
        crs = from_epsg(4326)
        # Add field to Shapefile properties
        schema['properties']['city_fips'] = 'str:7'
        with fiona.open(output_path, 'w', driver='ESRI Shapefile',
                        schema=schema, crs=crs) as outshp:
            place_count = len(shp)
            found = 0
            for feature in shp:
                prop = feature.get('properties')
                city = prop['city'].upper()
                state_places = list(lookup.get(prop['state']).keys())
                found_fips = None
                if state_places:
                    for place in state_places:
                        if place.find(city) == 0:
                            fips = lookup[prop['state']][place]
                            logger.info("Found place {place} for {city} in {state} "
                                        "with FIPS {fips}".format(place=place, city=city,
                                                                  state=prop['state'], fips=fips))
                            if found_fips:
                                if found_fips != fips:
                                    logger.warning("""FIPS mismatch. Expected: {fips}
                                        Got: {found} for {place}, {state}""".format(
                                        fips=fips, found=found_fips, place=place,
                                        state=prop['state']))
                            found_fips = fips
                if not found_fips:
                    logger.warning('Could not find FIPS for {city}, {state}'.format(city=city,
                                state=prop['state']))
                else:
                    found += 1

                # write feature with city FIPS to new output file
                feature['properties']['city_fips'] = found_fips
                outshp.write(feature)

            logger.info('Done writing city FIPS Shapefile to {o}'.format(o=output_path))

    logger.info('Found {found} out of {places} places.'.format(found=found,
                                                               places=place_count,
                                                               output=output_path))


def has_extension(pathname, extension):
    """Return true if file at given pathname has the given case-insensitive extension."""
    return pathname and pathname.lower().endswith(extension.lower())


def get_fips_csv():
    """Return path to CSV of place FIPS in project data directory.

    Download CSV from S3 and put it in the data directory if it is not already there.
    """
    if os.path.isfile(FIPS_PATH):
        logger.info('Using FIPS CSV found in data directory')
    else:
        logger.info('Downloading FIPS CSV from S3 into data directory')
        try:
            s3_client = boto3.client('s3')
            s3_client.download_file(FIPS_BUCKET, FIPS_CSV, FIPS_PATH)
        except ClientError as ex:
            logger.exception('Failed to download FIPS CSV {fips} from S3 bucket {bucket}.'.format(
                fips=FIPS_CSV, bucket=FIPS_BUCKET))
            raise ex
    return FIPS_PATH


class Command(BaseCommand):
    help = """Add the Census FIPS to each place in a batch analysis Shapefile.

    Output file defaults to <input file name>_city_fips.shp, in the same directory as the input.
    """

    def add_arguments(self, parser):
        parser.add_argument('-i', '--input',
                            help='Input batch analysis Shapefile. Should end with .shp')
        parser.add_argument('-o', '--output', nargs='?',
                            help='Output batch analysis Shapefile name. Should end with .shp')
        parser.add_argument('-f', '--fips-csv', nargs='?',
                            help="""CSV containing Census place FIPS. Defaults to pull from project
                            data directory if not defined, or from S3 if not already in /data.""")

    def handle(self, *args, **options):
        input_path = options['input']
        output_path = options['output']
        fips_csv = options['fips_csv']

        if not has_extension(input_path, '.shp'):
            raise ValueError('Expected input Shapefile name to end with .shp')
        elif not os.path.isfile(input_path):
            raise ValueError('Could not find input Shapefile at {input}'.format(input=input_path))
        if not output_path:
            input_basename = input_path.replace('.shp', '').replace('.SHP', '')
            output_path = ('{basename}_city_fips.shp').format(basename=input_basename)
        elif not has_extension(output_path, '.shp'):
            raise ValueError('Expected output Shapefile name to end with .shp')
        if not fips_csv:
            fips_csv = get_fips_csv()
        if not os.path.isfile(fips_csv):
            raise ValueError('Could not find FIPS CSV file at {fips}'.format(fips=fips_csv))
        elif not has_extension(fips_csv, '.csv'):
            raise ValueError('Expected FIPS CSV file name to exist and end with .csv')

        add_city_fips(input_path, output_path, fips_csv)
