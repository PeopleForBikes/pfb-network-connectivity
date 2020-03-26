"""pfb_network_connectivity URL Configuration

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/1.10/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  url(r'^$', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  url(r'^$', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.conf.urls import url, include
    2. Add a URL to urlpatterns:  url(r'^blog/', include('blog.urls'))
"""
from django.conf import settings
from django.conf.urls import include, url
from django.contrib import admin
from django.contrib.staticfiles.urls import staticfiles_urlpatterns

from rest_framework import routers

from users import views as user_views
from pfb_analysis import views as analysis_views

router = routers.DefaultRouter()

router.register(r'organizations', user_views.OrganizationViewSet, base_name='organizations')
router.register(r'users', user_views.PFBUserViewSet, base_name='users')
router.register(r'analysis_batches', analysis_views.AnalysisBatchViewSet,
                base_name='analysis_batches')
router.register(r'analysis_jobs', analysis_views.AnalysisJobViewSet, base_name='analysis_jobs')
router.register(r'local_upload_tasks', analysis_views.AnalysisLocalUploadTaskViewSet,
                base_name='local_upload_tasks')
router.register(r'score_metadata', analysis_views.AnalysisScoreMetadataViewSet,
                base_name='score_metadata')
router.register(r'neighborhoods', analysis_views.NeighborhoodViewSet, base_name='neighborhoods')


urlpatterns = [
    url(r'^admin/', admin.site.urls),
    url(r'^api/', include((router.urls, 'api'))),
    url(r'^api-auth/', include('rest_framework.urls')),

    # Countries view
    url(r'^api/countries/', analysis_views.CountriesView.as_view()),

    # Neighborhood points set
    url(r'^api/neighborhoods_geojson/', analysis_views.NeighborhoodGeoJsonViewSet.as_view()),

    # Neighborhood bounds
    url(r'^api/neighborhoods_bounds_geojson/$',
        analysis_views.NeighborhoodBoundsGeoJsonViewList.as_view()),
    url(r'^api/neighborhoods_bounds_geojson/(?P<neighborhood>[0-9a-f-]+)/$',
        analysis_views.NeighborhoodBoundsGeoJsonViewDetail.as_view()),


    # User Views
    url(r'^api/login/', user_views.PFBUserLoginView.as_view()),
    url(r'^api/logout/', user_views.PFBUserLogoutView.as_view()),
    url(r'^api/users/(?P<pk>.+)/set-password',
        user_views.PFBUserViewSet.as_view({'post': 'set_password'})),

    # Password Reset
    url(r'^api/request-password-reset/', user_views.PFBRequestPasswordReset.as_view()),
    url(r'^api/reset-password/', user_views.PFBResetPassword.as_view()),

    # 3rd party
    url(r'^healthcheck/', include('watchman.urls'))
]

if settings.DEBUG:
    urlpatterns += staticfiles_urlpatterns()
