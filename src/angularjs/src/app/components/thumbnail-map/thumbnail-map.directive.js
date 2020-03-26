
(function() {

    /* @ngInject */
    function ThumbnailMapController(MapConfig, Neighborhood) {
        var ctl = this;
        ctl.map = null;
        ctl.boundsLayer = null;

        ctl.$onInit = function () {
            ctl.mapOptions = {
                scrollWheelZoom: false,
                interactive: false,
                zoomControl: false,
                attributionControl: false,
                zoomAnimation: false
            };

            // will set center and zoom level by zooming to fit geojson polygon bounds when loaded
            ctl.boundsConus = MapConfig.conusBounds;
            ctl.baseLayer = L.tileLayer(
                MapConfig.baseLayers.Positron.url, {
                    attribution: MapConfig.baseLayers.Positron.attribution,
                    maxZoom: MapConfig.conusMaxZoom
                });
        };

        ctl.$onChanges = function(changes) {
            // set map layers once received from parent scope (paret-detail.controller)
            if (changes.pfbThumbnailMapPlace &&
                changes.pfbThumbnailMapPlace.currentValue && ctl.map) {

                loadBounds(changes.pfbThumbnailMapPlace.currentValue);
            }
        };

        ctl.onMapReady = function (map) {
            ctl.map = map;

            ctl.map.on('layeradd', function() {
                // Tell map to recalculate its size. Otherwise transition to compare page may
                // result in incorrect pan/zoom to bounds.
                ctl.map.invalidateSize(false);

                if (ctl.boundsLayer) {
                    var bounds = ctl.boundsLayer.getBounds();
                    ctl.map.fitBounds(bounds, {
                        maxZoom: MapConfig.conusMaxZoom,
                        animate: false
                    });
                }
            });

            if (ctl.pfbThumbnailMapPlace) {
                loadBounds(ctl.pfbThumbnailMapPlace);
            }
        };

        function loadBounds(uuid) {
            Neighborhood.bounds({uuid: uuid, simplified: true}).$promise.then(function (data) {
                ctl.boundsLayer = L.geoJSON(data, {});
                ctl.map.addLayer(ctl.boundsLayer);
            });
        }
    }

    function ThumbnailMapDirective() {
        var module = {
            restrict: 'E',
            scope: {
                pfbThumbnailMapPlace: '<'
            },
            controller: 'ThumbnailMapController',
            controllerAs: 'ctl',
            bindToController: true,
            templateUrl: 'app/components/thumbnail-map/thumbnail-map.html'
        };
        return module;
    }


    angular.module('pfb.components.thumbnailMap')
        .controller('ThumbnailMapController', ThumbnailMapController)
        .directive('pfbThumbnailMap', ThumbnailMapDirective);

})();
