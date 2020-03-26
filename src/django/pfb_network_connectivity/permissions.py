"""Permission classes and helpers for limiting access to resources/actions"""

from rest_framework import permissions

from users.models import OrganizationTypes, UserRoles


def is_admin(user):
    """Helper function to check if user has an admin role

    Arguments:
        user (users.models.PFBUser): user to check role type

    Returns:
        bool: True if user has an admin role
    """
    return hasattr(user, 'organization') and user.role == UserRoles.ADMIN


def is_org_admin(user):
    """Returns true is user has organization admin role."""
    return hasattr(user, 'organization') and user.role == UserRoles.ORGADMIN


def users_in_same_organization(user_one, user_two):
    """Returns true if the two users passed in belong to the same organization."""
    if not hasattr(user_one, 'organization') or not hasattr(user_two, 'organization'):
        return False
    return user_one.organization == user_two.organization


def is_not_subscriber(user):
    """Helper function to check if user is not in a subscriber organization

    Arguments:
        user (users.models.PFBUser): user to check org type

    Returns:
        bool: True if user is not in a subscriber organization
    """

    return user.organization.org_type != OrganizationTypes.SUBSCRIBER


def is_admin_org(user):
    """Helper function to check if user is in an admin organization

    Arguments:
        user (users.models.PFBUser): user to check org type

    Returns:
        bool: True if user is in an admin organization
    """
    return hasattr(user, 'organization') and user.organization.org_type == OrganizationTypes.ADMIN


class IsNotSubscriber(permissions.BasePermission):
    """Prevent subscribers from accessing endpoint/action if a subscriber"""

    def has_permission(self, request, view):
        return is_not_subscriber(request.user)

    def has_object_permission(self, request, view, obj):
        return is_not_subscriber(request.user)


class IsAdminOrgAndAdmin(permissions.BasePermission):
    """Restrict access to admins in the admin org"""

    def has_permission(self, request, view):
        return is_admin(request.user) and is_admin_org(request.user)


class IsAdminOrgAndAdminCreateEditOnly(permissions.BasePermission):
    """Permission object to restrict create access for certain endpoints"""
    def has_permission(self, request, view):

        if request.method not in permissions.SAFE_METHODS:
            return is_admin(request.user) and is_admin_org(request.user)
        else:
            return True


class IsAdminOrSelfOnly(permissions.BasePermission):
    """Permissions checking for users endpoints and actions"""

    ALLOWED_OBJECT_METHODS = ('GET', 'PUT', 'PATCH', 'POST')
    ALLOWED_ACTIONS = ('list', 'update', 'partial_update', 'token')

    def has_permission(self, request, view):
        """Allow access to admins or if safe method"""

        if not request.user or not request.user.is_authenticated:
            return False

        if is_admin(request.user) or is_org_admin(request.user):
            return True

        if view.action in self.ALLOWED_ACTIONS or request.method in permissions.SAFE_METHODS:
            return True

        return False

    def has_object_permission(self, request, view, obj):
        """Only allow access to own user, do not allow deleting self"""

        if not request.user or not request.user.is_authenticated:
            return False

        # User cannot delete themselves
        if request.method == 'DELETE' and request.user == obj:
            return False

        if is_admin(request.user):
            return True

        # org admin users cannot view or modify full admin users
        if is_org_admin(request.user) and is_admin(obj):
            return False

        # org admin users can only view or modify users within their own organization
        if is_org_admin(request.user):
            return users_in_same_organization(request.user, obj)

        # read-write only access to one's own user object for non-admin users
        if request.method in self.ALLOWED_OBJECT_METHODS and request.user == obj:
            return True

        return False


class RestrictedCreate(permissions.BasePermission):
    """Restricts access for POST actions on views"""

    def has_permission(self, request, view):
        """Allow only admins to create results or upload local analyses
        Arguments:
            request (rest_framework.request.Request): request to check for
        """

        if request.method in permissions.SAFE_METHODS:
            return True

        if not request.user or not request.user.is_authenticated:
            return False

        if 'AnalysisJobViewSet' == view.__class__.__name__:
            return is_admin(request.user)
        elif 'AnalysisLocalUploadTaskViewSet' == view.__class__.__name__:
            return is_admin(request.user)
        elif ('OrganizationViewSet' == view.__class__.__name__ and
              is_admin(request.user) and is_admin_org(request.user)):
            return True
        else:
            return request.user.role in UserRoles.DEFAULT_CREATE
