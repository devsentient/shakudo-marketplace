#!/bin/bash

function init_paths(){
    monorepo_root_dir="$(git rev-parse --show-toplevel)"
    export kubectl_values=${monorepo_root_dir}/gcp/values.yaml
    export kubectl_apply_with_values=${monorepo_root_dir}/gcp/scripts/kubectl_apply_with_values.sh
    export shakudo_helm_chart_path=${monorepo_root_dir}/gcp/chart/shakudo-platform
}

function create_secrets(){
    cert_manager_path=$shakudo_helm_chart_path/static/cert-manager
    hyperplane_development_path=$shakudo_helm_chart_path/static/hyperplane-development/secrets
    hyperplane_workloads_path=$shakudo_helm_chart_path/static/hyperplane-workloads/secrets

    $kubectl_apply_with_values --source-file $cert_manager_path/secret-gcp-service-account-key.yaml --values-file $kubectl_values
    
    $kubectl_apply_with_values --source-file $hyperplane_development_path/secret-gcp-service-account-key.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_development_path/secret-hyperplane-jhub-gcr-service-account-jhub-42b5pz2e.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_development_path/secrets-git-deploy-secret-jhub.yaml --values-file $kubectl_values

    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/secret-gcp-service-account-key.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/secret-hyperplane-gcr-docker-auth.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/secret-hyperplane-pipelines-custom-deploy-secrets-g994i1y2.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/secret-hyperplane-pipelines-github-deploy-key-ancrht4u.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/secret-hyperplane-pipelines-hyperplane-jobs-ssh-public-keys.yaml --values-file $kubectl_values
}

function create_configmaps(){
    hyperplane_development_path=$shakudo_helm_chart_path/static/hyperplane-development/configmaps
    hyperplane_workloads_path=$shakudo_helm_chart_path/static/hyperplane-workloads/configmaps

    $kubectl_apply_with_values --source-file $hyperplane_development_path/configmap-hyperplane-development-hyperplane-settings.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/configmap-hyperplane-workloads-hyperplane-settings.yaml --values-file $kubectl_values
}

function create_rbac(){
    hyperplane_development_path=$shakudo_helm_chart_path/static/hyperplane-development/rbac
    hyperplane_workloads_path=$shakudo_helm_chart_path/static/hyperplane-workloads/rbac

    $kubectl_apply_with_values --source-file $hyperplane_development_path/serviceaccount-hyperplane-jhub-gcr-jhub.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/serviceaccount-hyperplane-pipelines-gcr-pipelines.yaml --values-file $kubectl_values

    $kubectl_apply_with_values --source-file $hyperplane_development_path/role-hyperplane-development-devs-role-krsb9h82.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/role-hyperplane-pipelines-pipelines-role-cwxtsd6t.yaml --values-file $kubectl_values
}

function create_pvcs(){
    hyperplane_development_path=$shakudo_helm_chart_path/static/hyperplane-development/gpu-resources
    hyperplane_workloads_path=$shakudo_helm_chart_path/static/hyperplane-workloads/gpu-resources

    $kubectl_apply_with_values --source-file $hyperplane_development_path/persistentvolume-hyperplane-conda-gke-accelerated2-gputest-v1-volume.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/persistentvolume-hyperplane-conda-gke-accelerated2-gputest-v1-volume.yaml --values-file $kubectl_values

    $kubectl_apply_with_values --source-file $hyperplane_development_path/persistentvolumeclaim-hyperplane-pipelines-conda-pipeline-pvc.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/persistentvolumeclaim-hyperplane-pipelines-conda-pipeline-pvc.yaml --values-file $kubectl_values
}

function create_gitserver(){
    hyperplane_workloads_path=$shakudo_helm_chart_path/static/hyperplane-workloads/git-server

    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/deployment-hyperplane-pipelines-git-server-eiufsnuf.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $hyperplane_workloads_path/service-hyperplane-pipelines-git-server.yaml --values-file $kubectl_values
}

function create_cluster_issuer(){
    cert_manager_path=$shakudo_helm_chart_path/static/cert-manager
    $kubectl_apply_with_values --source-file $cert_manager_path/clusterissuer-hyperplane-certmanager-letsencrypt-dns-w2v1dwkr.yaml --values-file $kubectl_values
}

function create_istio_service_mesh(){
    istio_path=$shakudo_helm_chart_path/static/istio

    $kubectl_apply_with_values --source-file $istio_path/clusterrole-default-istio-operator.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $istio_path/clusterrolebinding-default-istio-operator.yaml --values-file $kubectl_values
    
    $kubectl_apply_with_values --source-file $istio_path/serviceaccount-istio-system-istio-ingressgateway-service-account.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $istio_path/serviceaccount-istio-operator-istio-operator.yaml --values-file $kubectl_values

    $kubectl_apply_with_values --source-file $istio_path/role-istio-system-istio-ingressgateway-sds.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $istio_path/rolebinding-istio-system-istio-ingressgateway-sds.yaml --values-file $kubectl_values
    
    $kubectl_apply_with_values --source-file $istio_path/deployment-istio-operator-istio-operator.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $istio_path/deployment-istio-system-istio-ingressgateway.yaml --values-file $kubectl_values

    $kubectl_apply_with_values --source-file $istio_path/poddisruptionbudget-istio-system-istio-ingressgateway.yaml --values-file $kubectl_values
    
    $kubectl_apply_with_values --source-file $istio_path/service-istio-operator-istio-operator.yaml --values-file $kubectl_values

    $kubectl_apply_with_values --source-file $istio_path/horizontalpodautoscaler-istio-system-istio-ingressgateway.yaml --values-file $kubectl_values
}

function apply_post_install_resources(){
    local is_dev_deployment=$1
    local SNOWPLOW_ENABLED=$2
    post_install_path=$shakudo_helm_chart_path/static/post-install

    $kubectl_apply_with_values --source-file $post_install_path/grafana/grafana-dashboardDefinitions.yaml --values-file $kubectl_values
    
    $kubectl_apply_with_values --source-file $post_install_path/istio/envoyFilter-istio-cookie.yaml --values-file $kubectl_values

    $kubectl_apply_with_values --source-file $post_install_path/prometheus/rolebinding-hyperplane-jhub-prometheus-jhub-role-binding-1agrq182.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $post_install_path/prometheus/rolebinding-hyperplane-pipelines-prometheus-pipeline-role-binding-jqrypvlh.yaml --values-file $kubectl_values

    $kubectl_apply_with_values --source-file $post_install_path/prometheus/prometheus-k8s-kube-system-role.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $post_install_path/prometheus/prometheus-k8s-kube-system-rolebinding.yaml --values-file $kubectl_values

    $kubectl_apply_with_values --source-file $post_install_path/rbac/role-hyperplane-core-jhub.yaml --values-file $kubectl_values
    $kubectl_apply_with_values --source-file $post_install_path/rbac/role-hyperplane-core-pipeline.yaml --values-file $kubectl_values

    if [ "$is_dev_deployment" = "true" ]; then
        $kubectl_apply_with_values --source-file $post_install_path/istio/authorizationpolicy-dev-istio-system-keycloak-istio-auth-policy-2zp8slg3.yaml --values-file $kubectl_values
    else
        $kubectl_apply_with_values --source-file $post_install_path/istio/authorizationpolicy-istio-system-keycloak-istio-auth-policy-2zp8slg3.yaml --values-file $kubectl_values
    fi

    if [ "$SNOWPLOW_ENABLED" = "true" ]; then
        $kubectl_apply_with_values --source-file $post_install_path/istio/rbac.yaml --values-file $kubectl_values
        $kubectl_apply_with_values --source-file $post_install_path/trackers/subdomainActivityCronjob.yaml --values-file $kubectl_values
    fi
}