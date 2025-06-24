#!/usr/bin/env bash

# Install the CRDs so we can create/get them
install_appstudio_repo_crds () {
    git clone https://github.com/$1/$2
    pushd $2
    kubectl create -f config/crd/bases
    popd
}

if ! kubectl get crd snapshots.appstudio.redhat.com ; then
    install_appstudio_repo_crds "redhat-appstudio" "application-api"
fi

if ! kubectl get crd releases.appstudio.redhat.com ; then
    install_appstudio_repo_crds "konflux-ci" "internal-services"
fi

if ! kubectl get crd releases.appstudio.redhat.com ; then
    install_appstudio_repo_crds "konflux-ci" "release-service"
fi

# Add RBAC so that the SA executing the tests can retrieve CRs
TASK_PATH="$1"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
kubectl apply -f "${SCRIPT_DIR}/crd_rbac.yaml"
