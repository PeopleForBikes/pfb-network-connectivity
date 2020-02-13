#!/bin/bash

set -e

cd `dirname "${0}"`

if [[ -n "${PFB_DEBUG}" ]]; then
    set -x
fi

function usage() {
    echo -n \
"
Usage: $(basename "$0") <path to boundary file> <state abbrev of boundary> <state fips of boundary>

Import all necessary files to run the analysis. See the scripts this calls for specific
ENV configuration options.

"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]
then
    if [ "${1:-}" = "--help" ] || [ -z "${1:-}" ]
    then
        usage
    else
        ../import/import_neighborhood.sh "${1}" "${3}"
        ../import/import_osm.sh "${4}"
    fi
fi
