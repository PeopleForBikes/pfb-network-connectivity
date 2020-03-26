/**
 * @ngdoc controller
 * @name pfb.place.list.controller:PlaceListController
 *
 * @description
 * Controller for listing analysis jobs
 *
 */
(function() {
    'use strict';

    /** @ngInject */
    function PlaceListController($log, $state, $stateParams, $scope, Pagination, AuthService,
                                 Neighborhood, AnalysisJob, Country) {
        var ctl = this;

        var sortingOptions = [
            {
                // string that gets passed to the /api/analysis_jobs/?ordering param
                value: 'neighborhood__label',
                // Human readable label to show in dropdown UI
                label: 'Place name'
            }, {
                value: '-overall_score',
                label: 'Highest Rated'
            }, {
                value: 'overall_score',
                label: 'Lowest Rated'
            }, {
                value: '-modified_at',
                label: 'Last Updated'
            }, {
                value: '-population_total',
                label: 'Population',
                // The value for the groupFn key corresponds to the 'iteratee' param
                //  of https://lodash.com/docs/4.17.4#groupBy
                // The _.groupBy keys will be used as the section headers in the list UI.
                // If you don't want section headers, omit groupFn.
                groupFn: function (n) {
                    var pop = n.population_total;
                    if (pop >= 500000) {
                        return 'Large';
                    } else if (pop >= 100000) {
                        return 'Medium';
                    } else if (pop > 0) {
                        return 'Small';
                    } else {
                        return 'Unknown';
                    }
                }
            }
        ];

        var defaultParams = {
            limit: null,
            offset: null,
            latest: 'True',
            status: 'COMPLETE'
        };
        var mapStyleKeys = {
            DEFAULT: 'default',
            COMPARE: 'compare'
        };

        initialize();

        function initialize() {
            ctl.isAdminUser = AuthService.isAdminUser();

            ctl.getNext = null;
            ctl.getPrev = null;
            ctl.places = [];
            ctl.searchText = '';
            ctl.mapPlaces = {};

            ctl.comparePlaces = [];
            ctl.maxPlaceCompare = 3;
            ctl.addPlaceToCompare = addPlaceToCompare;
            ctl.removeComparePlace = removeComparePlace;
            ctl.filterNeighborhoods = filterNeighborhoods;
            ctl.filterByCountry = filterByCountry;
            ctl.goComparePlaces = goComparePlaces;
            ctl.isInPlaceCompare = isInPlaceCompare;
            ctl.isPlaceCompareFull = isPlaceCompareFull;

            ctl.sortBy = sortingOptions[0]; // default to alphabetical order
            ctl.sortingOptions = sortingOptions;

            ctl.getPlaces = getPlaces;

            ctl.countryFilter = null;
            ctl.stateFilter = null;
            ctl.countries = [];
            Country.query({has_jobs: true}).$promise.then(function(response) {
                ctl.countries = response;
                // Build a {country: [subdivisions]} object for countries that have them
                ctl.states = _(ctl.countries)
                    .filter(function (c) { return c.subdivisions; })
                    .map(function (c) { return [c.alpha_2, c.subdivisions]; })
                    .fromPairs().value();
            });

            getPlaces(true);
        }

        /**
         * Add a place to the list of up to three places to view on compare page.
         *
         * @param {Neighborhood} place Neighborhood to list of places to compare
         */
        function addPlaceToCompare(place) {
            if (isInPlaceCompare(place.uuid)) {
                $log.warn('aready have place selected to compare');
            } else if (isPlaceCompareFull()) {
                $log.warn('already have three places to compare');
            } else {
                ctl.comparePlaces.push(place);
                updateComparisonsInUrl();
                setMapPlaces(ctl.places);
            }
        }

        /**
         * Helper to query separately for comparison places that may not be on the current page.
         * Should only be invoked after full place list for page has been loaded.
         */
        function getComparisonPlaces() {
            // Read out pre-set places to compare from the URL. Keep this state in the URL
            // so user can navigate between places list and comparison without losing selections.
            var uuidsToCompare = [$stateParams.place1, $stateParams.place2, $stateParams.place3];
            _.remove(uuidsToCompare, function(placeId) { return placeId.length === 0; });

             // Fetch places to compare; not all may be in the current page of `places`
            _.map(uuidsToCompare, function(uuid) {
                Neighborhood.query({uuid: uuid}).$promise.then(function(obj) {
                    var neighborhood = new Neighborhood(obj);
                    neighborhood.modifiedAt = obj.modifiedAt;
                    neighborhood.overall_score = obj.overall_score;
                    neighborhood.population_total = obj.population_total;
                    addPlaceToCompare(neighborhood);
                });
            });
        }

        // Convenience method to transition to places comparison page.
        function goComparePlaces() {
            $state.go('places.compare', $stateParams);
        }

        /**
         * Fired when an option selected from comparison drop-down.
         * Remove a selected place from comparison list.
         *
         * @param {String} uuid Neighborhood ID to remove from set of places to compare
         */
        function removeComparePlace(uuid) {
            if (!uuid) {
                return; // on page load, this watch fires will no value
            }

            var removeOffset = getPlaceCompareIndex(uuid);
            if (removeOffset > -1) {
                // remove Neighborhood from array of places selected for comparison
                ctl.comparePlaces.splice(removeOffset, 1);
                updateComparisonsInUrl();
                setMapPlaces(ctl.places);
            } else {
                $log.warn('no place with UUID ' + uuid + ' found to remove from comparison');
            }
        }

        function getPlaceCompareIndex(uuid) {
            return _.findIndex(ctl.comparePlaces, function (p) {
                return p && p.uuid === uuid;
            });
        }

        function isInPlaceCompare(uuid) {
            return getPlaceCompareIndex(uuid) !== -1;
        }

        function isPlaceCompareFull() {
            return ctl.comparePlaces.length >= ctl.maxPlaceCompare;
        }

        // helper to update URL after places added or removed for comparison, without reloading
        function updateComparisonsInUrl() {
            for (var i = 0; i < ctl.maxPlaceCompare; i++) {
                var place = ctl.comparePlaces[i];
                $stateParams['place' + (i + 1)] = place ? place.uuid : '';
            }
            $state.go('places.list', $stateParams, {notify: false});
        }

        function filterNeighborhoods() {
            getPlaces(false);
        }

        function filterByCountry() {
            ctl.stateFilter = null;
            filterNeighborhoods();
        }

        function getPlaces(fetchComparisonPlaces, params) {
            params = params || _.merge({}, defaultParams);
            params.ordering = ctl.sortBy.value;
            if (ctl.searchText) {
                params.search = ctl.searchText;
            }
            if (ctl.countryFilter) {
                params.neighborhood__country=ctl.countryFilter;
            }
            if (ctl.stateFilter) {
                params.neighborhood__state_abbrev=ctl.stateFilter;
            }

            AnalysisJob.query(params).$promise.then(function(data) {

                var places = _.map(data.results, function(obj) {
                    var neighborhood = new Neighborhood(obj.neighborhood);
                    // get properties from the neighborhood's last run job
                    neighborhood.modifiedAt = obj.modifiedAt;
                    neighborhood.overall_score = obj.overall_score;
                    neighborhood.population_total = obj.population_total;
                    return neighborhood;
                });
                setMapPlaces(places);

                // Get the grouping function, or fall back to using a keyword that groups
                // everything together and tells the template to omit sections labels.
                var groupFn = ctl.sortBy.groupFn || function () { return 'SKIPHEADER'; };

                var groupedPlaces = _.groupBy(places, groupFn);
                ctl.sections = _.keys(groupedPlaces).sort();
                ctl.places = groupedPlaces;

                ctl.getNext = pageButton('next', data);
                ctl.getPrev = pageButton('previous', data);

                if (fetchComparisonPlaces) {
                    getComparisonPlaces();
                }
            });
        }

        // Returns a function to go the next or previous page, to be used by the pagination buttons,
        // or 'null' if the data says there are no more pages in the given direction.
        function pageButton(direction, data) {
            if (!data[direction]) {
                return null;
            }
            return function() {
                var pageParams = Pagination.getLinkParams(data[direction])
                var params = _.merge({}, defaultParams, pageParams);
                $state.go('places.list', params, {notify: false});
                getPlaces(false, params);
            };
        }

        // Must set ctl.mapPlaces via this so that the object ref gets updated
        function setMapPlaces(places) {
            var mapPlaces = _.reduce(places, function (result, value) {
                result[value.uuid] = mapStyleKeys.DEFAULT;
                return result;
            }, {});
            _.forEach(ctl.comparePlaces, function (place) {
                if (place && place.uuid) {
                    mapPlaces[place.uuid] = mapStyleKeys.COMPARE;
                }
            });
            ctl.mapPlaces = mapPlaces;
        }
    }

    angular
        .module('pfb.places.list')
        .controller('PlaceListController', PlaceListController);
})();
