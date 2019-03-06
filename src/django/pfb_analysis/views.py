from collections import OrderedDict
from datetime import datetime
import logging
from uuid import uuid4

from django.conf import settings
from django.contrib.auth.models import AnonymousUser
from django.db import connection, DataError
from django.utils.text import slugify

import boto3
from botocore.client import Config as BotocoreClientConfig
from django_countries import countries
from django_filters.rest_framework import DjangoFilterBackend
from django_q.tasks import async
from rest_framework import mixins, parsers, status
from rest_framework.decorators import detail_route, parser_classes
from rest_framework.exceptions import NotFound
from rest_framework.filters import OrderingFilter
from rest_framework.permissions import (AllowAny, IsAuthenticatedOrReadOnly)
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet, ReadOnlyModelViewSet, GenericViewSet, ViewSet
from rest_framework.response import Response
import us

from pfb_network_connectivity.pagination import OptionalLimitOffsetPagination
from pfb_network_connectivity.filters import OrgAutoFilterBackend
from pfb_network_connectivity.permissions import IsAdminOrgAndAdminCreateEditOnly, RestrictedCreate

from .models import (
    AnalysisJob,
    AnalysisLocalUploadTask,
    AnalysisScoreMetadata,
    Neighborhood,
    get_batch_shapefile_upload_path,
)
from .serializers import (
    AnalysisJobSerializer,
    AnalysisLocalUploadTaskCreateSerializer,
    AnalysisLocalUploadTaskSerializer,
    AnalysisScoreMetadataSerializer,
    NeighborhoodSerializer,
)
from .filters import AnalysisJobFilterSet


logger = logging.getLogger(__name__)


class AnalysisJobViewSet(ModelViewSet):
    """For listing or retrieving analysis jobs."""

    def get_queryset(self):
        queryset = AnalysisJob.objects.select_related('neighborhood').all()
        queryset = queryset.exclude(neighborhood__visibility=Neighborhood.Visibility.HIDDEN)
        if isinstance(self.request.user, AnonymousUser):
            queryset = queryset.filter(neighborhood__visibility=Neighborhood.Visibility.PUBLIC)
        return queryset

    serializer_class = AnalysisJobSerializer
    permission_classes = (RestrictedCreate, IsAuthenticatedOrReadOnly)
    filter_class = AnalysisJobFilterSet
    filter_backends = (DjangoFilterBackend, OrderingFilter, OrgAutoFilterBackend)
    ordering_fields = ('created_at', 'modified_at', 'overall_score', 'neighborhood__label',
                       'neighborhood__country', 'neighborhood__state_abbrev', 'population_total')
    ordering = ('-created_at',)

    def perform_create(self, serializer):
        """ Start analysis jobs as soon as created """
        instance = serializer.save()
        instance.run()

    @detail_route(methods=['post'])
    def cancel(self, request, pk=None):
        job = self.get_object()
        job.cancel(reason='AnalysisJob terminated via API by {} at {}'
                          .format(request.user.email, datetime.utcnow()))
        serializer = AnalysisJobSerializer(job)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @detail_route(methods=['GET'])
    def results(self, request, pk=None):
        job = self.get_object()

        if job.status == AnalysisJob.Status.COMPLETE:
            results = OrderedDict([
                ('census_block_count', job.census_block_count),
                ('census_blocks_url', job.census_blocks_url),
                ('connected_census_blocks_url', job.connected_census_blocks_url),
                ('destinations_urls', job.destinations_urls),
                ('tile_urls', job.tile_urls),
                ('overall_scores', job.overall_scores),
                ('overall_scores_url', job.overall_scores_url),
                ('score_inputs_url', job.score_inputs_url),
                ('ways_url', job.ways_url),
            ])
            return Response(results, status=status.HTTP_200_OK)
        else:
            return Response(None, status=status.HTTP_404_NOT_FOUND)


class AnalysisBatchViewSet(ViewSet):

    @parser_classes([parsers.MultiPartParser])
    def create(self, request, *args, **kwargs):
        """ Trigger a new analysis batch given a well-formatted shapefile

        Upload file to the 'file' key in a multipart form.

        Each polygon/multipolygon feature in the shapefile will have a neighborhood created
        for it if it doesn't exist, and the job for each neighborhood will immediately be submitted.

        Each feature in the shapefile should have a "city" and "state" attribute. The "city"
        attribute maps to Neighborhood.label and "state" maps to Neighborhood.state_abbrev.

        If the "city" and "state" of an uploaded feature matches an existing neighborhood,
        the existing one will be used and its geom updated with the one in the upload.

        """
        file_obj = request.data['file']

        client = boto3.client('s3', config=BotocoreClientConfig(signature_version='s3v4'))

        organization = request.user.organization
        file_name = '{}.zip'.format(str(uuid4()))
        key = get_batch_shapefile_upload_path(organization.name, file_name).lstrip('/')

        response = client.upload_fileobj(file_obj, settings.AWS_STORAGE_BUCKET_NAME, key)
        print(response)
        url = client.generate_presigned_url(
            ClientMethod='get_object',
            Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': key}
        )
        async('pfb_analysis.tasks.create_batch_from_remote_shapefile',
            url,
            group='create_analysis_batch',
            ack_failure=True)

        return Response({
            'shapefile_url': url,
            'status': 'STARTED'
        }, status=status.HTTP_200_OK)


class AnalysisScoreMetadataViewSet(ReadOnlyModelViewSet):
    """Convenience endpoint for available analysis score metadata"""

    queryset = AnalysisScoreMetadata.objects.all().order_by('priority')
    serializer_class = AnalysisScoreMetadataSerializer
    pagination_class = None
    filter_class = None
    permission_classes = (AllowAny,)


class AnalysisLocalUploadTaskViewSet(mixins.CreateModelMixin,
                                     mixins.ListModelMixin,
                                     mixins.RetrieveModelMixin,
                                     GenericViewSet):
    queryset = AnalysisLocalUploadTask.objects.all()
    pagination_class = OptionalLimitOffsetPagination
    permission_classes = (RestrictedCreate, IsAuthenticatedOrReadOnly)

    filter_fields = ('job', 'upload_results_url')
    filter_backends = (DjangoFilterBackend, OrderingFilter)
    ordering_fields = ('created_at',)

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return AnalysisLocalUploadTaskCreateSerializer
        else:
            return AnalysisLocalUploadTaskSerializer

    def perform_create(self, serializer):
        if not serializer.is_valid():
            return
        neighborhood_id = serializer.validated_data['neighborhood']
        neighborhood = Neighborhood.objects.get(pk=neighborhood_id)
        user = self.request.user
        job = AnalysisJob.objects.create(neighborhood=neighborhood,
                                         created_by=user, modified_by=user)
        obj = serializer.save(job=job, created_by=user, modified_by=user)

        async('pfb_analysis.tasks.upload_local_analysis',
            obj.uuid,
            group='import_analysis_job',
            ack_failure=True)


class NeighborhoodViewSet(ModelViewSet):
    """For listing or retrieving neighborhoods."""

    def get_queryset(self):
        queryset = Neighborhood.objects.select_related('organization').all()
        queryset = queryset.exclude(visibility=Neighborhood.Visibility.HIDDEN)
        if isinstance(self.request.user, AnonymousUser):
            queryset = queryset.filter(visibility=Neighborhood.Visibility.PUBLIC)
        return queryset

    permission_classes = (IsAdminOrgAndAdminCreateEditOnly, IsAuthenticatedOrReadOnly)
    filter_fields = ('organization', 'name', 'label', 'country', 'state_abbrev')
    filter_backends = (DjangoFilterBackend, OrderingFilter, OrgAutoFilterBackend)
    serializer_class = NeighborhoodSerializer
    pagination_class = OptionalLimitOffsetPagination
    ordering_fields = ('created_at',)

    def perform_create(self, serializer):
        if serializer.is_valid():
            serializer.save(organization=self.request.user.organization,
                            name=slugify(serializer.validated_data['label']))


class NeighborhoodBoundsGeoJsonViewList(APIView):
    """For retrieving all neighborhood bounds multipolygons as GeoJSON feature collection."""

    pagination_class = None
    filter_class = None
    permission_classes = (AllowAny,)

    def get(self, request, format=None, *args, **kwargs):
        query = """
        SELECT row_to_json(fc)
        FROM (
            SELECT 'FeatureCollection' AS type,
                array_to_json(array_agg(f)) AS features
            FROM (SELECT 'Feature' AS type,
                  ST_AsGeoJSON(g.geom_simple)::json AS geometry,
                  g.uuid AS id,
                  row_to_json((SELECT p FROM (
                    SELECT uuid AS id, name, label, country, state_abbrev, organization_id) AS p))
                    AS properties
            FROM pfb_analysis_neighborhood AS g WHERE g.visibility <> %s) AS f) AS fc;
        """

        with connection.cursor() as cursor:
            cursor.execute(query, [Neighborhood.Visibility.HIDDEN])
            json = cursor.fetchone()
            if not json or not len(json):
                return Response({})

        return Response(json[0])


class NeighborhoodBoundsGeoJsonViewDetail(APIView):
    """For retrieving a single neighborhood bound multipolygon as GeoJSON feature collection."""

    pagination_class = None
    filter_class = None
    permission_classes = (AllowAny,)

    def get(self, request, format=None, *args, **kwargs):
        query = """
        SELECT row_to_json(fc)
        FROM (
            SELECT 'FeatureCollection' AS type,
                array_to_json(array_agg(f)) AS features
            FROM (SELECT 'Feature' AS type,
                  ST_AsGeoJSON(g.geom_simple)::json AS geometry,
                  g.uuid AS id,
                  row_to_json((SELECT p FROM (
                    SELECT uuid AS id, name, label, country, state_abbrev, organization_id) AS p))
                    AS properties
            FROM pfb_analysis_neighborhood AS g WHERE g.uuid = %s) AS f) AS fc;
        """

        # get the neighborhood ID from the request
        uuid = kwargs.get('neighborhood', '')
        if not uuid:
            return Response({})

        try:
            with connection.cursor() as cursor:
                cursor.execute(query, [uuid])
                json = cursor.fetchone()
                if not json or not len(json):
                    return Response({})
        except DataError:
            raise NotFound(detail='{} is not a valid neighborhood UUID.'.format(uuid))

        return Response(json[0])


class NeighborhoodGeoJsonViewSet(APIView):
    """For retrieving all neighborhood centroids as GeoJSON feature collection."""

    pagination_class = None
    filter_class = None
    permission_classes = (AllowAny,)

    def get(self, request, format=None, *args, **kwargs):
        """
        Uses raw query for fetching as GeoJSON because it is much faster to let PostGIS generate
        than Djangonauts serializer.
        """
        query = """
        SELECT row_to_json(fc)
        FROM (
            SELECT 'FeatureCollection' AS type,
                array_to_json(array_agg(f)) AS features
            FROM (SELECT 'Feature' AS type, ST_AsGeoJSON(g.geom_pt)::json AS geometry, g.uuid AS id,
                  row_to_json((SELECT p FROM (
                    SELECT uuid AS id, name, label, country, state_abbrev, organization_id) AS p))
                    AS properties
            FROM pfb_analysis_neighborhood AS g WHERE g.visibility <> %s) AS f)  AS fc;
        """

        with connection.cursor() as cursor:
            cursor.execute(query, [Neighborhood.Visibility.HIDDEN])
            json = cursor.fetchone()
            if not json or not len(json):
                return Response({})

        return Response(json[0])


class USStateView(APIView):
    """Convenience endpoint for available U.S. state options."""

    pagination_class = None
    filter_class = None
    permission_classes = (AllowAny,)

    def get(self, request, format=None, *args, **kwargs):
        return Response([{'abbr': state.abbr, 'name': state.name} for state in
                         us.STATES_AND_TERRITORIES])


class CountriesView(APIView):
    """Convenience endpoint for Django countries."""

    pagination_class = None
    filter_class = None
    permission_classes = (AllowAny,)

    # Make a list of countries with US territories excluded, since we'll treat them as states
    COUNTRIES_MINUS_TERRITORIES = [{'abbr': abbr, 'name': name} for (abbr, name) in list(countries)
                                   if abbr not in [t.abbr for t in us.TERRITORIES]]

    def get(self, request, format=None, *args, **kwargs):
        return Response(self.COUNTRIES_MINUS_TERRITORIES)
