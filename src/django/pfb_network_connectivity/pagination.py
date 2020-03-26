from rest_framework.pagination import LimitOffsetPagination


class OptionalLimitOffsetPagination(LimitOffsetPagination):
    """
    Allow client to request all by setting limit parameter to 'all'

    Inspired by https://github.com/azavea/ashlar/blob/develop/ashlar/pagination.py
    """
    def paginate_queryset(self, queryset, request, view=None):
        self.limit = self.get_limit(request)
        # set the limit to one more than the queryset count
        if self.limit == 'all':
            self.limit = self.get_count(queryset) + 1
        return super(OptionalLimitOffsetPagination, self).paginate_queryset(queryset, request, view)

    def get_limit(self, request):
        # If the limit is already set as an integer (e.g. because we're in the
        # super.paginate_queryset call), just return it
        if type(getattr(self, 'limit', None)) == int:
            return self.limit
        if self.limit_query_param and request.query_params.get(self.limit_query_param) == 'all':
            return 'all'
        return super(OptionalLimitOffsetPagination, self).get_limit(request)
