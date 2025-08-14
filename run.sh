#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color code

# Print when no paramenter are passed
usage() {
  echo -e "${BOLD}Usage:${NC} $0 [option]"
  echo -e "  ${CYAN}-a${NC}      Extract ${BOLD}All resources${NC}"
  echo -e "  ${CYAN}-c${NC}      Extract ${BOLD}ConfigMaps${NC}"
  echo -e "  ${CYAN}-i${NC}      Extract ${BOLD}Ingresses${NC}"
  echo -e "  ${CYAN}-s${NC}      Extract ${BOLD}Secrets${NC}"
  echo -e "  ${CYAN}-d${NC}      Extract ${BOLD}Deployments${NC}"
  echo -e "  ${CYAN}-v${NC}      Extract ${BOLD}Services${NC}"
  echo -e "  ${CYAN}-ds${NC}     Extract ${BOLD}DaemonSets${NC}"
  echo -e "  ${CYAN}-so${NC}     Extract ${BOLD}ScaledObjects${NC}"
  echo -e "  ${CYAN}-st${NC}     Extract ${BOLD}StatefulSets${NC}"
  echo -e "  ${CYAN}-pd${NC}     Extract ${BOLD}PodDisruptionBudget${NC}"
  echo -e "  ${CYAN}-cj${NC}     Extract ${BOLD}CronJobs${NC}"
  echo -e "  ${CYAN}-pvc${NC}    Extract ${BOLD}PersistentVolumeClaims${NC}"
  echo -e "  ${CYAN}-pv${NC}     Extract ${BOLD}PersistentVolumes${NC}"
  echo -e "  ${CYAN}-role${NC}   Extract ${BOLD}Roles${NC}"
  echo -e "  ${CYAN}-rb${NC}     Extract ${BOLD}RoleBindings${NC}"
  echo -e "  ${CYAN}-cr${NC}     Extract ${BOLD}ClusterRoles${NC}"
  echo -e "  ${CYAN}-crb${NC}    Extract ${BOLD}ClusterRoleBindings${NC}"


  exit 1
}

main() {
  # Ensure only one flag is passed
  if [ "$#" -ne 1 ]; then
    usage
  fi

  # Determine resource and output folder
  case "$1" in
    -a)
         all_resources=(
            configmap ingress secret deployment service daemonset scaledobject statefulset poddisruptionbudget cronjob
            namespace persistentvolumeclaim persistentvolume endpoints serviceaccount role rolebinding clusterrole clusterrolebinding
            networkpolicy horizontalpodautoscaler limitrange resourcequota event customresourcedefinition
          )
          for res in "${all_resources[@]}"; do
                # Map resource to outdir
                case "$res" in
                  configmap) outdir="config" ;;
                  ingress) outdir="ingress" ;;
                  secret) outdir="secret" ;;
                  deployment) outdir="deployment" ;;
                  service) outdir="service" ;;
                  daemonset) outdir="daemonset" ;;
                  scaledobject) outdir="scaledobject" ;;
                  statefulset) outdir="statefulset" ;;
                  poddisruptionbudget) outdir="pdb" ;;
                  cronjob) outdir="cronjob" ;;
                  namespace) outdir="namespace" ;;
                  persistentvolumeclaim) outdir="pvc" ;;
                  persistentvolume) outdir="pv" ;;
                  endpoints) outdir="endpoints" ;;
                  serviceaccount) outdir="serviceaccount" ;;
                  role) outdir="role" ;;
                  rolebinding) outdir="rolebinding" ;;
                  clusterrole) outdir="clusterrole" ;;
                  clusterrolebinding) outdir="clusterrolebinding" ;;
                  networkpolicy) outdir="networkpolicy" ;;
                  horizontalpodautoscaler) outdir="hpa" ;;
                  limitrange) outdir="limitrange" ;;
                  resourcequota) outdir="resourcequota" ;;
                  event) outdir="event" ;;
                  customresourcedefinition) outdir="crd" ;;
                esac

                mkdir -p "$outdir"
                echo -e "${CYAN}🔹 Extracting ${res}s...${NC}"
                extract_resources "$res" "$outdir"
            done
            echo -e "${GREEN}✔ All resources extracted.${NC}"
            exit 0;;
    -c) resource="configmap"; outdir="config" ;;
    -i) resource="ingress"; outdir="ingress" ;;
    -s) resource="secret"; outdir="secret" ;;
    -d) resource="deployment"; outdir="deployment" ;;
    -v) resource="service"; outdir="service" ;;
    -ds) resource="daemonset"; outdir="daemonset" ;;
    -so) resource="scaledobject"; outdir="scaledobject" ;;
    -st) resource="statefulset"; outdir="statefulset" ;;
    -pd) resource="poddisruptionbudget"; outdir="pdb" ;;
    -cj) resource="cronjob"; outdir="cronjob" ;;
    -pvc) resource="persistentvolumeclaim"; outdir="pvc" ;;
    -pv) resource="persistentvolume"; outdir="pv" ;;
    -role) resource="role"; outdir="role" ;;
    -rb) resource="rolebinding"; outdir="rolebinding" ;;
    -cr) resource="clusterrole"; outdir="clusterrole" ;;
    -crb) resource="clusterrolebinding"; outdir="clusterrolebinding" ;;
    *) usage ;;
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
      .metadata.annotations."deployment.kubernetes.io/revision",
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