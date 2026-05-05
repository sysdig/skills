#!/usr/bin/env bash
# check_permissions.sh — Pre-flight permission check for Sysdig cloud onboarding
#
# Validates that the current identity has the required permissions BEFORE
# running terraform apply, to catch permission issues early.
#
# Usage: check_permissions.sh <provider> [scope] [features]
#   provider: aws | gcp | azure
#   scope:    single | organization (default: single)
#   features: comma-separated list (default: cspm)
#             valid: cspm, cdr, cdr_cloudlogs, ciem, vm
#
# Examples:
#   check_permissions.sh aws single cspm,cdr
#   check_permissions.sh aws single cspm,cdr_cloudlogs  # CloudTrail/S3 CDR mode
#   check_permissions.sh gcp organization cspm,cdr,vm
#   check_permissions.sh azure tenant cspm
#
# Exit codes:
#   0 — All checks passed
#   1 — One or more checks failed (permission missing)
#   2 — Check could not be performed (tool missing, not authenticated)
#
# NOTE: This script checks permissions based on documented requirements.
# Documentation may be incomplete or outdated. If terraform apply fails with
# a permission error not caught by this script, please add the missing
# permission to references/known-issues.md and update this script.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
SIMULATE_AVAILABLE=true
IS_ASSUMED_ROLE=false
IS_ORG_MEMBER=false
SIMULATE_FAILURES=0
SIMULATE_CIRCUIT_BROKEN=false
AWS_PROFILE_ARG=""

pass() { echo -e "  ${GREEN}✓${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $*"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}!${NC} $*"; WARN=$((WARN + 1)); }
info() { echo -e "  ${BLUE}ℹ${NC} $*"; }

# ---------------------------------------------------------------------------
# AWS Fallback: identity detection and service-level probes
# ---------------------------------------------------------------------------

# Detect if the current identity is an assumed role (e.g., cross-account)
detect_identity_type() {
    local arn="$1"
    if [[ "$arn" == *":assumed-role/"* ]]; then
        IS_ASSUMED_ROLE=true
    fi
}

# Convert an assumed-role ARN to the IAM role ARN format.
# SimulatePrincipalPolicy requires the IAM role ARN, not the STS session ARN.
#   STS format: arn:aws:sts::123456789012:assumed-role/MyRole/session-name
#   IAM format: arn:aws:iam::123456789012:role/MyRole
convert_to_iam_role_arn() {
    local arn="$1"
    if [[ "$arn" == *":assumed-role/"* ]]; then
        local account role_name
        account=$(echo "$arn" | cut -d: -f5)
        role_name=$(echo "$arn" | sed 's|.*:assumed-role/||; s|/.*||')
        echo "arn:aws:iam::${account}:role/${role_name}"
    else
        echo "$arn"
    fi
}

# Test whether SimulatePrincipalPolicy is available for this identity.
# Uses iam:ListRoles (a real IAM action) and verifies the result is parseable.
# sts:GetCallerIdentity is always "allowed" in simulation, so it's useless here.
test_simulate_availability() {
    local principal="$1"
    local result
    result=$(aws iam simulate-principal-policy \
        --policy-source-arn "$principal" \
        --action-names "iam:ListRoles" \
        --query 'EvaluationResults[0].EvalDecision' \
        --output text 2>/dev/null) || return 1
    # Verify we got a real decision, not empty or error
    [[ "$result" == "allowed" || "$result" == "implicitDeny" || "$result" == "explicitDeny" ]]
}

# Run a read-only AWS API call and classify the result:
#   pass  — call succeeds or returns "resource not found" (service accessible)
#   fail  — AccessDenied with "service control policy" mention (SCP block)
#   fail  — AccessDenied without SCP mention (IAM block)
#   warn  — any other error (inconclusive)
probe_aws_service() {
    local service_label="$1"
    shift
    local cmd=("$@")

    local output exit_code
    output=$("${cmd[@]}" 2>&1) && exit_code=0 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "${service_label} — service accessible"
        return
    fi

    # Check for known "not found" patterns (means the call reached the service)
    if echo "$output" | grep -qi "NoSuchEntity\|NotFoundException\|not found\|does not exist\|ResourceNotFoundException"; then
        pass "${service_label} — service accessible (resource not found, expected)"
        return
    fi

    # Check for AccessDenied with SCP mention
    if echo "$output" | grep -qi "AccessDenied\|UnauthorizedAccess\|AccessDeniedException"; then
        if echo "$output" | grep -qi "service control policy"; then
            fail "${service_label} — blocked by SCP (service control policy)"
        else
            fail "${service_label} — access denied (IAM or SCP)"
        fi
        return
    fi

    # Any other error — inconclusive
    warn "${service_label} — probe inconclusive (${output:0:120})"
}

# Fallback permission check using service-level probes.
# Called when SimulatePrincipalPolicy is not available.
check_aws_permissions_fallback() {
    local scope="$1"
    local features="$2"

    echo ""
    echo "  Fallback mode: testing service-level access (reduced granularity)"
    echo ""

    # --- Always required: IAM ---
    echo "  Onboarding (always required):"
    local probe_ts
    probe_ts=$(date +%s)
    probe_aws_service "IAM" \
        aws iam get-role --role-name "sysdig-nonexistent-probe-${probe_ts}"

    # --- Organization-specific ---
    if [[ "$scope" == "organization" ]]; then
        echo ""
        echo "  Organization scope:"
        probe_aws_service "Organizations" \
            aws organizations list-roots --max-items 1
        probe_aws_service "CloudFormation (StackSets)" \
            aws cloudformation list-stack-sets --max-results 1
    fi

    # --- CDR (EventBridge) ---
    if [[ "$features" == *"cdr"* ]] && [[ "$features" != *"cdr_cloudlogs"* ]]; then
        echo ""
        echo "  CDR (EventBridge):"
        probe_aws_service "EventBridge" \
            aws events list-rules --limit 1
        probe_aws_service "SQS" \
            aws sqs list-queues --max-results 1
    fi

    # --- CDR (CloudTrail/S3 — cloud-logs) ---
    if [[ "$features" == *"cdr_cloudlogs"* ]]; then
        echo ""
        echo "  CDR (CloudTrail/S3 — cloud-logs):"
        probe_aws_service "S3" \
            aws s3api list-buckets --max-buckets 1
        probe_aws_service "SNS" \
            aws sns list-topics
    fi

    # --- VM (Agentless Scanning) ---
    if [[ "$features" == *"vm"* ]]; then
        echo ""
        echo "  Vulnerability Management (Agentless Scanning):"
        probe_aws_service "EC2 (Snapshots)" \
            aws ec2 describe-snapshots --owner-ids self --max-results 1
        probe_aws_service "KMS" \
            aws kms list-keys --limit 1
    fi

    # --- Org member SCP warning ---
    if [[ "$IS_ORG_MEMBER" == "true" ]]; then
        echo ""
        warn "Running from an organization member account. Service-level probes" \
             "confirm basic access but CANNOT detect action-level SCP restrictions" \
             "(e.g., an SCP blocking events:PutRule but allowing events:ListRules)." \
             "If terraform apply fails with an SCP error, see" \
             "references/troubleshooting.md for remediation steps."
    fi
}

# ---------------------------------------------------------------------------
# AWS Permission Checks
# ---------------------------------------------------------------------------
check_aws_permissions() {
    local scope="${1:-single}"
    local features="${2:-cspm}"

    echo ""
    echo "AWS Permission Check (scope: ${scope}, features: ${features})"
    echo "---"

    # Get caller identity
    local caller_arn
    caller_arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null) || {
        fail "Cannot determine AWS caller identity. Are you authenticated?"
        return
    }
    info "Identity: ${caller_arn}"

    # Detect if running from the AWS Organization management account
    # Management accounts are exempt from SCPs — simulate-principal-policy
    # incorrectly reports SCP denials for them (known false positive)
    local master_account
    master_account=$(aws organizations describe-organization \
        --query Organization.MasterAccountId --output text 2>/dev/null) || master_account=""
    IS_MANAGEMENT_ACCOUNT=false
    local caller_account
    caller_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    if [[ -n "$master_account" && "$caller_account" == "$master_account" ]]; then
        IS_MANAGEMENT_ACCOUNT=true
        warn "Running from the Organization management account. SCPs do NOT apply to" \
             "management accounts at runtime — SCP-related pre-flight denials will" \
             "be shown as warnings, not failures."
    fi

    # Detect identity type and org membership
    detect_identity_type "$caller_arn"
    if [[ -n "$master_account" && "$caller_account" != "$master_account" ]]; then
        IS_ORG_MEMBER=true
    fi

    # Convert assumed-role ARN to IAM role ARN for SimulatePrincipalPolicy
    local simulate_arn="$caller_arn"
    if [[ "$IS_ASSUMED_ROLE" == "true" ]]; then
        simulate_arn=$(convert_to_iam_role_arn "$caller_arn")
        info "Assumed role detected — using IAM role ARN for simulation: ${simulate_arn}"
    fi

    # Test if SimulatePrincipalPolicy is available
    if ! test_simulate_availability "$simulate_arn"; then
        SIMULATE_AVAILABLE=false
        if [[ "$IS_ASSUMED_ROLE" == "true" ]]; then
            warn "SimulatePrincipalPolicy unavailable (common for cross-account assumed roles)." \
                 "Falling back to service-level probes."
        else
            warn "SimulatePrincipalPolicy unavailable. Falling back to service-level probes."
        fi
        check_aws_permissions_fallback "$scope" "$features"
        return
    fi

    # Use simulate-principal-policy to test permissions
    # This is the most reliable way to check without actually creating resources

    # --- Always required: IAM permissions for onboarding ---
    echo ""
    echo "  Onboarding (always required):"
    local iam_actions=("iam:CreateRole" "iam:AttachRolePolicy" "iam:PutRolePolicy"
                       "iam:CreatePolicy" "iam:TagRole" "iam:GetRole"
                       "iam:ListAttachedRolePolicies" "iam:ListRolePolicies")

    for action in "${iam_actions[@]}"; do
        check_aws_action "$simulate_arn" "$action"
    done

    # --- Organization-specific ---
    if [[ "$scope" == "organization" ]]; then
        echo ""
        echo "  Organization scope:"
        local org_actions=("organizations:ListAccounts" "organizations:DescribeOrganization"
                           "organizations:ListRoots" "organizations:ListOrganizationalUnitsForParent")
        for action in "${org_actions[@]}"; do
            check_aws_action "$simulate_arn" "$action"
        done

        local cfn_actions=("cloudformation:CreateStackSet" "cloudformation:CreateStackInstances"
                           "cloudformation:DescribeStackSet" "cloudformation:ListStackInstances")
        for action in "${cfn_actions[@]}"; do
            check_aws_action "$simulate_arn" "$action"
        done

        # Check CloudFormation Organizations Access (required for SERVICE_MANAGED StackSets)
        echo ""
        echo "  CloudFormation Organizations Access:"
        local cfn_org_status
        cfn_org_status=$(aws cloudformation describe-organizations-access \
            --call-as SELF --query Status --output text 2>/dev/null) || cfn_org_status=""

        if [[ "$cfn_org_status" == "ENABLED" ]]; then
            pass "CloudFormation Organizations Access is enabled"
        elif [[ "$cfn_org_status" == "DISABLED" ]]; then
            fail "CloudFormation Organizations Access is disabled"
            info "Run: aws cloudformation activate-organizations-access"
            info "Also run: aws organizations enable-aws-service-access --service-principal member.org.stacksets.cloudformation.amazonaws.com"
        else
            warn "Could not determine CloudFormation Organizations Access status"
            info "Verify manually: aws cloudformation describe-organizations-access --call-as SELF"
            info "If disabled, run: aws cloudformation activate-organizations-access"
        fi
    fi

    # --- CDR (EventBridge) ---
    if [[ "$features" == *"cdr"* ]] && [[ "$features" != *"cdr_cloudlogs"* ]]; then
        echo ""
        echo "  CDR (EventBridge):"
        local cdr_actions=("events:PutRule" "events:PutTargets" "events:DescribeRule"
                           "events:ListTargetsByRule" "events:DeleteRule"
                           "sqs:CreateQueue" "sqs:GetQueueAttributes")
        for action in "${cdr_actions[@]}"; do
            check_aws_action "$simulate_arn" "$action"
        done
    fi

    # --- CDR (CloudTrail/S3 — cloud-logs) ---
    if [[ "$features" == *"cdr_cloudlogs"* ]]; then
        echo ""
        echo "  CDR (CloudTrail/S3 — cloud-logs):"
        local cdr_cl_actions=("s3:GetBucketAcl" "s3:GetObject" "s3:ListBucket"
                              "sns:Subscribe" "sns:GetTopicAttributes"
                              "iam:CreateRole" "iam:PutRolePolicy")
        for action in "${cdr_cl_actions[@]}"; do
            check_aws_action "$simulate_arn" "$action"
        done
        # SNS CreateTopic only needed if create_topic=true
        info "sns:CreateTopic — needed only if creating a new SNS topic (create_topic=true)"
        check_aws_action "$simulate_arn" "sns:CreateTopic"
    fi

    # --- VM (Agentless Scanning) ---
    if [[ "$features" == *"vm"* ]]; then
        echo ""
        echo "  Vulnerability Management (Agentless Scanning):"
        local vm_actions=("ec2:DescribeSnapshots" "ec2:DescribeVolumes"
                          "kms:CreateKey" "kms:CreateAlias" "kms:DescribeKey")
        for action in "${vm_actions[@]}"; do
            check_aws_action "$simulate_arn" "$action"
        done
    fi

    # --- Circuit breaker fallback ---
    if [[ "$SIMULATE_CIRCUIT_BROKEN" == "true" ]]; then
        SIMULATE_AVAILABLE=false
        echo ""
        warn "Simulation failed repeatedly — re-running checks with service-level probes"
        check_aws_permissions_fallback "$scope" "$features"
    fi
}

check_aws_action() {
    local principal="$1"
    local action="$2"

    # Circuit breaker: if too many consecutive simulation failures, skip
    if [[ "$SIMULATE_CIRCUIT_BROKEN" == "true" ]]; then
        return
    fi

    # Fetch both EvalDecision and OrganizationsDecisionDetail in one call
    local eval_result
    eval_result=$(aws iam simulate-principal-policy \
        --policy-source-arn "$principal" \
        --action-names "$action" \
        --query 'EvaluationResults[0].{Decision:EvalDecision,AllowedByOrg:OrganizationsDecisionDetail.AllowedByOrganizations}' \
        --output json 2>/dev/null) || {
        SIMULATE_FAILURES=$((SIMULATE_FAILURES + 1))
        if [[ $SIMULATE_FAILURES -ge 3 ]]; then
            SIMULATE_CIRCUIT_BROKEN=true
            warn "${action} — could not simulate (3 consecutive failures, switching to fallback)"
        else
            warn "${action} — could not simulate (may lack iam:SimulatePrincipalPolicy)"
        fi
        return
    }
    # Reset failure counter on success
    SIMULATE_FAILURES=0

    local decision allowed_by_org
    decision=$(echo "$eval_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Decision','unknown'))" 2>/dev/null)
    allowed_by_org=$(echo "$eval_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('AllowedByOrg','None'))" 2>/dev/null)

    if [[ "$decision" == "allowed" ]]; then
        pass "${action}"
    elif [[ "$IS_MANAGEMENT_ACCOUNT" == "true" && "$allowed_by_org" == "False" ]]; then
        warn "${action} — blocked by SCP (${decision}), but management accounts" \
             "are exempt from SCPs at runtime — this is a known false positive"
    else
        fail "${action} — ${decision}"
    fi
}

# ---------------------------------------------------------------------------
# GCP Permission Checks
# ---------------------------------------------------------------------------
check_gcp_permissions() {
    local scope="${1:-single}"
    local features="${2:-cspm}"

    echo ""
    echo "GCP Permission Check (scope: ${scope}, features: ${features})"
    echo "---"

    # Get current project
    local project
    project=$(gcloud config get-value project 2>/dev/null) || {
        fail "Cannot determine GCP project. Run 'gcloud config set project PROJECT_ID'"
        return
    }
    if [[ -z "$project" || "$project" == "(unset)" ]]; then
        fail "No GCP project set. Run 'gcloud config set project PROJECT_ID'"
        return
    fi
    info "Project: ${project}"

    local account
    account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
    info "Identity: ${account}"

    # Use testIamPermissions to check project-level permissions
    echo ""
    echo "  Onboarding (always required):"
    local onboarding_perms=(
        "iam.serviceAccounts.create"
        "iam.serviceAccounts.delete"
        "iam.serviceAccounts.get"
        "iam.roles.create"
        "iam.roles.update"
        "resourcemanager.projects.getIamPolicy"
        "resourcemanager.projects.setIamPolicy"
        "iam.serviceAccountKeys.create"
        "serviceusage.services.enable"
        "iam.workloadIdentityPools.create"
        "iam.workloadIdentityPoolProviders.create"
    )

    check_gcp_project_permissions "$project" "${onboarding_perms[@]}"

    # --- Organization-specific ---
    if [[ "$scope" == "organization" ]]; then
        echo ""
        echo "  Organization scope:"
        warn "Organization-level permissions require 'roles/iam.organizationRoleAdmin' and 'roles/resourcemanager.organizationAdmin'"
        warn "These cannot be tested at project level — verify manually in GCP Console > IAM"
    fi

    # --- CDR (Pub/Sub) ---
    if [[ "$features" == *"cdr"* ]]; then
        echo ""
        echo "  CDR (Pub/Sub):"
        local cdr_perms=(
            "pubsub.topics.create"
            "pubsub.subscriptions.create"
            "logging.sinks.create"
        )
        check_gcp_project_permissions "$project" "${cdr_perms[@]}"
    fi

    # --- VM (Agentless Scanning) ---
    if [[ "$features" == *"vm"* ]]; then
        echo ""
        echo "  Vulnerability Management (Agentless Scanning):"
        local vm_perms=(
            "compute.snapshots.create"
            "compute.disks.create"
        )
        check_gcp_project_permissions "$project" "${vm_perms[@]}"
    fi
}

check_gcp_project_permissions() {
    local project="$1"
    shift
    local permissions=("$@")

    # Build the permissions JSON array
    local perms_json
    perms_json=$(printf '"%s",' "${permissions[@]}")
    perms_json="[${perms_json%,}]"

    local result
    result=$(gcloud projects test-iam-permissions "$project" \
        --permissions="$(IFS=,; echo "${permissions[*]}")" \
        --format=json 2>/dev/null) || {
        warn "Could not test permissions on project ${project}"
        return
    }

    for perm in "${permissions[@]}"; do
        if echo "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
granted = data.get('permissions', [])
sys.exit(0 if '$perm' in granted else 1)
" 2>/dev/null; then
            pass "${perm}"
        else
            fail "${perm}"
        fi
    done
}

# ---------------------------------------------------------------------------
# Azure Permission Checks
# ---------------------------------------------------------------------------
check_azure_permissions() {
    local scope="${1:-single}"
    local features="${2:-cspm}"

    echo ""
    echo "Azure Permission Check (scope: ${scope}, features: ${features})"
    echo "---"

    # Get current context
    local sub_name sub_id tenant_id
    sub_name=$(az account show --query name --output tsv 2>/dev/null) || {
        fail "Cannot determine Azure subscription. Run 'az login'"
        return
    }
    sub_id=$(az account show --query id --output tsv 2>/dev/null)
    tenant_id=$(az account show --query tenantId --output tsv 2>/dev/null)
    info "Subscription: ${sub_name} (${sub_id})"
    info "Tenant: ${tenant_id}"

    # Get current user's object ID
    local user_id
    user_id=$(az ad signed-in-user show --query id --output tsv 2>/dev/null) || {
        warn "Cannot get signed-in user info. Some Entra ID checks will be skipped."
    }

    # Check Azure RBAC role assignments
    echo ""
    echo "  Azure RBAC Roles:"

    local roles
    roles=$(az role assignment list --assignee "${user_id:-unknown}" \
        --scope "/subscriptions/${sub_id}" \
        --query "[].roleDefinitionName" --output tsv 2>/dev/null) || {
        warn "Cannot list role assignments."
        roles=""
    }

    # Check for User Access Administrator
    if echo "$roles" | grep -qi "User Access Administrator"; then
        pass "User Access Administrator (RBAC)"
    else
        # Also check at management group level
        local mg_roles
        mg_roles=$(az role assignment list --assignee "${user_id:-unknown}" \
            --all --query "[].roleDefinitionName" --output tsv 2>/dev/null) || mg_roles=""
        if echo "$mg_roles" | grep -qi "User Access Administrator"; then
            pass "User Access Administrator (inherited from management group)"
        else
            fail "User Access Administrator — not found on subscription or management group"
        fi
    fi

    # Check for Contributor (needed for CDR, CIEM, VM)
    if [[ "$features" == *"cdr"* ]] || [[ "$features" == *"ciem"* ]] || [[ "$features" == *"vm"* ]]; then
        if echo "$roles" | grep -qi "^Contributor$"; then
            pass "Contributor (RBAC) — needed for CDR/CIEM/VM"
        elif echo "$roles" | grep -qi "^Owner$"; then
            pass "Owner (RBAC) — includes Contributor permissions"
        else
            fail "Contributor — not found (required for CDR, CIEM, or VM features)"
        fi
    fi

    # Check Entra ID roles
    echo ""
    echo "  Entra ID Roles:"

    # Check for Application Administrator
    local app_admin
    app_admin=$(az rest --method GET \
        --url "https://graph.microsoft.com/v1.0/me/transitiveMemberOf?%24filter=displayName%20eq%20'Application%20Administrator'" \
        --headers "ConsistencyLevel=eventual" \
        --query "value | length(@)" --output tsv 2>/dev/null) || app_admin=""

    if [[ "$app_admin" -gt 0 ]] 2>/dev/null; then
        pass "Application Administrator (Entra ID)"
    else
        warn "Application Administrator — could not verify (check manually in Entra ID > Roles)"
    fi

    # Check for Privileged Role Administrator
    local priv_admin
    priv_admin=$(az rest --method GET \
        --url "https://graph.microsoft.com/v1.0/me/transitiveMemberOf?%24filter=displayName%20eq%20'Privileged%20Role%20Administrator'" \
        --headers "ConsistencyLevel=eventual" \
        --query "value | length(@)" --output tsv 2>/dev/null) || priv_admin=""

    if [[ "$priv_admin" -gt 0 ]] 2>/dev/null; then
        pass "Privileged Role Administrator (Entra ID)"
    else
        warn "Privileged Role Administrator — could not verify (check manually in Entra ID > Roles)"
    fi

    info "Entra ID role checks use Graph API and may show warnings if permissions are insufficient."
    info "If warnings appear, verify roles manually: Azure Portal > Entra ID > Roles and Administrators"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <provider> [scope] [features] [--aws-profile NAME]"
    echo "  provider: aws | gcp | azure"
    echo "  scope:    single | organization | tenant (default: single)"
    echo "  features: comma-separated (default: cspm)"
    echo "            valid: cspm, cdr, cdr_cloudlogs, ciem, vm"
    echo "            cdr = EventBridge mode, cdr_cloudlogs = CloudTrail/S3 mode"
    echo "  --aws-profile NAME: use a specific AWS CLI profile"
    echo ""
    echo "Examples:"
    echo "  $0 aws single cspm,cdr"
    echo "  $0 aws single cspm,cdr_cloudlogs"
    echo "  $0 aws single cspm,cdr --aws-profile myprofile"
    echo "  $0 gcp organization cspm,cdr,vm"
    echo "  $0 azure tenant cspm"
    exit 1
fi

# Parse arguments: positional (provider, scope, features) + optional --aws-profile
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --aws-profile)
            shift
            AWS_PROFILE_ARG="${1:-}"
            if [[ -z "$AWS_PROFILE_ARG" ]]; then
                echo "Error: --aws-profile requires a profile name"
                exit 1
            fi
            ;;
        -*) echo "Unknown option: $1"; exit 1 ;;
        *) POSITIONAL+=("$1") ;;
    esac
    shift
done

PROVIDER="${POSITIONAL[0]:-}"
SCOPE="${POSITIONAL[1]:-single}"
FEATURES="${POSITIONAL[2]:-cspm}"

if [[ -z "$PROVIDER" ]]; then
    echo "Error: provider argument is required"
    exit 1
fi

# Apply AWS profile if specified
if [[ -n "$AWS_PROFILE_ARG" ]]; then
    export AWS_PROFILE="$AWS_PROFILE_ARG"
fi

echo "========================================"
echo " Sysdig Onboarding Permission Pre-Flight"
echo " Provider: ${PROVIDER}"
echo " Scope:    ${SCOPE}"
echo " Features: ${FEATURES}"
[[ -n "$AWS_PROFILE_ARG" ]] && echo " AWS Profile: ${AWS_PROFILE_ARG}"
echo "========================================"

case "$PROVIDER" in
    aws)    check_aws_permissions "$SCOPE" "$FEATURES" ;;
    gcp)    check_gcp_permissions "$SCOPE" "$FEATURES" ;;
    azure)  check_azure_permissions "$SCOPE" "$FEATURES" ;;
    *)
        echo "Unknown provider: $PROVIDER"
        echo "Valid providers: aws, gcp, azure"
        exit 1
        ;;
esac

echo ""
echo "========================================"
if [[ "$SIMULATE_AVAILABLE" == "false" ]]; then
    echo -e " Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}" \
         "(service-level probes — action-level accuracy not available)"
else
    echo -e " Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
fi
echo "========================================"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "Some permissions are missing. Fix them before running 'terraform apply'."
    echo "See the provider reference in references/${PROVIDER}.md for details."
    if [[ "$IS_ORG_MEMBER" == "true" ]]; then
        echo ""
        echo "NOTE: Some failures may be caused by organizational SCPs."
        echo "If terraform apply fails with 'explicit deny in a service control policy',"
        echo "see references/troubleshooting.md for SCP remediation steps."
    fi
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo ""
    echo "Some checks could not be verified. Review warnings above."
    echo "You may proceed, but watch for permission errors during apply."
    if [[ "$IS_ORG_MEMBER" == "true" && "$SIMULATE_AVAILABLE" == "false" ]]; then
        echo ""
        echo "NOTE: Service-level probes cannot detect action-level SCP restrictions."
        echo "If terraform apply fails with an SCP error, see"
        echo "references/troubleshooting.md for remediation steps."
    fi
    exit 0
else
    echo ""
    echo "All permission checks passed. You are ready for 'terraform apply'."
    exit 0
fi
