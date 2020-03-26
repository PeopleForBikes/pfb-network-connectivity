/**
 * @ngdoc controller
 * @name pfb.analysisJobs.import.controller:AnalysisJobImportController
 *
 * @description
 * Controller for importing analysis results for a job run elsewhere
 *
 */
(function() {
    'use strict';

    /** @ngInject */
    function AnalysisJobImportController($state, toastr, Neighborhood, AnalysisJobImport) {
        var ctl = this;

        function initialize() {
            ctl.neighborhoods = Neighborhood.all({ordering: 'label'}).$promise.then(function(data) {
                ctl.neighborhoods = data.results;
            });
        }

        initialize();

        ctl.import = function() {
            var submitToast = toastr.info('Submitting analysis import. Please wait...',
                                          {autoDismiss: false});

            var job = new AnalysisJobImport({
                neighborhood: ctl.neighborhood.uuid,
                upload_results_url: ctl.url
            });
            job.$save().then(function() {
                toastr.clear(submitToast);
                toastr.success('Successfully submitted analysis import job');
                $state.go('admin.analysis-jobs.list');
            }).catch(function(error) {
                toastr.clear(submitToast);
                toastr.error('Error submitting analysis import job: ' + error);
            });
        };
    }
    angular
        .module('pfb.analysisJobs.import')
        .controller('AnalysisJobImportController', AnalysisJobImportController);
})();
