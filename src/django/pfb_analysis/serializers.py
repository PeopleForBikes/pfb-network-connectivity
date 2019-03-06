from collections import OrderedDict

from django_countries.serializer_fields import CountryField
from rest_framework import serializers
import us

from pfb_analysis.models import (
    AnalysisJob,
    AnalysisLocalUploadTask,
    AnalysisScoreMetadata,
    Neighborhood,
    CITY_FIPS_LENGTH,
)
from pfb_network_connectivity.serializers import PFBModelSerializer


class PrimaryKeyReferenceRelatedField(serializers.PrimaryKeyRelatedField):
    """A custom relational field for read-only objects.

    This field is for the specific case where:
    1. We want to reference the model on create by its primary key
    2. We want to print the full serialized representation of the object on to_representation,
       using a serializer of our choice
    """

    def __init__(self, **kwargs):
        """Custom init to take an extra 'serializer' argument

        @param serializer A custom serializer instance, used to generate the object representation
                          in to_representation()
        """
        self.serializer = kwargs.pop('serializer')
        super(PrimaryKeyReferenceRelatedField, self).__init__(**kwargs)

    def use_pk_only_optimization(self):
        return False

    def to_representation(self, value):
        if self.allow_null is True and value.pk is None:
            return None
        try:
            serializer = self.serializer(value)
            return serializer.data
        except self.serializer.Meta.model.DoesNotExist:
            self.fail('does_not_exist', pk_value=value.pk)
        except (TypeError, ValueError):
            self.fail('incorrect_type', data_type=type(value).__name__)

    def get_choices(self, cutoff=None):
        """This is used to get the param value for the POST form in the DRF browsable API.
        It normally uses `to_representation` to get the param value, but we want it to use `pk`.
        """
        queryset = self.get_queryset()
        if queryset is None:
            # Ensure that field.choices returns something sensible
            # even when accessed with a read-only field.
            return {}

        if cutoff is not None:
            queryset = queryset[:cutoff]

        return OrderedDict([(item.pk, self.display_value(item)) for item in queryset])


class NeighborhoodSerializer(PFBModelSerializer):

    # Set default for country field, as serializers do not recognize model defaults
    country = CountryField(initial='US', country_dict=True)
    # Use minimum length serializer in-built validator (model only defines max)
    city_fips = serializers.CharField(max_length=CITY_FIPS_LENGTH, min_length=CITY_FIPS_LENGTH,
                                      default='', allow_blank=True, trim_whitespace=True)

    def validate(self, data):
        """Cross-field validation that US state is set or not based on country."""
        if data['country'] == 'US':
            if not data['state_abbrev']:
                raise serializers.ValidationError('State must be provided for US neighborhoods')
            fips = data['city_fips']
            if fips:
                if not fips.isdigit():
                    raise serializers.ValidationError(
                        'City FIPS must be a string of {fips_len} digits'
                        .format(fips_len=CITY_FIPS_LENGTH))
                us_state = us.states.lookup(data['state_abbrev'])
                if us_state and not fips.startswith(us_state.fips):
                    raise serializers.ValidationError(
                        'City FIPS must start with state FIPS: {state_fips}'
                        .format(state_fips=us_state.fips))
        else:
            if data['state_abbrev']:
                raise serializers.ValidationError('State can only be set for US neighborhoods')
            if data['city_fips']:
                raise serializers.ValidationError('City FIPS can only be set for US neighborhoods')
        return data

    class Meta:
        model = Neighborhood
        # explicitly list fields (instead of using `exclude`) to control ordering
        fields = ('uuid', 'createdAt', 'modifiedAt', 'createdBy', 'modifiedBy',
                  'name', 'label', 'organization', 'country', 'state_abbrev', 'city_fips',
                  'boundary_file', 'visibility', 'last_job',)
        read_only_fields = ('uuid', 'createdAt', 'modifiedAt', 'createdBy', 'modifiedBy',
                            'organization', 'last_job', 'name',)


class NeighborhoodSummarySerializer(PFBModelSerializer):
    """Serializer for including neighborhood information in AnalysisJob results.

    All the fields are read-only. Any changes to neighborhoods should happen through the
    neighborhoods endpoint, which uses the regular serializer.
    """
    country = CountryField(country_dict=True)

    class Meta:
        model = Neighborhood
        fields = ('uuid', 'name', 'label', 'country', 'state_abbrev', 'organization', 'geom_pt',)
        read_only_fields = fields


class AnalysisLocalUploadTaskSerializer(serializers.ModelSerializer):

    class Meta:
        model = AnalysisLocalUploadTask
        fields = ('uuid', 'created_at', 'modified_at', 'created_by', 'modified_by', 'job',
                  'status', 'error', 'upload_results_url',)
        read_only_fields = ('uuid', 'job', 'error', 'status', 'created_at', 'modified_at',
                            'created_by',)


class AnalysisLocalUploadTaskSummarySerializer(serializers.ModelSerializer):

    class Meta:
        model = AnalysisLocalUploadTask
        fields = ('status', 'error', 'upload_results_url',)
        read_only_fields = ('error', 'status', 'upload_results_url',)


class AnalysisLocalUploadTaskCreateSerializer(serializers.ModelSerializer):

    neighborhood = serializers.UUIDField(write_only=True)

    def create(self, validated_data):
        validated_data.pop('neighborhood')
        return super(AnalysisLocalUploadTaskCreateSerializer, self).create(validated_data)

    def validate_neighborhood(self, obj):
        if Neighborhood.objects.filter(uuid=obj).count() != 1:
            raise serializers.ValidationError(
                'No matching neighborhood found for UUID {uuid}'.format(uuid=obj))
        return obj

    class Meta:
        model = AnalysisLocalUploadTask
        fields = ('uuid', 'created_at', 'modified_at', 'created_by', 'modified_by',
                  'error', 'job', 'status', 'upload_results_url',
                  'neighborhood',)
        read_only_fields = ('uuid', 'created_at', 'modified_at', 'created_by', 'modified_by',
                            'error', 'job', 'status',)


class AnalysisJobSerializer(PFBModelSerializer):

    logs_url = serializers.SerializerMethodField()
    running_time = serializers.SerializerMethodField()
    start_time = serializers.SerializerMethodField()
    status = serializers.SerializerMethodField()
    neighborhood = PrimaryKeyReferenceRelatedField(queryset=Neighborhood.objects.all(),
                                                   serializer=NeighborhoodSummarySerializer)
    overall_score = serializers.FloatField(read_only=True)
    population_total = serializers.IntegerField(read_only=True)
    local_upload_task = PrimaryKeyReferenceRelatedField(serializer=AnalysisLocalUploadTaskSummarySerializer,
                                                        read_only=True)

    def get_logs_url(self, obj):
        return obj.logs_url

    def get_running_time(self, obj):
        return obj.running_time

    def get_start_time(self, obj):
        return obj.start_time

    def get_status(self, obj):
        return obj.status

    class Meta:
        model = AnalysisJob
        exclude = ('created_at', 'modified_at', 'created_by', 'modified_by', 'overall_scores',
                   'analysis_job_definition', '_analysis_job_name',)
        read_only_fields = ('uuid', 'createdAt', 'modifiedAt', 'createdBy', 'modifiedBy',
                            'batch_job_id', 'batch', 'census_block_count', 'final_runtime',
                            'local_upload_task')


class AnalysisScoreMetadataSerializer(serializers.ModelSerializer):

    class Meta:
        model = AnalysisScoreMetadata
        fields = ('name', 'label', 'category', 'description',)
        read_only_fields = ('name', 'label', 'category', 'description',)
