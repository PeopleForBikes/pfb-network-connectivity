(function() {
    'use strict';

    angular
        .module('pfb', [
            'angular-loading-bar', 'pfb.login', 'pfb.analysisJobs', 'pfb.help', 'pfb.home',
            'pfb.utils', 'pfb.places', 'pfb.passwordReset', 'pfb.users', 'pfb.organizations',
            'pfb.neighborhoods',
            'ngAnimate', 'ngCookies', 'ngSanitize', 'ngMessages', 'ngAria',
            'ngResource', 'ui.router', 'toastr', 'ui.bootstrap', 'pfb.components']);

})();
