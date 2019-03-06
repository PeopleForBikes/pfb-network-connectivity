# Running the Analysis Locally

## Setup

All commands should be run inside the VM from the `/vagrant/` directory. To SSH into the VM,
run `vagrant ssh` from the project directory on your host machine.

The container is built by `scripts/update`, but can also be rebuilt separately by running:
```
docker-compose build analysis
```

## Example

Running a bike network analysis requires a few inputs. At a minimum, you'll need to provide:

- The directory you want to output results to
- The boundary for the area you want to run the analysis for, as a zipped shapefile
- The [state abbreviation and FIPS code](https://www.mcc.co.mercer.pa.us/dps/state_fips_code_listing.htm) for the state that the boundary area is in

Once, you've prepared the above information, you can run a local analysis using the
following general form:
```
NB_OUTPUT_DIR=/data/path/to/results/folder \
    ./scripts/run-local-analysis \
    https://example.com/path/to/shapefile.zip <state_abbrev> <state_fips_code>
```

**Note:** All paths provided to this script should be paths valid within the analysis container.
The folder `./data` is mounted into the container at `/data`. So, for example, if you wanted your
results to be available at `./data/outputs/test-run-one` on your host machine, relative to this folder,
you'd set `NB_OUTPUT_DIR=/data/outputs/test-run-one`.

There are many other parameters available to this script that can be provided as environment
variables. See [Analysis Parameters](#analysis-parameters) for a few common ones, or run
`./scripts/run-local-analysis --help` to see all available options.

Given the above, you could run an analysis for Boulder, CO with:
```
NB_OUTPUT_DIR=/data/output/boulder \
    ./scripts/run-local-analysis \
    https://s3.amazonaws.com/test-pfb-inputs/boulder/boulder.zip co 08
```

This will take up to an hour, so just let it work.

### Using local files

The analysis can also get its input data from local files.  To run the analysis using the
same Boulder boundary and a pre-downloaded OSM file, download
[the zipped shapefile](https://s3.amazonaws.com/test-pfb-inputs/boulder/boulder.zip)
and extract it to `./data/`.
Also download [the OSM file](https://s3.amazonaws.com/test-pfb-inputs/boulder/boulder.osm.zip)
and extract it into `./data/`.

Then run:
```
NB_OUTPUT_DIR=/data/output/boulder-local-osm PFB_OSM_FILE=/data/boulder.osm \
    ./scripts/run-local-analysis /data/boulder.shp co 08
```

## Analysis parameters

See the usage message of `scripts/run-local-analysis` for all options and defaults, but
here's a table of the environment variables that can be set to affect the analyis:

| Variable | Purpose | Default value |
| -------- | ------- | ------------- |
| NB_INPUT_SRID | SRID of the input shapefile | 4326 |
| NB_MAX_TRIP_DISTANCE | The maximum trip distance (in meters) considered in the connectivity calculations. | 2680 |
| NB_BOUNDARY_BUFFER | The distance (in meters) beyond the edge of the boundary given by the shapefile to include in the imported geographic data. | 1/2 * NB_MAX_TRIP_DISTANCE |
| PFB_OSM_FILE | An exported OSM file to use instead of downloading current OSM data during the analysis | |
| PFB_OSM_FILE_URL | A URL from which a zipped .osm file can be downloaded. Overrides PFB_OSM_FILE. If this is also left unset, the analysis will automatically pull the latest state OSM file from Geofabrik. | none |
| NB_OUTPUT_DIR | The path, within the analysis container, to write results to. The directory will be created (if possible) if it doesn't exist. | /data/output |
| AWS_STORAGE_BUCKET_NAME | The S3 bucket to upload results to. Requires `AWS_PROFILE` be set. | {DEV_USER}-pfb-storage-us-east-1 |
| AWS_PROFILE | The name of the AWS profile, configured in `~/.aws` to use for uploading to S3. This can also be left unset, and the analysis run will ignore attempts to interface with AWS if no valid profile + credentials are found. | pfb |
| PFB_JOB_ID | The job ID of an AnalysisJob triggered from Django. This should be left unset if you're running local jobs not managed by the Django dev stack. | '' |

## Targeting a remote database

`./scripts/run-local-analysis` supports running the analysis against a remote PostgreSQL database
cluster, as long as the appropriate requirements are satisified. It is up to the user to ensure
that this is the case.

If the requirements below are satisified, a bike network analysis can be run against the remote DB
using the `NB_POSTGRESQL_*` variables documented in `./scripts/run-local-analysis`. For example:
```
NB_OUTPUT_DIR=/data/output/germantown-remote-db \
NB_POSTGRESQL_DB=remote_db_name \
NB_POSTGRESQL_HOST=remote_db_host \
NB_POSTGRESQL_USER=remote_db_user \
NB_POSTGRESQL_PASSWORD=remote_db_password \
    ./scripts/run-local-analysis \
    'https://s3.amazonaws.com/test-pfb-inputs/germantown/gtown_westside.zip' PA 42
```

### Requirements

- PostgreSQL 9.6+
- PostGIS 2.3+
- Extensions installed:
  - [PostGIS](http://postgis.net/)
  - [pgRouting](http://pgrouting.org/)
  - [quantile](https://github.com/tvondra/quantile)
  - uuid-ossp
  - hstore
  - plpythonu
- Schemas created in NB_POSTGRESQL_DB with permission for NB_POSTGRESQL_USER to use them.
  In addition, these schemas must be added to the user's `search_path`:
  - `CREATE SCHEMA IF NOT EXISTS generated AUTHORIZATION ${NB_POSTGRESQL_USER};`
  - `CREATE SCHEMA IF NOT EXISTS received AUTHORIZATION ${NB_POSTGRESQL_USER};`
  - `CREATE SCHEMA IF NOT EXISTS scratch AUTHORIZATION ${NB_POSTGRESQL_USER};`
  - `ALTER USER ${NB_POSTGRESQL_USER} SET search_path TO generated,received,scratch,"\$user",public;`

## Running sample neighborhoods

Azavea/PFB created a few sample OSM and boundary files that can be used for testing.

The following input files are also available at https://s3.amazonaws.com/test-pfb-inputs/.

Use the default for any individual parameter, unless otherwise specified.

### Cambridge, MA

- Shapefile: https://s3.amazonaws.com/test-pfb-inputs/cambridge/neighborhood_boundary_02138.zip
- OSM files: https://s3.amazonaws.com/test-pfb-inputs/cambridge/cambridge.osm.zip
- FIPS code: 25
- set `NB_INPUT_SRID=2249`

```
NB_OUTPUT_DIR=/data/output/cambridge \
NB_INPUT_SRID=2249 \
PFB_OSM_FILE_URL=https://s3.amazonaws.com/test-pfb-inputs/cambridge/cambridge.osm.zip \
    ./scripts/run-local-analysis \
    https://s3.amazonaws.com/test-pfb-inputs/cambridge/neighborhood_boundary_02138.zip ma 25
```

## Germantown neighborhood, Philadelphia, PA

- Shapefile: https://s3.amazonaws.com/test-pfb-inputs/germantown/gtown_westside.zip
- OSM file: https://s3.amazonaws.com/test-pfb-inputs/germantown/gtown_westside.osm.zip
- FIPS code: 42
- A very small area, great for quick tests of the analysis pipeline

### Center City Philadelphia, PA

- Shapefile: https://s3.amazonaws.com/test-pfb-inputs/philly/philly.zip
- OSM file: https://s3.amazonaws.com/test-pfb-inputs/philly/philly.osm.zip
- FIPS code: 42

### Lower Manhattan, NY

- Shapefile: https://s3.amazonaws.com/test-pfb-inputs/lowermanhattan/lowermanhattan.zip
- OSM file: https://s3.amazonaws.com/test-pfb-inputs/lowermanhattan/lowermanhattan.osm.zip
- FIPS code: 36
- A large network.  Analysis is lengthy and resource-intensive.

## Cleaning up old analysis runs

Each analysis run takes up a significant amount of limited VM disk space. To clear old analysis volumes once finished with them, run:
```
./scripts/clean-analysis-volumes
```

## Importing local analysis results into the BNA site

The results of analysis jobs run locally can be imported and displayed on the [BNA site](https://bna.peopleforbikes.org/).

To do so, first [create a Neighborhood](https://bna.peopleforbikes.org/#/admin/neighborhoods/create/)
(if it doesn't already exist on the site) using the boundary shapefile you used for the analysis.
Then go to the ["Import Analysis Results" page](https://bna.peopleforbikes.org/#/admin/analysis-jobs/import/),
select the neighborhood, and provide a URL to a zip file containing the local analysis results.

The results zip file should contain all the files saved by the analysis.  For a local analysis run,
that will be the contents of the directory set as `NB_OUTPUT_DIR` for the analysis.  For a job run
remotely, the files can be downloaded from the "Data" section of the job details page or from the
`results/JOB_ID/` folder in the site's results S3 bucket.  The zip file should contain only the
files, with no internal directory structure.  Since the resulting file is too large to be uploaded
and processed within a single request/response cycle, it must be provided via URL.  The [results
storage bucket on S3](https://s3.amazonaws.com/production-pfb-storage-us-east-1/) is set up to be
publicly accessible via URL, so uploading the zipped results to a folder within that bucket works well.

When an import request is submitted, the server creates a new analysis job instance then downloads
the results and attaches them to the job.  This process takes less than a minute, and can be monitored
on the Analysis Job detail page, where it will initially show "status: CREATED" and "local upload task
status: IMPORTING".  When both statuses have changed to "COMPLETE", the import is finished and the
analysis results will appear on the site.

If the import fails, for example due to a file being missing from the results .zip, the statuses
will change to "ERROR" and the "local upload task error" field will provide more details.
