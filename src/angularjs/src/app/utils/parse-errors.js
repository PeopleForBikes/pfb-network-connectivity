(function () {
    'use strict';

    /* ngInject */
    function parseError() {
        // Filter to extract API error messages into a readable format
        function parse(error) {
            if (error.data && angular.isObject(error.data)) {
                if (angular.isArray(error.data)) {
                    // Model validation error converted to serializer error comes back as a list
                    return error.data.join('<br/>');
                }
                if (error.data.non_field_errors) {
                    // Errors raised in `validate` come back as `non_field_errors`, an array
                    return error.data.non_field_errors.join('<br/>');
                } else {
                    // If neither of those apply, there should be field errors, as {field: msg}
                    return _.map(error.data, function(msg, field) {
                        return field + ': ' + msg; }).join('<br/>')
                }
            } else if (error.data) {
                // If there's `data` but it doesn't match an expected format, strip HTML formatting
                // and pass it along, or just pass it along if it's not formatted as HTML
                return angular.element(error.data).text() || error.data;
            } else {
                // If there's no `data`, return statusText (which might be empty or null)
                return error.statusText;
            }
        }
        return parse;
    }
    angular.module('pfb.utils')
        .filter('parseError', parseError);
})();
