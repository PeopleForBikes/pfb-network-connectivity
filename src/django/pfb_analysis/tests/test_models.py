from __future__ import division
import logging
import os

from django.contrib.gis.gdal import DataSource
from django.contrib.gis.geos import LineString
from django.test import override_settings, SimpleTestCase, TestCase

from pfb_analysis.models import (
    simplify_geom,
    AnalysisBatch,
    AnalysisJob,
    SIMPLIFICATION_MIN_VALID_AREA_RATIO,
)
from users.models import PFBUser

logger = logging.getLogger(__name__)

TESTDATA_PATH = os.path.join(os.path.dirname(__file__), 'data')


class SimplifyGeomTestCase(SimpleTestCase):

    def _test_simplify_geom_from_shpfile(self, shpfile_name):
        ds = DataSource(shpfile_name)
        self.assertEqual(len(ds), 1)
        layer = ds[0]
        self.assertEqual(len(layer), 1)
        geom = layer[0].geom.geos
        self._test_simplify_geom(geom)

    def _test_simplify_geom(self, geom):
        simple = simplify_geom(geom)
        self.assertLess(simple.num_coords, geom.num_coords)
        self.assertGreater(simple.area / geom.area, SIMPLIFICATION_MIN_VALID_AREA_RATIO)

    def test_polygon_geom_simplify_tolerance_more(self):
        """This tests a basic boundary, with a single, simple polygon.

        It should simplify ok using the first MORE tolerance and not require preserve_topology.

        """
        shpfile_name = os.path.join(TESTDATA_PATH, 'birmingham', 'birmingham.shp')
        self._test_simplify_geom_from_shpfile(shpfile_name)

    def test_polygon_geom_simplify_requires_preserve_topology(self):
        """This tests a more complex boundary, with a single, simple multi polygon.

        This is a multipolygon, where one polygon is much smaller than the other, which
        breaks our simplification tolerances and thus should require preserve_topology.

        """
        shpfile_name = os.path.join(TESTDATA_PATH, 'ann-arbor-mi', 'ann-arbor-mi.shp')
        self._test_simplify_geom_from_shpfile(shpfile_name)

    def test_not_a_polygon(self):
        geom = LineString(((0, 0), (1, 1)), srid=4326)
        self.assertEqual(geom, simplify_geom(geom))


@override_settings(DEFAULT_FILE_STORAGE='django.core.files.storage.FileSystemStorage')
class AnalysisBatchCreateFromShapefileTestCase(TestCase):

    def setUp(self):
        self.shapefile_path = os.path.join(TESTDATA_PATH,
                                           'batch_create_shapefile',
                                           'PFB_BigJumpCities_1.shp')
        self.shapefile_zip_path = os.path.join(TESTDATA_PATH,
                                               'batch_create_shapefile',
                                               'PFB_BigJumpCities_1.zip')

    def test_create_from_shapefile_path(self):
        batch = AnalysisBatch.objects.create_from_shapefile(self.shapefile_path)
        self.assertEqual(batch.jobs.count(), 6)

    def test_create_from_shapefile_http(self):
        url = 'https://s3.amazonaws.com/pfb-batch-run-inputs-us-east-1/PFB_BigJumpCities_1.zip'
        batch = AnalysisBatch.objects.create_from_shapefile(url)
        self.assertEqual(batch.jobs.count(), 6)

    def test_create_from_shapefile_zip(self):
        batch = AnalysisBatch.objects.create_from_shapefile(self.shapefile_zip_path)
        self.assertEqual(batch.jobs.count(), 6)

    def test_create_from_shapefile_no_submit(self):
        batch = AnalysisBatch.objects.create_from_shapefile(self.shapefile_path)
        self.assertEqual(batch.jobs.filter(status=AnalysisJob.Status.CREATED).count(), 6)

    def test_create_from_shapefile_submit(self):
        batch = AnalysisBatch.objects.create_from_shapefile(self.shapefile_path, submit=True)
        self.assertEqual(batch.jobs.filter(status=AnalysisJob.Status.QUEUED).count(), 6)

    def test_create_from_shapefile_with_user(self):
        root_user = PFBUser.objects.get_root_user()
        user = PFBUser.objects.create(email='user@peopleforbikes.org',
                                      organization=root_user.organization,
                                      created_by=root_user,
                                      modified_by=root_user)
        batch = AnalysisBatch.objects.create_from_shapefile(self.shapefile_path, user=user)
        self.assertEqual(batch.created_by.pk, user.pk)
        self.assertEqual(batch.modified_by.pk, user.pk)
