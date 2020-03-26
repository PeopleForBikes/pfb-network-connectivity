#!/usr/bin/env python3

"""
A script to cache Geofabrik OSM extracts on S3 to avoid downloading the same file repeatedly.

Given a local directory, a state, and an S3 bucket, it
- Checks the bucket for a lockfile for the state and, if there is one, waits for it to disappear.
- Tries to download the OSM file for the state from the S3 bucket.
- If it's not there, downloads the file from Geofabrik and uploads it to the bucket, writing then
  clearing a lockfile to prevent other jobs from trying to do it at the same time.
"""
from __future__ import print_function
from builtins import str
from builtins import range

import argparse
import datetime
import logging
import os
import sys
from time import sleep

import boto3
from botocore.exceptions import ProfileNotFound
import requests
import us


logging.basicConfig(
    stream=sys.stderr,
    format='{} %(asctime)s %(levelname)-8s %(message)s'.format(os.path.basename(__file__)),
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__file__)

GEOFABRIK_URL_TEMPLATE = "http://download.geofabrik.de/north-america/us/{}-latest.osm.pbf"
S3_KEY_TEMPLATE = "osm-data-cache/{}"
LOCKFILE_POLLING_INTERVAL = 60  # in seconds. File size ranges from 8.8MB (RI) to 822MB (CA)
LOCKFILE_POLLING_ATTEMPTS = 21  # One is immediate, so total timeout is interval * (attempts - 1)

try:
    S3_CLIENT = boto3.client('s3')
except ProfileNotFound as e:
    S3_CLIENT = None


def compose_lockfile_key(state_abbrev):
    return S3_KEY_TEMPLATE.format('{}.lock'.format(state_abbrev))


def read_from_s3(bucket, key):
    try:
        # botocore.response.StreamingBody.read() returns a bytestring, so it needs decoding
        # to make it a proper Python 3 string
        return S3_CLIENT.get_object(Bucket=bucket, Key=key)['Body'].read().decode('utf-8')
    except S3_CLIENT.exceptions.NoSuchKey:
        return None


def write_to_s3(bucket, key, content):
    return S3_CLIENT.put_object(Bucket=bucket, Key=key, Body=content)


def delete_from_s3(bucket, key):
    S3_CLIENT.delete_object(Bucket=bucket, Key=key)


def wait_for_lockfile(bucket, state_abbrev):
    """
    Checks for a lockfile for the given state and, if there is one, waits until it's gone.
    If it doesn't disappear within the allotted time, assume something went wrong and bail out.
    """
    logger.debug('Checking for OSM extract lockfile for {}'.format(state_abbrev))
    key = compose_lockfile_key(state_abbrev)
    for attempt in range(LOCKFILE_POLLING_ATTEMPTS):
        if read_from_s3(bucket, key) is None:
            return None
        logger.info('Lockfile exists for {}, waiting'.format(state_abbrev))
        sleep(LOCKFILE_POLLING_INTERVAL)
    total_time = LOCKFILE_POLLING_INTERVAL * (LOCKFILE_POLLING_ATTEMPTS - 1) / 60
    raise Exception('Lockfile for {} not deleted after {} minutes'.format(state_abbrev, total_time))


def get_lockfile(bucket, state_abbrev):
    """Try to get the lockfile for the OSM extract for this state.

    Writes the .lock file for this state, using a unique string as the contents of the file,
    then waits 30 seconds and checks if it's still the same as what we wrote.
    If it changed, that means another job started moments after this one, so we should
    let that job do the download and get the file once it finishes.
    If the lockfile hasn't changed in 30 seconds, we can be confident that this job has the lock.
    """
    logger.debug('Trying to acquire download lock for {}'.format(state_abbrev))
    key = compose_lockfile_key(state_abbrev)
    lockfile_content = '{} {}'.format(os.getpid(), datetime.datetime.now())
    try:
        write_to_s3(bucket, key, lockfile_content)
        # The likely race condition window is probably <2 seconds, but caution doesn't hurt
        sleep(30)
        if read_from_s3(bucket, key) == lockfile_content:
            return key
        else:
            logger.info('Another job got the download lock for {}'.format(state_abbrev))
            return None
    except:
        # If something goes wrong, we want to clear the lockfile rather than leave it.
        # There's a chance that would mean we're clearing another job's lockfile, but the
        # consequences of that are less bad than the consequences of an orphaned lockfile.
        delete_from_s3(bucket, key)
        raise


def local_filepath_for_state(local_dir, state_abbrev):
    return os.path.join(local_dir, '{}.osm.pbf'.format(state_abbrev))


def download_from_geofabrik(local_dir, state_abbrev):
    # Use state level extracts available at:
    #   http://download.geofabrik.de/north-america.html
    # We have to process the neighborhood state abbrev to a full name in format found in the url
    logger.info('Downloading OSM extract from Geofabrik for {}'.format(state_abbrev))
    state_name = us.states.lookup(state_abbrev).name.lower().replace(' ', '-')
    osm_extract_url = GEOFABRIK_URL_TEMPLATE.format(state_name)
    filepath = local_filepath_for_state(local_dir, state_abbrev)
    with requests.get(osm_extract_url, allow_redirects=True) as resp:
        with open(filepath, 'wb') as local_file:
            local_file.write(resp.content)
    return filepath


def upload_to_s3(filepath, bucket):
    filename = os.path.basename(filepath)
    logger.info('Uploading OSM extract {} to S3'.format(filename))
    key = S3_KEY_TEMPLATE.format(filename)
    boto3.s3.transfer.S3Transfer(S3_CLIENT).upload_file(filepath, bucket, key)


def download_from_s3(local_dir, state_abbrev, bucket):
    """
    Download the state's extract file from S3, returning the file path if successful or None if not.
    """
    logger.debug('Looking for OSM extract on S3 for {}'.format(state_abbrev))
    filepath = local_filepath_for_state(local_dir, state_abbrev)
    key = S3_KEY_TEMPLATE.format(os.path.basename(filepath))
    try:
        boto3.s3.transfer.S3Transfer(S3_CLIENT).download_file(bucket, key, filepath)
        logger.info('Downloaded OSM extract from S3 for {}'.format(state_abbrev))
        return filepath
    except S3_CLIENT.exceptions.ClientError:
        return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("local_dir", help="The directory to put downloaded OSM extract files in")
    parser.add_argument("state_abbrev", help="state abbreviation")
    parser.add_argument("--storage_bucket", default=None, help="S3 storage bucket")
    parser.add_argument('--verbose', '-v', action="store_true")
    args = parser.parse_args()

    local_dir = args.local_dir
    bucket = args.storage_bucket
    state_abbrev = args.state_abbrev.lower()
    if args.verbose:
        logger.setLevel('DEBUG')
    else:
        logger.setLevel('INFO')

    # Shortcut and do a direct geofabrik download if we don't have AWS configured
    # or a bucket provided
    if S3_CLIENT is None or bucket is None:
        logger.debug('Shortcut direct Geofabrik download: S3_CLIENT={}, bucket={}'
                     .format(str(S3_CLIENT), bucket))
        osm_extract_filepath = download_from_geofabrik(local_dir, state_abbrev)
        print(osm_extract_filepath)
        return

    # First try to download the file, since that's all we ultimately want to accomplish
    osm_extract_filepath = download_from_s3(local_dir, state_abbrev, bucket)
    # If the file isn't there already, do the lockfile/download/upload thing
    while osm_extract_filepath is None:
        # If lockfile exists, wait for it.
        # Returns immediately if there's no lockfile.
        # Raises an exception if there is one and it doesn't disappear as expected.
        wait_for_lockfile(bucket, state_abbrev)

        # Try to download the file from S3
        osm_extract_filepath = download_from_s3(local_dir, state_abbrev, bucket)
        # If it's not there, we need to download it from Geofabrik and upload it to S3
        if osm_extract_filepath is None:
            # Get the lockfile for this state
            lockfile_key = get_lockfile(bucket, state_abbrev)

            # If we fail to get the lockfile that means there was a race condition and the other
            # job won. Go back to the top of the loop and wait for the lockfile to disappear.
            if lockfile_key is None:
                continue

            try:
                osm_extract_filepath = download_from_geofabrik(local_dir, state_abbrev)
                upload_to_s3(osm_extract_filepath, bucket)
            finally:
                # If we have the lock, we want to make sure we release it even on error
                delete_from_s3(bucket, lockfile_key)

    print(osm_extract_filepath)


main()
