#!/bin/bash

source ./scripts/ordered_static_resources.sh

function apply_k8_resources() {
    # Create namespaces
    kubectl apply -f $shakudo_helm_chart_path/static/namespaces/

    # Apply CRDs
    kubectl apply -f $shakudo_helm_chart_path/static/crds/
    kubectl apply -f $shakudo_helm_chart_path/static/prometheus/
    kubectl apply -f $shakudo_helm_chart_path/static/cert-manager/cert-manager.yaml

    create_secrets
    create_configmaps   
    create_rbac

    create_gitserver
    create_cluster_issuer
    create_istio_service_mesh

    kubectl apply -f $shakudo_helm_chart_path/static/priorityClasses
}

# Disallow expansion of unset variables
set -o nounset

# Exit upon error
set -e

init_paths
apply_k8_resources