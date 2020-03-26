# pfb

## Docker

To run the analysis in docker, first build the docker image.

From the `src` folder, run
```bash
docker build -t pfb -f analysis/Dockerfile .
```

Then run the analysis as follows:

```bash
docker run \
    -e PFB_SHPFILE=/data/neighborhood_boundary.shp \
    -e PFB_STATE=ma \
    -e PFB_STATE_FIPS=25 \
    -e NB_INPUT_SRID=2249 \
    -e NB_BOUNDARY_BUFFER=11000 \
    -v /vagrant/data/:/data/ \
    pfb
```

The `-e` in this example sets environment variables, which will depend on the
analysis you are running.

The `-v` in this example mounts a local directory inside the docker container
under `/data/`. The `PFB_SHPFILE` environment variable specifies the `.shp`
file under this directory to use.

This process of mounting a data directory with the input shapefile will be
removed in favor of an import process.
