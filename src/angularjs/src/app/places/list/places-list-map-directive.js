(function() {

    /* @ngInject */
    function PlacesListMapController(MapConfig, Neighborhood) {
        var ctl = this;
        ctl.map = null;
        ctl.layerControl = null;
        // keys in this object are the uuids of the items to filter from the
        //   geojson requested by this directive
        // values are a string that can be used to group the items, typically
        //   for something like pulling a specific styling config
        ctl.neighborhoods = {};

        ctl.$onInit = function () {
            ctl.boundsConus = MapConfig.conusBounds;
            ctl.baseLayer = L.tileLayer(
                MapConfig.baseLayers.Positron.url, {
                    attribution: MapConfig.baseLayers.Positron.attribution,
                    maxZoom: MapConfig.conusMaxZoom
                });
        };

        ctl.$onChanges = function (changes) {
            ctl.neighborhoods = changes.pfbPlacesListMapNeighborhoods.currentValue || {};
            drawNeighborhoods();
        }

        ctl.onMapReady = function (map) {
            ctl.map = map;

            var satelliteLayer = L.tileLayer(MapConfig.baseLayers.Satellite.url, {
                attribution: MapConfig.baseLayers.Satellite.attribution,
                maxZoom: MapConfig.conusMaxZoom
            });

            if (!ctl.layerControl) {
                ctl.layerControl = L.control.layers({
                        'Positron': ctl.baseLayer,
                        'Satellite': satelliteLayer
                    },
                    []).addTo(ctl.map);
            }

            Neighborhood.geojson().$promise.then(function (data) {
                ctl.geojson = data;
                drawNeighborhoods();
            });

        };

        function drawNeighborhoods() {
            if (!(ctl.geojson && ctl.map)) {
                return;
            }
            if (ctl.neighborhoodLayer) {
                ctl.map.removeLayer(ctl.neighborhoodLayer);
            }
            var geojson = {
                type: "FeatureCollection",
                features: _.filter(ctl.geojson.features, function (f) {
                    return !!(ctl.neighborhoods[f.id])
                })
            };
            ctl.neighborhoodLayer = L.geoJSON(geojson, {
                onEachFeature: onEachFeature
            });
            ctl.map.addLayer(ctl.neighborhoodLayer);

            function onEachFeature(feature, layer) {
                layer.on({
                    click: function () {
                        if (feature && feature.geometry &&
                            feature.geometry.coordinates) {
                            var popup = L.popup()
                                .setLatLng([
                                    feature.geometry.coordinates[1],
                                    feature.geometry.coordinates[0]
                                ])
                                .setContent(feature.properties.label);
                            ctl.map.openPopup(popup);
                        }
                    }
                });
            }
        }
    }

    function PlacesListMapDirective() {
        var module = {
            restrict: 'E',
            scope: {
                pfbPlacesListMapNeighborhoods: '<'
            },
            controller: 'PlacesListMapController',
            controllerAs: 'ctl',
            bindToController: true,
            templateUrl: 'app/places/list/places-list-map.html'
        };
        return module;
    }


    angular.module('pfb.places.list')
        .controller('PlacesListMapController', PlacesListMapController)
        .directive('pfbPlacesListMap', PlacesListMapDirective);

})();
