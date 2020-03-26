/**
 * @ngdoc controller
 * @name pfb.neighborhood.list.controller:NeighborhoodListController
 *
 * @description
 * Controller for listing analysis jobs
 *
 */
(function() {
    'use strict';

    /** @ngInject */
    function NeighborhoodListController($state, $stateParams, toastr, Pagination, AuthService,
                                        Neighborhood, ConfirmationModal) {
        var ctl = this;

        var defaultParams = {
            limit: null,
            offset: null
        };
        var nextParams = {};
        var prevParams = {};

        initialize();

        function initialize() {
            ctl.isAdminUser = AuthService.isAdminUser();

            ctl.hasNext = false;
            ctl.getNext = getNext;

            ctl.hasPrev = false;
            ctl.getPrev = getPrev;
            ctl.neighborhoods = [];

            ctl.deleteUpload = deleteUpload;
            ctl.filters = {};

            getNeighborhoods();
        }

        function getNeighborhoods(params) {
            params = params || $stateParams;
            Neighborhood.query(params).$promise.then(function(data) {
                ctl.neighborhoods = _.map(data.results, function(obj) {
                    return new Neighborhood(obj);
                });

                if (data.next) {
                    ctl.hasNext = true;
                    nextParams = Pagination.getLinkParams(data.next);
                } else {
                    ctl.hasNext = false;
                    nextParams = {};
                }

                if (data.previous) {
                    ctl.hasPrev = true;
                    prevParams = Pagination.getLinkParams(data.previous);
                } else {
                    ctl.hasPrev = false;
                    prevParams = {};
                }

            });
        }

        function getNext() {
            var params = _.merge({}, defaultParams, nextParams);
            $state.go('admin.neighborhoods.list', params, {notify: false});
            getNeighborhoods(params);
        }

        function getPrev() {
            var params = _.merge({}, defaultParams, prevParams);
            $state.go('admin.neighborhoods.list', params, {notify: false});
            getNeighborhoods(params);
        }

        function deleteUpload (neighborhood) {
            ConfirmationModal.open({
                headerText: 'Confirm Neighborhood Deletion',
                bodyText: 'Are you sure you want to delete the <b>' +
                          neighborhood.label + ', ' + neighborhood.label_suffix +
                          '</b> neighborhood?<br/>' +
                          'All associated analysis jobs will also be deleted.',
                confirmButtonText: 'Delete'
            })
            .result
            .then(function () { return neighborhood.$delete(); })
            .then(function () {
                toastr.success('Successfully deleted neighborhood');
                getNeighborhoods();
            })
            .catch(function() {
                toastr.error('Error deleting neighborhood');
            });
        }

    }

    angular
        .module('pfb.neighborhoods.list')
        .controller('NeighborhoodListController', NeighborhoodListController);
})();
