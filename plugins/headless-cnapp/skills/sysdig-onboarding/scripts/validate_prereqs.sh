#!/usr/bin/env bash
# validate_prereqs.sh — Check prerequisites for Sysdig onboarding
#
# Usage: validate_prereqs.sh <type> [--json] [--aws-profile NAME]
#   type: aws | gcp | azure | kubernetes | host
#   --json: output structured JSON instead of colored text
#   --aws-profile NAME: use a specific AWS CLI profile
#
# Exit codes:
#   0 — All checks passed
#   1 — One or more checks failed

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
JSON_MODE=false
JSON_CHECKS=""
AWS_PROFILE_ARG=""

# Escape a string for safe JSON embedding
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

json_add() {
    local name="$1" status="$2" detail="$3" fix_macos="${4:-}" fix_linux="${5:-}"
    local entry
    entry=$(printf '{"name":"%s","status":"%s","detail":"%s","fix_macos":"%s","fix_linux":"%s"}' \
        "$(json_escape "$name")" "$status" "$(json_escape "$detail")" \
        "$(json_escape "$fix_macos")" "$(json_escape "$fix_linux")")
    if [[ -n "$JSON_CHECKS" ]]; then
        JSON_CHECKS="${JSON_CHECKS},${entry}"
    else
        JSON_CHECKS="${entry}"
    fi
}

pass() {
    if [[ "$JSON_MODE" == "true" ]]; then
        json_add "${2:-$1}" "pass" "$1" "" ""
    else
        echo -e "  ${GREEN}✓${NC} $1"
    fi
    PASS=$((PASS + 1))
}

fail() {
    if [[ "$JSON_MODE" == "true" ]]; then
        json_add "${2:-$1}" "fail" "$1" "${3:-}" "${4:-}"
    else
        echo -e "  ${RED}✗${NC} $1"
    fi
    FAIL=$((FAIL + 1))
}

warn() {
    if [[ "$JSON_MODE" == "true" ]]; then
        json_add "${2:-$1}" "warn" "$1" "${3:-}" "${4:-}"
    else
        echo -e "  ${YELLOW}!${NC} $1"
    fi
}

check_terraform() {
    [[ "$JSON_MODE" != "true" ]] && echo "" && echo "Terraform:"
    if command -v terraform &>/dev/null; then
        local version
        version=$(terraform version -json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['terraform_version'])" 2>/dev/null || terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        local major minor
        major=$(echo "$version" | cut -d. -f1)
        minor=$(echo "$version" | cut -d. -f2)
        if [[ "$major" -gt 1 ]] || { [[ "$major" -eq 1 ]] && [[ "$minor" -ge 10 ]]; }; then
            pass "Terraform v${version} (>= 1.10.0 required)" "Terraform"
        else
            fail "Terraform v${version} found, but >= 1.10.0 is required" "Terraform" \
                "brew upgrade terraform" "See https://terraform.io/downloads"
        fi
    else
        fail "Terraform not found" "Terraform" \
            "brew install terraform" "See https://terraform.io/downloads"
    fi
}

check_aws() {
    [[ "$JSON_MODE" != "true" ]] && echo "" && echo "AWS:"
    if command -v aws &>/dev/null; then
        pass "AWS CLI installed ($(command -v aws))" "AWS CLI"
    else
        fail "AWS CLI not found" "AWS CLI" \
            "brew install awscli" "apt install awscli"
        return
    fi

    if aws sts get-caller-identity &>/dev/null; then
        local account arn
        account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
        pass "AWS authenticated (account: ${account}, identity: ${arn})" "AWS Auth"
    else
        fail "AWS CLI not authenticated" "AWS Auth" \
            "aws configure or aws sso login" "aws configure or aws sso login"
    fi
}

check_gcp() {
    [[ "$JSON_MODE" != "true" ]] && echo "" && echo "GCP:"
    if command -v gcloud &>/dev/null; then
        pass "Google Cloud CLI installed ($(command -v gcloud))" "GCP CLI"
    else
        fail "Google Cloud CLI not found" "GCP CLI" \
            "brew install google-cloud-sdk" "See https://cloud.google.com/sdk/install"
        return
    fi

    local account
    account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
    if [[ -n "$account" ]]; then
        local project
        project=$(gcloud config get-value project 2>/dev/null)
        pass "GCP authenticated as ${account} (project: ${project:-not set})" "GCP Auth"
        if [[ -z "$project" ]]; then
            warn "No default project set" "GCP Project" \
                "gcloud config set project PROJECT_ID" "gcloud config set project PROJECT_ID"
        fi
    else
        fail "GCP not authenticated" "GCP Auth" \
            "gcloud auth login" "gcloud auth login"
    fi
}

check_azure() {
    [[ "$JSON_MODE" != "true" ]] && echo "" && echo "Azure:"
    if command -v az &>/dev/null; then
        pass "Azure CLI installed ($(command -v az))" "Azure CLI"
    else
        fail "Azure CLI not found" "Azure CLI" \
            "brew install azure-cli" "curl -sL https://aka.ms/InstallAzureCLIDeb | bash"
        return
    fi

    if az account show &>/dev/null; then
        local sub tenant
        sub=$(az account show --query name --output tsv 2>/dev/null)
        tenant=$(az account show --query tenantId --output tsv 2>/dev/null)
        pass "Azure authenticated (subscription: ${sub}, tenant: ${tenant})" "Azure Auth"
    else
        fail "Azure CLI not authenticated" "Azure Auth" \
            "az login" "az login"
    fi
}

check_kubernetes() {
    [[ "$JSON_MODE" != "true" ]] && echo "" && echo "Kubernetes:"

    # kubectl
    if command -v kubectl &>/dev/null; then
        pass "kubectl installed ($(command -v kubectl))" "kubectl"
    else
        fail "kubectl not found" "kubectl" \
            "brew install kubectl" "See https://kubernetes.io/docs/tasks/tools/"
    fi

    # Helm
    if command -v helm &>/dev/null; then
        local hv
        hv=$(helm version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
        local hmajor hminor
        hmajor=$(echo "$hv" | cut -d. -f1)
        hminor=$(echo "$hv" | cut -d. -f2)
        if [[ "$hmajor" -gt 3 ]] || { [[ "$hmajor" -eq 3 ]] && [[ "$hminor" -ge 10 ]]; }; then
            pass "Helm v${hv} (>= 3.10 required)" "Helm"
        else
            fail "Helm v${hv} found, but >= 3.10 is required" "Helm" \
                "brew upgrade helm" "See https://helm.sh/docs/intro/install/"
        fi
    else
        fail "Helm not found" "Helm" \
            "brew install helm" "See https://helm.sh/docs/intro/install/"
    fi

    # Cluster connectivity
    if command -v kubectl &>/dev/null; then
        if kubectl cluster-info &>/dev/null; then
            local ctx
            ctx=$(kubectl config current-context 2>/dev/null)
            pass "kubectl connected to cluster (context: ${ctx})" "Cluster"
        else
            fail "kubectl cannot reach cluster" "Cluster" \
                "Check kubeconfig" "Check kubeconfig"
        fi
    fi

    # K8s server version (>= 1.25 recommended)
    if command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null; then
        local server_ver
        server_ver=$(kubectl version -o json 2>/dev/null | python3 -c \
            "import sys,json; v=json.load(sys.stdin).get('serverVersion',{}); print(v.get('major','0')+'.'+v.get('minor','0').rstrip('+'))" 2>/dev/null || echo "")
        if [[ -n "$server_ver" ]]; then
            local sv_major sv_minor
            sv_major=$(echo "$server_ver" | cut -d. -f1)
            sv_minor=$(echo "$server_ver" | cut -d. -f2)
            if [[ "$sv_major" -gt 1 ]] || { [[ "$sv_major" -eq 1 ]] && [[ "$sv_minor" -ge 25 ]]; }; then
                pass "K8s server v${server_ver} (>= 1.25 recommended)" "K8s Version"
            else
                warn "K8s server v${server_ver} — older than 1.25, some features may not work" "K8s Version" \
                    "Upgrade cluster" "Upgrade cluster"
            fi
        fi
    fi

    # RBAC — Shield helm chart creates cluster-scoped resources
    if command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null; then
        local rbac_ok=true
        # Namespace-scoped: deployments, daemonsets, secrets
        kubectl auth can-i create deployments -n sysdig-agent &>/dev/null || rbac_ok=false
        kubectl auth can-i create daemonsets -n sysdig-agent &>/dev/null || rbac_ok=false
        # Cluster-scoped: clusterroles, clusterrolebindings (created by the chart)
        kubectl auth can-i create clusterroles &>/dev/null || rbac_ok=false
        kubectl auth can-i create clusterrolebindings &>/dev/null || rbac_ok=false
        if [[ "$rbac_ok" == "true" ]]; then
            pass "RBAC: can create namespace and cluster-scoped resources" "RBAC"
        else
            fail "RBAC: insufficient permissions. Shield needs cluster-admin or equivalent (creates ClusterRole, ClusterRoleBinding, DaemonSet)" "RBAC" \
                "kubectl create clusterrolebinding admin --clusterrole=cluster-admin --user=\$(kubectl config current-context)" \
                "kubectl create clusterrolebinding admin --clusterrole=cluster-admin --user=\$(kubectl config current-context)"
        fi
    fi

    # Helm repo — is sysdig repo configured?
    if command -v helm &>/dev/null; then
        if helm repo list 2>/dev/null | grep -q sysdig; then
            pass "Sysdig Helm repo configured" "Helm Repo"
        else
            warn "Sysdig Helm repo not configured (will be added during install)" "Helm Repo" \
                "helm repo add sysdig https://charts.sysdig.com" \
                "helm repo add sysdig https://charts.sysdig.com"
        fi
    fi

    # Node resources — disk, CPU, memory
    if command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null; then
        # Check for DiskPressure on any node
        local disk_pressure
        disk_pressure=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .status.conditions[?(@.type=="DiskPressure")]}{.status}{end}{"\n"}{end}' 2>/dev/null | grep True || true)
        if [[ -n "$disk_pressure" ]]; then
            fail "DiskPressure detected on nodes: $(echo "$disk_pressure" | awk '{print $1}' | tr '\n' ', '). Shield images need ~1.5GB free disk." "Disk" \
                "Free disk or use larger nodes" "Free disk or use larger nodes"
        else
            # Check minimum ephemeral storage (need at least ~3GB free per node)
            # Values come as Ki (e.g., "59846508Ki") — convert to GB
            local min_storage_ki
            min_storage_ki=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.allocatable.ephemeral-storage}{"\n"}{end}' 2>/dev/null \
                | sed 's/Ki$//' | sort -n | head -1)
            if [[ -n "$min_storage_ki" ]] && [[ "$min_storage_ki" =~ ^[0-9]+$ ]]; then
                local min_gb=$(( min_storage_ki / 1048576 ))  # Ki to GB: divide by 1024*1024
                if [[ "$min_gb" -lt 3 ]]; then
                    warn "Smallest node has ~${min_gb}GB ephemeral storage. Shield needs ~1.5GB for images; recommend >= 10GB." "Disk" \
                        "Use larger nodes" "Use larger nodes"
                else
                    pass "Node disk: smallest node has ~${min_gb}GB ephemeral storage" "Disk"
                fi
            fi
        fi
    fi

    # Existing installation check
    if command -v helm &>/dev/null && kubectl cluster-info &>/dev/null; then
        local existing
        existing=$(helm list -n sysdig-agent -q 2>/dev/null)
        if [[ -n "$existing" ]]; then
            warn "Existing Helm release found in sysdig-agent: ${existing} (upgrade, not fresh install)" "Existing Install" \
                "" ""
        fi
    fi
}

check_host() {
    [[ "$JSON_MODE" != "true" ]] && echo "" && echo "Host:"
    local kver
    kver=$(uname -r | grep -oE '^[0-9]+\.[0-9]+')
    local kmajor kminor
    kmajor=$(echo "$kver" | cut -d. -f1)
    kminor=$(echo "$kver" | cut -d. -f2)
    if [[ "$kmajor" -gt 3 ]] || { [[ "$kmajor" -eq 3 ]] && [[ "$kminor" -ge 10 ]]; }; then
        pass "Kernel $(uname -r) (>= 3.10 required)" "Kernel"
    else
        fail "Kernel $(uname -r) — version 3.10+ required for eBPF" "Kernel" \
            "Upgrade kernel" "Upgrade kernel"
    fi

    if [[ $EUID -eq 0 ]]; then
        pass "Running as root" "Root Access"
    else
        warn "Not running as root. Agent installation may require sudo." "Root Access" \
            "sudo -i" "sudo -i"
    fi
}

# --- Main ---

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <type> [--json] [--aws-profile NAME]"
    echo "  type: aws | gcp | azure | kubernetes | host"
    echo "  --json: output structured JSON"
    echo "  --aws-profile NAME: use a specific AWS CLI profile"
    exit 1
fi

TYPE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true ;;
        --aws-profile)
            shift
            AWS_PROFILE_ARG="${1:-}"
            if [[ -z "$AWS_PROFILE_ARG" ]]; then
                echo "Error: --aws-profile requires a profile name"
                exit 1
            fi
            ;;
        -*) echo "Unknown option: $1"; exit 1 ;;
        *) [[ -z "$TYPE" ]] && TYPE="$1" ;;
    esac
    shift
done

if [[ -z "$TYPE" ]]; then
    echo "Error: type argument is required"
    exit 1
fi

# Apply AWS profile if specified
if [[ -n "$AWS_PROFILE_ARG" ]]; then
    export AWS_PROFILE="$AWS_PROFILE_ARG"
fi

if [[ "$JSON_MODE" != "true" ]]; then
    echo "========================================"
    echo " Sysdig Onboarding Prerequisites Check"
    echo " Type: ${TYPE}"
    [[ -n "$AWS_PROFILE_ARG" ]] && echo " AWS Profile: ${AWS_PROFILE_ARG}"
    echo "========================================"
fi

case "$TYPE" in
    aws)
        check_terraform
        check_aws
        ;;
    gcp)
        check_terraform
        check_gcp
        ;;
    azure)
        check_terraform
        check_azure
        ;;
    kubernetes)
        check_kubernetes
        ;;
    host)
        check_host
        ;;
    *)
        echo "Unknown type: $TYPE"
        echo "Valid types: aws, gcp, azure, kubernetes, host"
        exit 1
        ;;
esac

if [[ "$JSON_MODE" == "true" ]]; then
    profile_json=""
    [[ -n "$AWS_PROFILE_ARG" ]] && profile_json="$(printf ',"aws_profile":"%s"' "$AWS_PROFILE_ARG")"
    printf '{"type":"%s"%s,"checks":[%s],"summary":{"pass":%d,"fail":%d}}\n' \
        "$TYPE" "$profile_json" "$JSON_CHECKS" "$PASS" "$FAIL"
else
    echo ""
    echo "========================================"
    echo -e " Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
    echo "========================================"
fi

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
