#!/usr/bin/env bash
# teardown.sh — reduce or eliminate running cost.
#
# Two modes:
#   --node-group-only    Scale the EKS managed node group to zero.
#                        Keeps the EKS control plane, S3, RDS, VPC.
#                        Resume with --node-group-up.
#   --node-group-up      Scale the managed node group back to its desired size.
#   --full               terraform destroy on the environment. Irreversible.
#
# EKS control plane cost (~$72/mo) is paid whether nodes exist or not.
# Running nodes dominate cost; scaling to zero overnight saves the most.

set -euo pipefail

: "${AWS_PROFILE:=observability}"
: "${AWS_REGION:=us-east-1}"
: "${CLUSTER:=observability-eks}"
: "${NODE_GROUP:=observability-ng-default}"
: "${TF_DIR:=terraform/envs/prod}"

info() { printf "\033[1;34m==> %s\033[0m\n" "$*"; }
die()  { printf "\033[1;31m!!! %s\033[0m\n" "$*" >&2; exit 1; }

usage() {
  cat <<USAGE
Usage: $0 [--node-group-only | --node-group-up | --full]
  --node-group-only   Scale EKS node group to zero.
  --node-group-up     Scale EKS node group back to desired size.
  --full              terraform destroy the whole environment.
USAGE
  exit 1
}

[[ $# -eq 1 ]] || usage

case "$1" in
  --node-group-only)
    info "Scaling node group ${NODE_GROUP} to zero"
    aws eks update-nodegroup-config \
      --cluster-name "${CLUSTER}" \
      --nodegroup-name "${NODE_GROUP}" \
      --scaling-config minSize=0,maxSize=3,desiredSize=0 \
      --region "${AWS_REGION}" \
      --profile "${AWS_PROFILE}" >/dev/null
    info "Done. Nodes draining in the background."
    ;;

  --node-group-up)
    info "Scaling node group ${NODE_GROUP} back to desired size (3)"
    aws eks update-nodegroup-config \
      --cluster-name "${CLUSTER}" \
      --nodegroup-name "${NODE_GROUP}" \
      --scaling-config minSize=1,maxSize=3,desiredSize=3 \
      --region "${AWS_REGION}" \
      --profile "${AWS_PROFILE}" >/dev/null
    info "Done. New nodes join in 2–3 minutes."
    ;;

  --full)
    read -rp "This destroys the whole environment including state and S3 data. Type 'destroy' to proceed: " confirm
    [[ "${confirm}" == "destroy" ]] || die "Aborted."
    info "Running terraform destroy on ${TF_DIR}"
    cd "${TF_DIR}"
    terraform destroy
    ;;

  *)
    usage
    ;;
esac
