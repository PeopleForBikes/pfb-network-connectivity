
(function() {

    /* @ngInject */
    function NeighborhoodDetailMapController(MapConfig, Neighborhood) {
        var ctl = this;
        ctl.map = null;
        ctl.boundsLayer = null;

        ctl.$onInit = function () {
            ctl.mapOptions = {
                // All the defaults are fine for this purpose
            };

            // The map directive has to have some bounds to initialize. It will zoom to the
            // fit the neighborhood polygon bounds when it's loaded.
            ctl.initialBounds = MapConfig.conusBounds;

            ctl.baseLayer = L.tileLayer(
                MapConfig.baseLayers.Positron.url, {
                    attribution: MapConfig.baseLayers.Positron.attribution,
                    maxZoom: MapConfig.conusMaxZoom
                });
        };

        // Listener to load and zoom to the boundary once the instance is set from the parent scope
        ctl.$onChanges = function(changes) {
            if (changes.pfbNeighborhoodId && changes.pfbNeighborhoodId.currentValue && ctl.map) {
                loadBounds(changes.pfbNeighborhoodId.currentValue);
            }
        };

        ctl.onMapReady = function (map) {
            ctl.map = map;
            // If the id is already in place (unlikely but maybe possible), load the boundary now
            if (ctl.pfbNeighborhoodId) {
                loadBounds(ctl.pfbNeighborhoodId);
            }
        };

        function loadBounds(uuid) {
            Neighborhood.bounds({uuid: uuid}).$promise.then(function (data) {
                var boundsLayer = L.geoJSON(data, {});
                ctl.map.addLayer(boundsLayer);
                ctl.map.fitBounds(boundsLayer.getBounds(), {
                    maxZoom: MapConfig.conusMaxZoom,
                    animate: false
                });
            });
        }
    }

    function NeighborhoodDetailMapDirective() {
        var module = {
            restrict: 'E',
            scope: {
                pfbNeighborhoodId: '<'
            },
            controller: 'NeighborhoodDetailMapController',
            controllerAs: 'ctl',
            bindToController: true,
            templateUrl: 'app/neighborhoods/detail/neighborhood-detail-map.html'
        };
        return module;
    }


    angular.module('pfb.neighborhoods.detail')
        .controller('NeighborhoodDetailMapController', NeighborhoodDetailMapController)
        .directive('pfbNeighborhoodDetailMap', NeighborhoodDetailMapDirective);

})();
