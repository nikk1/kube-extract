#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# How to use it
usage() {
  echo "Usage: $0 [-c | -i | -s]"
  echo "  -c    Extract ConfigMaps"
  echo "  -i    Extract Ingresses"
  echo "  -s    Extract Secrets"
  echo "  -d    Extract Deployments"
  echo "  -v    Extract Services"
  echo "  -ds   Extract DaemonSets"
  echo " -so    Extract ScaledObjects"

  exit 1
}

main() {
  # Ensure only one flag is passed
  if [ "$#" -ne 1 ]; then
    usage
  fi

  # Determine resource and output folder
  case "$1" in
    -c)
      resource="configmap"
      outdir="config"
      ;;
    -i)
      resource="ingress"
      outdir="ingress"
      ;;
    -s)
      resource="Secret"
      outdir="secret"
      ;;
   -d)
      resource="Deployment"
      outdir="deployment"
      ;;
   -v)
        resource="Service"
        outdir="service"
        ;;
   -ds)
        resource="DaemonSet"
        outdir="daemonset"
        ;;

    -so)
        resource="ScaledObject"
        outdir="scaledobject"
        ;;
    *)
      usage
      ;;
  esac

  confirm_namespace "$resource"
  mkdir -p "$outdir"
  extract_resources "$resource" "$outdir"
  echo -e "${GREEN}✔ Done. Resources saved in $outdir/${NC}"
}

confirm_namespace() {
  # Fetch current context and namespace
  context=$(kubectl config current-context)
  namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}')
  if [ -z "$namespace" ]; then
    namespace="default"
  fi

  # Show context/namespace with icons
  echo -e "${YELLOW}🧭  Current context:${NC} ${BOLD}$context${NC}"
  echo -e "${YELLOW}📦  Namespace:${NC} ${BOLD}$namespace${NC}"
  echo -e "${YELLOW}🔍  Resource type:${NC} ${BOLD}${1}${NC}"
  echo

  # Ask for confirmation
  echo -e "${RED}❓  Continue extracting '${1}s' from namespace '$namespace'?${NC}"
  read -p "[y/N]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${RED}✖ Aborted.${NC}"
    exit 1
  fi

  export namespace
}

extract_resources() {
  local resource=$1
  local outdir=$2

  kubectl get "$resource" -n "$namespace" -o yaml > /tmp/kube_extract_all.yaml

  yq eval '.items[]' -o=y /tmp/kube_extract_all.yaml | \
  awk -v outdir="$outdir" '
    /^apiVersion:/ { if (f) close(f); f=sprintf("%s/resource_%03d.yaml", outdir, ++i) }
    { print >> f }
  '

  for file in "$outdir"/resource_*.yaml; do
    name=$(yq e '.metadata.name' "$file")

    # Skip secrets that contain '-tls' to avoid TLS secrets
    if [[ "$resource" == "secret" && "$name" == *-tls* ]]; then
      echo -e "${YELLOW}⚠ Skipping TLS secret: $name${NC}"
      rm "$file"
      continue
    fi

    newfile="$outdir/${name}.yaml"
    mv "$file" "$newfile"

    # Strip unwanted fields
    yq eval 'del(
      .metadata.managedFields,
      .metadata.annotations."kubectl.kubernetes.io/last-applied-configuration",
      .metadata.creationTimestamp,
      .metadata.resourceVersion,
      .metadata.uid,
      .metadata.generation,
      .spec.clusterIP,
      .spec.clusterIPs,
      .spec.internalTrafficPolicy,
      .spec.ipFamilies,
      .spec.ipFamilyPolicy,
      .status
    )' -i "$newfile"
  done

  rm /tmp/kube_extract_all.yaml
}

# Run the script with arguments
main "$@"