"""
Models related to users and organizations

Models in this file should relate directly to users of the
system, organizations, and user permissions.
"""

from __future__ import unicode_literals

from django.conf import settings
from django.core.mail import send_mail
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.utils import timezone
from django.utils.text import slugify
from django.utils.translation import ugettext_lazy as _
from django.db import models

from rest_framework.authtoken.models import Token

from pfb_network_connectivity.models import PFBModel


class OrganizationTypes:
    """Enum-like object to track organization types"""

    ADMIN = 'ADMIN'
    SUBSCRIBER = 'SUBSCRIBER'

    CHOICES = (
        (ADMIN, 'PFB Administrator Organization'),
        (SUBSCRIBER, 'Subscriber')
    )


class Organization(PFBModel):
    """Model for tracking subscribers and admin groups


    Every user will belong to an organization. Organization membership will determine
    whether or not a user can access or edit certain resources.

    There are 2 types of organizations:

    **Admin.** Membership in the admin organization will grant access to all other organizations,
    and the ability to create/delete users within the system. Membership in this organization
    will be tightly controlled and will be limited to PFB personnel who are responsible
    for activating/deactivating neighborhood sites and creating initial admin users
    within a neighborhood organization.

    **Subscriber.** Membership in a subscriber organization grants read-only access to results data.

    Attributes:
        name (str): Human readable, actual name for organization (e.g. Alabama, etc.)
        label (str): Slug version of name, appropriate for URLs and embeding in JSON
        org_type (str): ENUM like field for type of organization
        associated with organization
    """

    def __str__(self):
        return "<Organization: {}>".format(self.label)

    name = models.CharField(max_length=255, unique=True)
    label = models.SlugField(unique=True)
    org_type = models.CharField(choices=OrganizationTypes.CHOICES, max_length=10)

    def save(self, *args, **kwargs):
        """Override save method to add slug label.
        """
        if not self.label:
            self.label = slugify(self.name)
        super(Organization, self).save(*args, **kwargs)


class UserRoles:
    """Enum-like object to track acceptable user roles"""
    ADMIN = 'ADMIN'
    ORGADMIN = 'ORGADMIN'
    VIEWER = 'VIEWER'

    DEFAULT_CREATE = [ADMIN]

    CHOICES = (
        (ADMIN, 'Administrator'),
        (ORGADMIN, 'Organization Administrator'),
        (VIEWER, 'Viewer'),
    )


class PFBUserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, email, password, **extra_fields):
        """
        Creates and saves a User with the given username, email and password.
        """
        if not email:
            raise ValueError('The given email must be set')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', False)
        extra_fields.setdefault('is_superuser', False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')

        return self._create_user(email, password, **extra_fields)

    def get_root_user(self):
        """Get the primary admin user for the root organization.

        Draws from a value coded in settings. This would probably get the same user:
          root_org = Organization.objects.filter(org_type=OrganizationTypes.ADMIN).first()
          return self.filter(organization=root_org, role=UserRoles.ADMIN).first()
        but isn't guaranteed to, so it's a setting.
        """
        return self.get(email=settings.ROOT_USER_EMAIL)


class PFBUser(AbstractBaseUser, PermissionsMixin, PFBModel):
    """User class for PFB application

    Roles define a set of permissions for a user within an organization, determining the
    depth of access a user has within an organization. Roles are not mutually exclusive
    and a single user may have the following roles defined within the Repository:

    **Admin.** Administrators have the most access within an organization. They can manage
    users and manage the neighborhood site.

    **Org Admin.** Can manage users, but only within their organization and only for permission
    levels at or below their own.

    **Viewer.** Viewers have read-only access to resources associated with an organization.

    Attributes:
       organization (str): name of organization user represents
       token (Optional[Token]): token, if generated, for user else ``None``

    Attributes copied from BaseUser:
       email (email): contact email for the user. User as the username
       first_name (str): User's first name
       last_name (str): User's last name
       is_staff (boolean): Designates whether the user can log into this admin site.
       is_active (boolean): Designates whether this user should be treated as active.
       date_joined (datetime): Date the user joined

    Email and password are required. Other fields are optional.
    """
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['organization', 'role']

    email = models.EmailField(_('email address'),
                              unique=True,
                              help_text=_('Required. A valid email address'),
                              error_messages={'unique': _("A user with that email already exists")})
    first_name = models.CharField(_('first name'), max_length=30, blank=True)
    last_name = models.CharField(_('last name'), max_length=30, blank=True)
    organization = models.ForeignKey(Organization, on_delete=models.PROTECT)
    role = models.CharField(choices=UserRoles.CHOICES, default=UserRoles.VIEWER,
                            max_length=8)
    is_staff = models.BooleanField(
        _('staff status'),
        default=False,
        help_text=_('Designates whether the user can log into this admin site.'),
    )
    is_active = models.BooleanField(
        _('active'),
        default=True,
        help_text=_(
            'Designates whether this user should be treated as active. '
            'Unselect this instead of deleting accounts.'
        ),
    )
    date_joined = models.DateTimeField(_('date joined'), default=timezone.now)

    objects = PFBUserManager()

    @property
    def token(self):
        try:
            return self.auth_token
        except Token.DoesNotExist:
            return None

    class Meta:
        verbose_name = _('pfbuser')
        verbose_name_plural = _('pfbusers')

    def get_full_name(self):
        """
        Returns the first_name plus the last_name, with a space in between.
        """
        full_name = '{} {}'.format(self.first_name, self.last_name)
        return full_name.strip()

    def get_short_name(self):
        "Returns the short name for the user."
        return self.first_name

    def email_user(self, subject, message, from_email=None, **kwargs):
        """
        Sends an email to this User.
        """
        send_mail(subject, message, from_email, [self.email], **kwargs)
