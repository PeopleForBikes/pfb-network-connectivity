"""API views for users, logins, api tokens, and organizations"""
from django.conf import settings
from django.contrib.auth import (
    authenticate,
    login,
    logout
)
from django.core.mail import send_mail
from django.core.signing import TimestampSigner, BadSignature

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import permissions, serializers, status, viewsets
from rest_framework.authtoken.models import Token
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.filters import OrderingFilter
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from pfb_network_connectivity.filters import OrgOrAdminAutoFilterBackend, SelfUserAutoFilterBackend
from pfb_network_connectivity.permissions import IsAdminOrSelfOnly, RestrictedCreate
from users.models import Organization, PFBUser
from users.serializers import OrganizationSerializer, PFBUserSerializer
from users.emails import password_reset_txt, user_registration_txt
from users.utils import get_password_reset_url


class PFBUserLoginView(APIView):
    """View to login users; public endpoint that does not require authentication"""
    permission_classes = ()
    authentication_classes = ()

    def post(self, request, *args, **kwargs):
        """Login a user given a username password combination

        Args:
            request (rest_framework.request.Request)
        """
        email = request.data.get('email', None)
        password = request.data.get('password', None)
        if not all([email, password]):
            raise serializers.ValidationError({'error': 'email and/or password not provided'})
        user = authenticate(email=email, password=password)
        if user is not None:
            login(request, user)
            return Response(PFBUserSerializer(user).data)
        else:
            return Response({
                'detail': 'Unable to login with provided username/password'
            }, status=status.HTTP_401_UNAUTHORIZED)


class PFBUserLogoutView(APIView):
    """View to log users out"""
    permission_classes = ()
    authentication_classes = ()

    def post(self, request, *args, **kwargs):
        """Logout a user

        Args:
            request (rest_framework.request.Request)
        """
        logout(request)
        return Response({'detail': 'Successfully logged out'})


class PFBUserViewSet(viewsets.ModelViewSet):
    """ViewSet responsible for creating/updating/deleting users/tokens

    This view set powers the `/api/users` endpoints. This includes creating, reading,
    updating, deleting users in addition to changing passwords and generating/retrieving
    tokens for a user.

    Attributes:
        queryset: django queryset, note 'auth_token' is selected with queryset
        serializer_class (PFBUserSerializer): serializes users
    """
    permission_classes = (IsAuthenticated, IsAdminOrSelfOnly,)
    queryset = PFBUser.objects.all().select_related('auth_token')
    serializer_class = PFBUserSerializer
    filter_fields = ('organization', 'role')
    filter_backends = (DjangoFilterBackend, OrderingFilter,
                       OrgOrAdminAutoFilterBackend, SelfUserAutoFilterBackend)

    def create(self, request, *args, **kwargs):
        """Override create to send registration email after user creation

        Emails are only sent if the user is created with an email address

        Args:
            request (rest_framework.request.Request): request object for creation
        """

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)

        # If created successfully, send email
        user = serializer.instance
        if user.email:
            url = get_password_reset_url(request, user)
            created_by_name = '{} {}'.format(
                request.user.first_name, request.user.last_name
            ).strip()
            if len(created_by_name) == 0:
                created_by_name = request.user.email
            created_by_organization = request.user.organization.name
            context = {
                'user_firstname': user.first_name, 'created_by_name': created_by_name,
                'created_by_organization': created_by_organization,
                'created_organization': user.organization.name,
                'url': url, 'username': user.email
            }
            send_mail(
                settings.USER_EMAIL_SUBJECT,
                user_registration_txt.format(**context),
                settings.RESET_EMAIL_FROM,
                [user.email]
            )
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    @action(detail=True, methods=['get', 'post'])
    def token(self, request, pk=None):
        """Creates/Retrieves tokens

        Tokens are generated only if a user needs it via a ``POST`` to this
        endpoint. ``GET`` requests for a token return a ``404`` if tokens have
        yet to be generated.

        Args:
            request (rest_framework.request.Request)
            pk (str): primary key for user to retrieve user from database
        Returns:
            Response
        """
        user = self.get_object()

        def token_data(t):
            return {'token': t.key}

        if request.method == 'GET':
            if user.token:
                return Response(token_data(user.token))
            else:
                return Response(
                    {'detail': 'Token not found for user'},
                    status=status.HTTP_404_NOT_FOUND
                )
        elif request.method == 'POST':
            if user.token:
                user.token.delete()
            token = Token.objects.create(user=user)
            return Response(token_data(token), status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def set_password(self, request, pk=None):
        """Detail ``POST`` endpoint for changing a user's password

        Args:
            request (rest_framework.request.Request)
            pk (str): primary key for user to retrieve user from database
        Returns:
            Response
        """
        old_password = request.data.get('oldPassword')
        user = authenticate(email=PFBUser.objects.get(uuid=pk).email,
                            password=old_password)
        if not user:
            raise ValidationError({'detail': 'Unable to complete password change'})

        new_password = request.data.get('newPassword')
        if not new_password:
            raise ValidationError({'detail': 'Unable to complete password change'})
        user.set_password(new_password)
        user.save()

        return Response({'detail': 'Successfully changed password'},
                        status=status.HTTP_200_OK)


class OrganizationViewSet(viewsets.ModelViewSet):
    """ViewSet responsible for creating/updating/deleting organizations

    Only admins within the admin organization will be able to view/edit/create organizations
    """
    permission_classes = (IsAuthenticated, RestrictedCreate)
    filter_backends = (OrgOrAdminAutoFilterBackend,)
    queryset = Organization.objects.all()
    serializer_class = OrganizationSerializer
    pagination_class = None


class PFBRequestPasswordReset(APIView):
    """View to allow password resets for users"""
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        if 'email' not in request.data:
            return Response({'errors': ['No email provided']}, status.HTTP_400_BAD_REQUEST)
        email = request.data['email']
        try:
            user = PFBUser.objects.get(email=email)
            url = get_password_reset_url(request, user)

            if user.email:
                send_mail(
                    settings.USER_EMAIL_SUBJECT,
                    password_reset_txt.format(username=user.get_short_name(), url=url),
                    settings.RESET_EMAIL_FROM,
                    [email]
                )
        except PFBUser.DoesNotExist:
            pass
        return Response({'status': 'Success'})


class PFBResetPassword(APIView):
    """View for resetting password

    Checks the signed token and changes the password if valid
    """

    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        errors = []
        fatal = False
        token = request.data.get('token')
        password = request.data.get('password')
        if not token:
            errors.append('Invalid reset token.')
            fatal = True
        if not password:
            errors.append('No password provided.')
        signer = TimestampSigner(salt=settings.RESET_SALT)
        if token:
            try:
                user_uuid = signer.unsign(token, max_age=settings.RESET_TOKEN_LENGTH)
            except BadSignature:
                errors.append('Can not reset password because the reset link used was invalid.')
                fatal = True
        if len(errors) == 0:
            # set password
            user = PFBUser.objects.get(uuid=user_uuid)
            user.set_password(password)
            user.save()
            return Response({'status': 'Success'})
        else:
            return Response({'errors': errors, 'fatal': fatal}, status.HTTP_400_BAD_REQUEST)
