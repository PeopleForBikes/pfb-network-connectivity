(function() {

    /* @ngInject */
    function MapController($element) {
        var ctl = this;
        ctl.map = null;
        ctl.mapHTMLElement = $element[0];
        ctl.pfbMapOptions = ctl.pfbMapOptions || {};

        ctl.$onChanges = function (changes) {
            ctl.updateMapOptions(changes);
        };

        ctl.$postLink = function () {
            ctl.map = L.map(ctl.mapHTMLElement, ctl.pfbMapOptions);
            ctl.updateMapOptions({
                pfbMapBounds: { currentValue: ctl.pfbMapBounds },
                pfbMapCenter: { currentValue: ctl.pfbMapCenter },
                pfbMapZoom: { currentValue: ctl.pfbMapZoom },
                pfbMapBaselayer: { currentValue: ctl.pfbMapBaselayer }
            });
            ctl.pfbMapReady({map: ctl.map});
        };

        ctl.updateMapOptions = function (changes) {
            if (ctl.map) {
                if (changes.pfbMapBounds && changes.pfbMapBounds.currentValue) {
                    ctl.map.fitBounds(changes.pfbMapBounds.currentValue);
                }
                if (changes.pfbMapCenter && changes.pfbMapCenter.currentValue) {
                    ctl.map.panTo(changes.pfbMapCenter.currentValue, {animate: false});
                }
                if (changes.pfbMapZoom && changes.pfbMapZoom.currentValue) {
                    ctl.map.setZoom(changes.pfbMapZoom.currentValue, {animate: false});
                }

                if (changes.pfbMapBaselayer && changes.pfbMapBaselayer.currentValue) {
                    if (ctl.baseLayer) {
                        ctl.map.removeLayer(ctl.baseLayer);
                        ctl.baseLayer = null;
                    }
                    ctl.baseLayer = changes.pfbMapBaselayer.currentValue;
                    ctl.map.addLayer(ctl.baseLayer);
                }
            }
        };
    }

    function PFBMapDirective() {
        var module = {
            restrict: 'A',
            controller: 'PFBMapController',
            controllerAs: 'ctl',
            bindToController: true,
            scope: {
                pfbMapBounds: '<',
                pfbMapZoom: '<',
                pfbMapCenter: '<',
                pfbMapBaselayer: '<',
                pfbMapOptions: '<',
                pfbMapReady: '&'
            }
        };
        return module;
    }


    angular.module('pfb.components.map')
        .controller('PFBMapController', MapController)
        .directive('pfbMap', PFBMapDirective);

})();
