(function() {
    'use strict';

    // analysis job statuses, with short and long descriptive labels, for filtering
    var statuses = {
        CREATED: {
            short: 'Created',
            long: 'Created'
        },
        QUEUED: {
            short: 'Queued',
            long: 'Queued'
        },
        IMPORTING: {
            short: 'Importing',
            long: 'Importing Data'
        },
        BUILDING: {
            short: 'Building',
            long: 'Building Network Graph'
        },
        CONNECTIVITY: {
            short: 'Connectivity',
            long: 'Calculating Connectivity'
        },
        METRICS: {
            short: 'Metrics',
            long: 'Calculating Graph Metrics'
        },
        EXPORTING: {
            short: 'Exporting',
            long: 'Exporting Results'
        },
        COMPLETE: {
            short: 'Complete',
            long: 'Complete'
        },
        CANCELLED: {
            short: 'Cancelled',
            long: 'Cancelled'
        },
        ERROR: {
            short: 'Error',
            long: 'Error'
        }
    };

    angular
        .module('pfb.analysisJobs.constants', [])
        .constant('JOB_STATUSES', statuses);

})();
