(function () {
    'use strict';

    /**
     * A controller for a uibModal instance.
     * Use 'resolve' in your $uibModal.open() call to fill 'params' with whatever parameters
     * you want to use inside the modal.
     */
    /* ngInject */
    function ModalInstanceController($uibModalInstance, params) {
        var ctl = this;
        ctl.ok = ok;
        ctl.cancel = cancel;

        // params needs to be set on construction. If delayed until $onInit, the initial template
        // render doesn't have the values it needs
        ctl.params = params;

        function ok () {
            $uibModalInstance.close();
        }

        function cancel () {
            $uibModalInstance.dismiss('cancel');
        }
    }

    angular.module('pfb.components.modals')
    .controller('ModalInstanceController', ModalInstanceController);

})();
