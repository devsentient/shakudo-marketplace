#!/bin/bash

function usage() { echo "Usage: $0 --source-file <value> --values-file <value>" 1>&2; exit 1; }

function cleanup {
    rm ./temp.yaml
}

function parse_parameters() {
    if [ $# -eq 0 ]
    then
        usage 
        exit 1
    fi
    if [ -z "${1-}" ]; then
        usage
        exit 1
    fi
    while [[ $# -gt 0 ]]; do
        key="$1"

        case $key in
        --source-file)
            SOURCE_FILE="$2"
            shift 2
            ;;
        --values-file)
            VALUES_FILE="$2"
            shift 2
            ;;
        *)
            usage
            exit 1
            ;;
        esac
    done

    if [ -z "${SOURCE_FILE}" ] && [ -z "${VALUES_FILE}" ]; then
        usage
        exit 1
    fi

    if [[ ! -f "${SOURCE_FILE}" ]] || [[ ! -f "${VALUES_FILE}" ]]; then
        echo "Both files must exist."
        usage
        exit 1
    fi
}

function apply_k8_resource() {
    cp "${SOURCE_FILE}" "temp.yaml"
    while IFS= read -r line; do
        if [[ -z "$line" ]] || [[ ! "$line" == *:* ]]; then
            continue
        fi

        # Extract variable and value
        variable="${line%%:*}"
        value="${line#*:}"

        # Trim leading and trailing whitespace
        variable=$(echo "$variable" | xargs)
        value=$(echo "$value" | xargs)

        # Replace all instances of the variable in deployment.yaml with the value
        #sed -i '' -E "s#<${variable}>#${value}#g" "temp.yaml"

        if [[ -z "$value" ]]; then
            sed -i '' -E "s#<${variable}>#\"\"#g" "temp.yaml"
        else
            sed -i '' -E "s#<${variable}>#${value}#g" "temp.yaml"
        fi

    done < $VALUES_FILE

    kubectl apply -f ./temp.yaml
}

trap cleanup EXIT

# Disallow expansion of unset variables
set -o nounset

# Exit upon error
set -e

parse_parameters "$@"
apply_k8_resource