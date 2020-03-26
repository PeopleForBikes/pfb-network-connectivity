/**
 * @ngdoc controller
 * @name pfb.neighborhoods.detail.controller:NeighborhoodDetailController
 *
 * @description
 * Controller for creating a neighborhood upload
 *
 */
(function() {
    'use strict';

    /** @ngInject */
    function NeighborhoodDetailController($log, $state, $stateParams, toastr, Upload, Neighborhood,
                                          Country, parseErrorFilter) {
        var ctl = this;

        var DEFAULT_COUNTRY = {alpha_2: 'US', name: 'United States'};

        function initialize() {
            if ($stateParams.uuid) {
                ctl.editing = true;
                ctl.neighborhood = Neighborhood.get($stateParams);
            }

            // TODO: De-dupe from API?
            ctl.visibilities = [
                ['public', 'Public'],
                ['private', 'Private']
            ]

            loadData();
        }

        initialize();

        function loadData() {
            Country.query().$promise
            // Load countries list from API
            .then(function(response) { ctl.countries = response; })
            // Load the neighborhood OR set the default country
            .then(function() {
                if (ctl.editing) {
                    return ctl.neighborhood.$promise.then(function(neighborhood) {
                        ctl.country = {
                            alpha_2: neighborhood.country.code,
                            name: neighborhood.country.name
                        }
                    });
                } else {
                    ctl.country = DEFAULT_COUNTRY;
                    return ctl.neighborhood;  // Return from promise to ensure next step waits
                }
            })
            .then(function() {
                // Use the countries response to fill in states
                ctl.country = _.find(ctl.countries,
                    function (c) { return c.alpha_2 === ctl.country.alpha_2; });
                // Then use the country object to load the selected one, if applicable
                ctl.state = _.find(ctl.country.subdivisions,
                    function (s) { return s.code === ctl.neighborhood.state_abbrev});
            })
        }

        ctl.saveNeighborhood = function() {
            var uploadToast = toastr.info('Saving neighborhood. Please wait...',
                                          {autoDismiss: false});

            var url = '/api/neighborhoods/' + (ctl.editing ? ctl.neighborhood.uuid + '/' : '');
            var method = ctl.editing ? 'PATCH' : 'POST';
            var verb = ctl.editing ? 'update' : 'create';
            var neighborhoodData = {
                boundary_file: ctl.file,
                // Only send state if it's supported (i.e. if the country has subdivisions)
                state_abbrev: ctl.state && ctl.country.subdivisions ? ctl.state.code : '',
                // Only send city FIPS if it's supported (i.e. only for US)
                city_fips: ctl.isDefaultCountry() ? (ctl.neighborhood.city_fips || '') : '',
                country: ctl.country.alpha_2,
                visibility: ctl.neighborhood.visibility,
                label: ctl.neighborhood.label
            };

            Upload.upload({
                url: url,
                method: method,
                data: neighborhoodData
            }).then(function() {
                toastr.clear(uploadToast);
                toastr.success('Successfully ' + verb + 'd neighborhood');
                $state.go('admin.neighborhoods.list');
            }).catch(function(error) {
                $log.error(error);
                toastr.clear(uploadToast);
                var errorDetails = parseErrorFilter(error);
                var msg = 'Unable to ' + verb + ' neighborhood' +
                          (errorDetails ? ': <br/>' + errorDetails : '');
                toastr.error(msg);
            });
        };

        ctl.isDefaultCountry = function() {
            return ctl.country && ctl.country.alpha_2 === 'US';
        }
    }
    angular
        .module('pfb.neighborhoods.detail')
        .controller('NeighborhoodDetailController', NeighborhoodDetailController);
})();
