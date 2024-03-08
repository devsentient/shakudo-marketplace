#!/bin/bash

readonly REALM_NAME=Hyperplane

function usage() { echo "Usage: $0 --client-id <value> --client-secret <value> --hosted-domain <value>" 1>&2; exit 1; }

function check_parameters() {
  if [ $# -eq 0 ]
  then
      usage 
  fi

  while [[ $# -gt 0 ]]; do
    flag="$1"
    case $flag in
    # TODO: Set this up to use our default oauth client creds from 1pass cli
    --client-id)
        if [ -z "${2-}" ] ; then
            usage
        fi
        CLIENT_ID="$2"
        shift 2
        ;;
    --client-secret)
        if [ -z "${2-}" ] ; then
            usage
        fi
        CLIENT_SECRET="$2"
        shift 2
        ;;
    --hosted-domain)
        if [ -z "${2-}" ] ; then
            usage
        fi
        HOSTED_DOMAIN="$2"
        shift 2
        ;;
    *)
        usage
        ;;
    esac
  done
}

function auth() {
  local encoded_keycloak_password="$(kubectl get secret "keycloak-login-pass" -n "$RELEASE_NAMESPACE" -o jsonpath='{.data}' | jq -r '.password')"

  local domain_name=$(kubectl get cm -n "$RELEASE_NAMESPACE" hyperplane-settings -o=jsonpath='{.data.HYPERPLANE_DOMAIN}')
  kcadm.sh config credentials --server https://${domain_name}/auth/ --realm master --user admin \
      --password "$(echo $encoded_keycloak_password | base64 --decode)"
}

function create_google_identity_provider() {
  kcadm.sh create identity-provider/instances -r "${REALM_NAME}" \
      -f ./scripts/keycloak_configs/google_identity_provider.json -s config.clientId=${CLIENT_ID} -s config.clientSecret=${CLIENT_SECRET} -s config.hostedDomain=${HOSTED_DOMAIN}
}

function main() {
  check_parameters "$@"
  auth

  create_google_identity_provider
}

# Disallow expansion of unset variables
set -o nounset

main "$@"