<!--Note: to keep the headings readable, the version number links are defined at the bottom.-->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Upcoming release]

## [0.13.0] - 2020-02-14

#### Changed
- Upgraded Django and psycopg2 package versions and switched to psycopg2-binary
- Upgraded ansible-docker module to 5.0.0, Docker to 18.*, and Docker Compose to 1.23.*
- Fix lane handling in analysis
- Fix population scores for destinations in analysis
- Add favicon
- Increase max zoomlevel from 17 to 19

## [0.12.0] - 2019-12-30

#### Added
- A delete button for neighborhoods, with a confirmation modal
- Clean up S3 assets when deleting neighborhoods and analysis jobs
- Editing of neighborhood details and boundary
- A boundary map preview to the neighborhood editing page

#### Changed
- Fixed garbled error messages and improved error formatting

## [0.11.0] - 2019-10-31

#### Changed
- Upgraded Django app to run under Python 3
- Upgraded Django app to Django 2.2
- Upgraded osm2pgrouting and osm2pgsql and switched them to use the apt packages

## [0.10.0] - 2019-05-08

#### Added
- Places list filtering by country and state/province

#### Changed
- Updated containers based on Debian Jessie to Stretch
- Support entering state/province for non-US neighborhoods
- Default to sorting places list by name and remove order-by-state option
- Adjust label formatting to show state/province and country
- Upgraded analysis scripts to run under Python 3

## [0.9.2] - 2019-03-11

#### Changed
- Use Terraform to create and configure the Tilegarden executor role
- Show country name in neighborhood label for non-US places
- Treat US territories as states, not countries
- Add management-only deployment command for applying migrations before deployment

#### Removed
- Removed 'tilemaker' container and all code and config related to static tiling

## [0.9.1] - 2019-02-20

#### Added
- Lambda warming support for Tilegarden

#### Changed
- Replace logo and icon with new BNA ones

## [0.9.0] - 2019-02-14

#### Added
- Enable local analysis uploads
- Add support for non-US neighborhoods
- Dynamic tile server

#### Changed
- Analysis: add support for state/city speed limit defaults
- Analysis: improve handling of pedestrian paths and one-way street segments
- Update census block tile styling

## [0.8.1] - 2019-01-22

- Only import geometries for each neighborhood's latest analysis job

## [0.8.0] - 2019-01-16

- Preliminary back-end changes to enable dynamic tile server
- Preliminary back-end changes to enable local analysis uploads

## [0.7.0] - 2018-06-14

#### Added
- Async Batch job creation via Admin UI using Django Q running as an ECS task
- S3 caching for state OSM downloads from Geofabrik to reduce chance of throttling
- Google Analytics for basic site hit tracking

#### Changed
- Upgrade Django to 1.11.13 LTS
- Upgrade application third-party Django dependencies
- Improve robustness of Neighborhood boundary simplification algorithm by checking simplified
  geom area against original geom area

#### Fixed
- Improper handling of AWS_REGION variable in development environments
- Invalid string formatting of single-digit UTM zones

## [0.6.1] - 2017-08-08
## [0.6.0] - 2017-07-28
## [0.5.1] - 2017-07-24
## [0.5.0] - 2017-07-18
## [0.4.3] - 2017-06-16
## [0.4.2] - 2017-06-02
## [0.4.1] - 2017-05-25
## [0.4.0] - 2017-05-23
## [0.3.0] - 2017-05-12
## [0.2.2] - 2017-05-10
## [0.2.1] - 2017-05-10
## [0.2.0] - 2017-05-08
## [0.1.5] - 2017-04-28
## [0.1.4] - 2017-04-28
## [0.1.3] - 2017-04-27
## [0.1.2] - 2017-04-26
## [0.1.1] - 2017-04-21
## [0.1.0] - 2017-04-21


[Upcoming release]: https://github.com/azavea/pfb-network-connectivity/compare/0.13.0...HEAD
[0.13.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.12.0...0.13.0
[0.12.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.11.0...0.12.0
[0.11.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.10.0...0.11.0
[0.10.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.9.2...0.10.0
[0.9.2]: https://github.com/azavea/pfb-network-connectivity/compare/0.9.1...0.9.2
[0.9.1]: https://github.com/azavea/pfb-network-connectivity/compare/0.9.0...0.9.1
[0.9.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.8.1...0.9.0
[0.8.1]: https://github.com/azavea/pfb-network-connectivity/compare/0.8.0...0.8.1
[0.8.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.7.0...0.8.0
[0.7.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.6.1...0.7.0
[0.6.1]: https://github.com/azavea/pfb-network-connectivity/compare/0.6.0...0.6.1
[0.6.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.5.1...0.6.0
[0.5.1]: https://github.com/azavea/pfb-network-connectivity/compare/0.5.0...0.5.1
[0.5.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.4.3...0.5.0
[0.4.3]: https://github.com/azavea/pfb-network-connectivity/compare/0.4.2...0.4.3
[0.4.2]: https://github.com/azavea/pfb-network-connectivity/compare/0.4.1...0.4.2
[0.4.1]: https://github.com/azavea/pfb-network-connectivity/compare/0.4.0...0.4.1
[0.4.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.2.2...0.3.0
[0.2.2]: https://github.com/azavea/pfb-network-connectivity/compare/0.2.1...0.2.2
[0.2.1]: https://github.com/azavea/pfb-network-connectivity/compare/0.2.0...0.2.1
[0.2.0]: https://github.com/azavea/pfb-network-connectivity/compare/0.1.5...0.2.0
[0.1.5]: https://github.com/azavea/pfb-network-connectivity/compare/0.1.4...0.1.5
[0.1.4]: https://github.com/azavea/pfb-network-connectivity/compare/0.1.3...0.1.4
[0.1.3]: https://github.com/azavea/pfb-network-connectivity/compare/0.1.2...0.1.3
[0.1.2]: https://github.com/azavea/pfb-network-connectivity/compare/0.1.1...0.1.2
[0.1.1]: https://github.com/azavea/pfb-network-connectivity/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/azavea/pfb-network-connectivity/releases/tag/0.1.0
