#!/usr/bin/env python3

"""
Accepts a polygon shapefile and finds the SRID for the UTM zone
Based on https://github.com/jbranigan/geo-scripts-python/blob/master/latlng2utm/detect-utm-zone.py
"""
from __future__ import print_function
from __future__ import division

import argparse
import math
from osgeo import ogr, osr
import sys


def check_latlng(check_bbox):
    """ Checks to see if the file coordinates are in lat/lng """
    for i in check_bbox:
        if i < -180 or i > 180:
            failure('This file is already projected.')
    return True


def check_width(check_bbox):
    """ Checks to see if the bounding box fits in a UTM zone """
    wide = check_bbox[1] - check_bbox[0]
    if wide > 3:
        failure('This file is too many degrees wide for UTM')
    return True


def get_zone(coord):
    """ Finds the UTM zone of a WGS84 coordinate """
    # There are 60 longitudinal projection zones numbered 1 to 60 starting at 180W
    # So that's -180 = 1, -174 = 2, -168 = 3
    zone = ((coord - -180) / 6.0)
    return int(math.ceil(zone))


def get_bbox(shapefile):
    """ Gets the bounding box of a shapefile in EPSG 4326.
        If shapefile is not in WGS84, bounds are reprojected.
    """
    driver = ogr.GetDriverByName('ESRI Shapefile')
    # 0 means read, 1 means write
    data_source = driver.Open(shapefile, 0)
    # Check to see if shapefile is found.
    if data_source is None:
        failure('Could not open %s' % (shapefile))
    else:
        layer = data_source.GetLayer()
        shape_bbox = layer.GetExtent()

        spatialRef = layer.GetSpatialRef()
        target = osr.SpatialReference()
        target.ImportFromEPSG(4326)

        # this check for non-WGS84 projections gets some false positives, but that's okay
        if target.ExportToProj4() != spatialRef.ExportToProj4():
            transform = osr.CoordinateTransformation(spatialRef, target)
            point1 = ogr.Geometry(ogr.wkbPoint)
            point1.AddPoint(shape_bbox[0], shape_bbox[2])
            point2 = ogr.Geometry(ogr.wkbPoint)
            point2.AddPoint(shape_bbox[1], shape_bbox[3])
            point1.Transform(transform)
            point2.Transform(transform)
            shape_bbox = [point1.GetX(), point2.GetX(), point1.GetY(), point2.GetY()]

        return shape_bbox


def failure(why):
    """ Quits the script with an exit message """
    print(why)
    sys.exit(1)


def get_srid(filename):
    bbox = get_bbox(filename)
    check_latlng(bbox)
    check_width(bbox)

    avg_longitude = ((bbox[1] - bbox[0]) / 2) + bbox[0]
    utm_zone = get_zone(avg_longitude)

    avg_latitude = ((bbox[3] - bbox[2]) / 2) + bbox[2]

    # convert UTM zone to SRID
    # SRID for a given UTM ZONE: 32[6 if N|7 if S]<zone>
    srid = '32'
    if avg_latitude < 0:
        srid += '7'
    else:
        srid += '6'

    srid += '%02d' % utm_zone
    print(srid)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("filename", help="the path to the input shapefile")
    args = parser.parse_args()

    get_srid(args.filename)


main()
