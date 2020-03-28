(function() {
  'use strict';

  var config = {
    baseLayers: {
        'Positron': {
            url: 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
            attribution: [
                '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>, ',
                '&copy; <a href="https://carto.com/attribution">CARTO</a> | ',
                '<a target="_blank" href="http://learnosm.org/en/">Improve this map</a>'].join('')
        },
        'Stamen' : {
            url: 'https://stamen-tiles.a.ssl.fastly.net/toner-lite/{z}/{x}/{y}.png',
            attribution: ['Map tiles by <a href="http://stamen.com">Stamen Design</a>, ',
                'under <a href="http://creativecommons.org/licenses/by/3.0">CC BY 3.0</a>. ',
                'Data by <a href="http://openstreetmap.org">OpenStreetMap</a>, under ',
                '<a href="http://www.openstreetmap.org/copyright">ODbL</a>. | ',
                '<a target="_blank" href="http://learnosm.org/en/">Improve this map</a>'
            ].join('')
        },
        'Satellite': {
            url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            attribution: [
                '&copy; <a href="http://www.esri.com/">Esri</a> ',
                'Source: Esri, DigitalGlobe, GeoEye, Earthstar Geographics, CNES/Airbus DS, USDA, USGS, ',
                'AEX, Getmapping, Aerogrid, IGN, IGP, swisstopo, and the GIS User Community'
            ].join('')
        }
    },
    conusBounds: [[24.396308, -124.848974], [49.384358, -66.885444]],
    conusMaxZoom: 19,
    legends: {
        census_blocks: {
            position: 'bottomright',
            colors: ['#FF3300', '#D04628', '#B9503C', '#A25A51', '#8B6465', '#736D79', '#5C778D', '#4581A2', '#2E8BB6', '#009FDF'],
            labels: ['0 - 9', '10 - 19', '20 - 29', '30 - 39', '40 - 49', '50 - 59', '60 - 69', '70 - 79', '80 - 89', '90 - 100'],
            title: 'BNA Score'
        },
        bike_infrastructure: {
            position: 'bottomright',
            colors: ['#8c54de', '#5072f5', '#44a3a6', '#15bf50'],
            labels: ['Conventional Lane', 'Buffered Lane', 'Protected Lane', 'Off-Street Path'],
            title: 'Bike Infrastructure'
        },
        ways: {
            position: 'bottomright',
            colors: ['#009fdf', '#ff3300'],
            labels: ['Low Stress', 'High Stress']
        }
    }
  };

  angular
    .module('pfb.components.map')
    .constant('MapConfig', config);

})();
