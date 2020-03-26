(function () {
    'use strict';

    /* ngInject */
    function ConfirmationModal($uibModal) {
        var module = {
            open: open
        };
        return module;

        // Return uibModalInstance object
        function open(params) {
            var uibModalInstance = $uibModal.open({
                templateUrl: 'app/components/modals/confirmation-modal.html',
                controller: 'ModalInstanceController',
                controllerAs: 'modal',
                bindToController: true,
                size: 'md',
                resolve: {
                    params: function () {
                        return params;
                    }
                }
            });

            return uibModalInstance;
        }
    }

    angular.module('pfb.components.modals')
    .service('ConfirmationModal', ConfirmationModal);

})();
