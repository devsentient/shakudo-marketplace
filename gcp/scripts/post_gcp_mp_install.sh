#!/bin/bash

source ./scripts/ordered_static_resources.sh

function refresh_hyperplane_service_account() {
    release_namespace=$(grep 'TOREPLACE_RELEASE_NAMESPACE:' ./values.yaml | awk '{print $2}')
    encoded_secret_value=$(kubectl get secret gcr-service-account-1r1byicw -n "$release_namespace" -o jsonpath='{.data.gcp-service-account-credentials\.json}')
    decoded_secret_value=$(echo -n "$encoded_secret_value" | base64 --decode)
    escaped_secret_value=$(jq -aRs . <<< "$decoded_secret_value")
    
    kubectl patch secret gcr-service-account-jhub-42b5pz2e -n hyperplane-development -p "{\"data\":{\"gcr-hyperplane-credentials.json\":\"$encoded_secret_value\"}}"
    kubectl patch secret gcr-service-account-key-pipelines-zsaw8epg -n hyperplane-workloads -p "{\"data\":{\"gcr-hyperplane-credentials.json\":\"$encoded_secret_value\"}}"

    kubectl patch configmap hyperplane-settings -n hyperplane-development --type=merge --patch "{\"data\":{\"SERVICE_ACCOUNT_KEY_CONTENT\":$escaped_secret_value}}"
    kubectl patch configmap hyperplane-settings -n hyperplane-workloads --type=merge --patch "{\"data\":{\"SERVICE_ACCOUNT_KEY_CONTENT\":$escaped_secret_value}}"
}

function enable_prometheus_metrics() {
    kubectl_output=$(kubectl get clusterroles | grep "prometheusK8s")
    promtheus_role_name=$(echo $kubectl_output | awk '{print $1}')

    kubectl patch clusterrole $promtheus_role_name --type=json -p='[{"op": "add", "path": "/rules/-", "value": { "nonResourceURLs": ["/metrics"], "verbs": ["get"]}}]'
    kubectl patch clusterrole $promtheus_role_name --type=json -p='[{"op": "add", "path": "/rules/-", "value": { "apiGroups": [""], "resources": ["nodes", "nodes/metrics", "services", "endpoints", "pods"], "verbs": ["get", "list", "watch"]}}]'
}

function add_hyperplane_podspec_permissions() {
    kubectl_output=$(kubectl get clusterroles | grep "dashboard")
    dashboard_role_name=$(echo $kubectl_output | awk '{print $1}')

    kubectl patch clusterrole $dashboard_role_name --type=json -p='[{"op": "add", "path": "/rules/-", "value": { "apiGroups": ["crds.hyperplane.com"], "resources": ["hyperplanepodspecs"], "verbs": ["get", "list", "watch", "create", "update", "delete"]}}]'
}

function apply_k8_resources() {
    apply_post_install_resources "false" "false"

    refresh_hyperplane_service_account

    enable_prometheus_metrics

    add_hyperplane_podspec_permissions
}

# Disallow expansion of unset variables
set -o nounset

# Exit upon error
set -e

init_paths
apply_k8_resources