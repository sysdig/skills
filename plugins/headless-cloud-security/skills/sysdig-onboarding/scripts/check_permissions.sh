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
#             valid: cspm, cdr, cdr_cloudlogs, ciem, vm,
#                    workload_scanning
#
# Examples:
#   check_permissions.sh aws single cspm,cdr
#   check_permissions.sh aws single cspm,cdr_cloudlogs  # CloudTrail/S3 CDR mode
#   check_permissions.sh aws single cspm,vm,workload_scanning
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
IS_MANAGEMENT_ACCOUNT=false
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
    if echo "$output" | grep -qi "NoSuchEntity\|NotFoundException\|not found\|does not exist\|ResourceNotFoundException\|NonExistentQueue"; then
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
        # Probe with read actions that ARE in the onboarding policy set
        # (events:DescribeRule, sqs:GetQueueAttributes) rather than broad list
        # actions (events:ListRules, sqs:ListQueues) the least-privilege policy
        # intentionally omits — those return AccessDenied for an identity that can
        # actually onboard, producing false failures. Nonexistent resources yield
        # a "not found" (probe passes) when the action is permitted.
        probe_aws_service "EventBridge" \
            aws events describe-rule --name "sysdig-nonexistent-probe-${probe_ts}"
        local sqs_region sqs_acct
        sqs_region=$(aws configure get region 2>/dev/null || echo "${AWS_REGION:-${AWS_DEFAULT_REGION:-}}")
        sqs_acct=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || sqs_acct=""
        if [[ -n "$sqs_region" && -n "$sqs_acct" ]]; then
            probe_aws_service "SQS" \
                aws sqs get-queue-attributes \
                --queue-url "https://sqs.${sqs_region}.amazonaws.com/${sqs_acct}/sysdig-nonexistent-probe-${probe_ts}" \
                --attribute-names QueueArn
        else
            warn "SQS — cannot probe (region/account unresolved); sqs:CreateQueue" \
                 "is required for CDR. Ensure your identity can create SQS queues before apply."
        fi
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
        # EC2 requires --max-results >= 5 (a value of 1 throws InvalidParameterValue,
        # which the probe would misreport as "inconclusive"). ec2:DescribeSnapshots
        # is in the onboarding policy set.
        probe_aws_service "EC2 (Snapshots)" \
            aws ec2 describe-snapshots --owner-ids self --max-results 5
        # Probe kms:DescribeKey (in the onboarding policy set) against a nonexistent
        # alias rather than kms:ListKeys (which the least-privilege policy omits).
        probe_aws_service "KMS" \
            aws kms describe-key --key-id "alias/sysdig-nonexistent-probe-${probe_ts}"
    fi

    # --- Workload Scanning (ECS + Lambda) ---
    if [[ "$features" == *"workload_scanning"* ]]; then
        echo ""
        echo "  Workload Scanning (ECS + Lambda):"
        info "IAM role/policy creation (probed above)$([[ "$scope" == "organization" ]] && echo " + CloudFormation StackSets (probed under Organization scope)")"
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

    # Get caller identity — account and ARN in a single API call
    local identity caller_account caller_arn
    identity=$(aws sts get-caller-identity --query '[Account,Arn]' --output text 2>/dev/null) || {
        fail "Cannot determine AWS caller identity. Are you authenticated?"
        return
    }
    read -r caller_account caller_arn <<< "$identity" || true
    info "Identity: ${caller_arn}"

    # Detect if running from the AWS Organization management account
    # Management accounts are exempt from SCPs — simulate-principal-policy
    # incorrectly reports SCP denials for them (known false positive)
    local master_account
    master_account=$(aws organizations describe-organization \
        --query Organization.MasterAccountId --output text 2>/dev/null) || master_account=""
    IS_MANAGEMENT_ACCOUNT=false
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
    # This is the most reliable way to check without actually creating resources.
    # Actions are batched into ONE API call per section (not one per action).

    # --- Always required: IAM permissions for onboarding ---
    echo ""
    echo "  Onboarding (always required):"
    # NOTE: Sysdig modules always create resources WITH tags, so the "tag"
    # companion of every "create" action is a hard requirement — e.g.
    # vm-workload-scanning calls CreatePolicy with tags, which needs both
    # iam:CreatePolicy AND iam:TagPolicy. Probe the tag companions too,
    # otherwise a minimal policy missing them fails silently at apply time.
    local iam_actions=("iam:CreateRole" "iam:AttachRolePolicy" "iam:PutRolePolicy"
                       "iam:CreatePolicy" "iam:TagRole" "iam:TagPolicy" "iam:GetRole"
                       "iam:ListAttachedRolePolicies" "iam:ListRolePolicies")
    simulate_actions "$simulate_arn" "" "${iam_actions[@]}"

    # --- Organization-specific ---
    if [[ "$scope" == "organization" ]]; then
        echo ""
        echo "  Organization scope:"
        local org_actions=("organizations:ListAccounts" "organizations:DescribeOrganization"
                           "organizations:ListRoots" "organizations:ListOrganizationalUnitsForParent"
                           # CreateStackSet is called with tags -> cloudformation:TagResource is required
                           "cloudformation:CreateStackSet" "cloudformation:CreateStackInstances"
                           "cloudformation:TagResource"
                           "cloudformation:DescribeStackSet" "cloudformation:ListStackInstances")
        simulate_actions "$simulate_arn" "" "${org_actions[@]}"

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
        # The event-bridge module creates the rule and SQS queue with tags →
        # events:TagResource / sqs:TagQueue are required companions.
        local cdr_actions=("events:PutRule" "events:PutTargets" "events:DescribeRule"
                           "events:ListTargetsByRule" "events:DeleteRule" "events:TagResource"
                           "sqs:CreateQueue" "sqs:GetQueueAttributes" "sqs:TagQueue")
        simulate_actions "$simulate_arn" "" "${cdr_actions[@]}"
    fi

    # --- CDR (CloudTrail/S3 — cloud-logs) ---
    if [[ "$features" == *"cdr_cloudlogs"* ]]; then
        echo ""
        echo "  CDR (CloudTrail/S3 — cloud-logs):"
        # SNS CreateTopic only needed if create_topic=true
        info "sns:CreateTopic — needed only if creating a new SNS topic (create_topic=true)"
        local cdr_cl_actions=("s3:GetBucketAcl" "s3:GetObject" "s3:ListBucket"
                              "sns:Subscribe" "sns:GetTopicAttributes"
                              "iam:CreateRole" "iam:PutRolePolicy" "sns:CreateTopic")
        simulate_actions "$simulate_arn" "" "${cdr_cl_actions[@]}"
    fi

    # --- VM (Agentless Scanning) ---
    if [[ "$features" == *"vm"* ]]; then
        echo ""
        echo "  Vulnerability Management (Agentless Scanning):"
        # The agentless-scanning module creates the KMS key with tags →
        # kms:TagResource is a required companion to kms:CreateKey.
        local vm_actions=("ec2:DescribeSnapshots" "ec2:DescribeVolumes"
                          "kms:CreateKey" "kms:CreateAlias" "kms:DescribeKey" "kms:TagResource")
        simulate_actions "$simulate_arn" "" "${vm_actions[@]}"
    fi

    # --- Workload Scanning (ECS + Lambda) ---
    if [[ "$features" == *"workload_scanning"* ]]; then
        echo ""
        echo "  Workload Scanning (ECS + Lambda):"
        # The vm-workload-scanning module creates IAM roles/policies (covered by
        # the always-required IAM checks above). Organization scope additionally
        # uses CloudFormation StackSets (covered by the Organization scope checks).
        if [[ "$scope" == "organization" ]]; then
            info "IAM role/policy creation (checked above) + CloudFormation StackSets (checked under Organization scope)"
        else
            info "IAM role/policy creation only (checked above) — no additional services"
        fi
    fi

    # --- Circuit breaker fallback ---
    if [[ "$SIMULATE_CIRCUIT_BROKEN" == "true" ]]; then
        SIMULATE_AVAILABLE=false
        echo ""
        warn "Simulation failed repeatedly — re-running checks with service-level probes"
        check_aws_permissions_fallback "$scope" "$features"
    fi
}

# simulate_actions <principal> <soft_csv> <action> [action...]
# Simulate ALL given actions in a single SimulatePrincipalPolicy API call
# (one round-trip per section instead of one per action) and report a
# pass/fail/warn line per action.
# <soft_csv>: comma-separated actions whose non-allowed decision is reported
# as a WARNING instead of a hard failure — for actions that cannot be
# simulated accurately without a concrete resource ARN / request context
# (e.g. iam:PassRole, which least-privilege policies scope to a specific role
# with an iam:PassedToService condition that simulation against "*" can't model).
simulate_actions() {
    local principal="$1" soft_csv="$2"
    shift 2
    local actions=("$@")
    [[ ${#actions[@]} -eq 0 ]] && return 0

    # Circuit breaker: if simulation keeps failing, skip (fallback re-checks)
    if [[ "$SIMULATE_CIRCUIT_BROKEN" == "true" ]]; then
        return 0
    fi

    # One line per action: EvalActionName<TAB>EvalDecision<TAB>AllowedByOrganizations
    local results
    results=$(aws iam simulate-principal-policy \
        --policy-source-arn "$principal" \
        --action-names "${actions[@]}" \
        --query 'EvaluationResults[].[EvalActionName,EvalDecision,OrganizationsDecisionDetail.AllowedByOrganizations]' \
        --output text 2>/dev/null) || {
        SIMULATE_FAILURES=$((SIMULATE_FAILURES + 1))
        if [[ $SIMULATE_FAILURES -ge 2 ]]; then
            SIMULATE_CIRCUIT_BROKEN=true
            warn "could not simulate ${actions[*]} (repeated failures, switching to fallback)"
        else
            warn "could not simulate ${actions[*]} (may lack iam:SimulatePrincipalPolicy)"
        fi
        return 0
    }
    # Reset failure counter on success
    SIMULATE_FAILURES=0

    local action decision allowed_by_org
    while IFS=$'\t' read -r action decision allowed_by_org; do
        [[ -z "$action" ]] && continue
        if [[ "$decision" == "allowed" ]]; then
            pass "${action}"
        elif [[ "$IS_MANAGEMENT_ACCOUNT" == "true" && "$allowed_by_org" == "False" ]]; then
            warn "${action} — blocked by SCP (${decision}), but management accounts" \
                 "are exempt from SCPs at runtime — this is a known false positive"
        elif [[ "$IS_ORG_MEMBER" == "true" && "$decision" == "implicitDeny" && "$allowed_by_org" == "False" ]]; then
            # Member-account false negative: from a member account, simulate cannot
            # positively resolve the org's SCP allows (reading SCPs is a
            # management-account capability), so it folds AllowedByOrganizations=false
            # into EvalDecision=implicitDeny even when the identity can perform the
            # action at runtime. Mirror the management-account handling and downgrade
            # to a warning rather than a hard failure — member-account SCP simulation
            # is not reliable enough to fail-hard on.
            warn "${action} — ${decision}, but this is driven by OrganizationsDecisionDetail" \
                 "(AllowedByOrganizations=false). Member accounts cannot resolve org SCP allows" \
                 "via simulation, so this is likely a false negative. Confirm at apply time; if" \
                 "terraform apply fails with an SCP error, see references/troubleshooting.md"
        elif [[ ",${soft_csv}," == *",${action},"* ]]; then
            warn "${action} — ${decision} (simulated against all resources without" \
                 "request context; least-privilege policies that scope this to the" \
                 "execution role with iam:PassedToService=cloudformation.amazonaws.com" \
                 "will show this — confirm the role can be passed to CloudFormation)"
        else
            fail "${action} — ${decision}"
        fi
    done <<< "$results"
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
    account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null) || account=""
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

    # gcloud has NO `projects test-iam-permissions` subcommand — testIamPermissions
    # is only exposed on the Cloud Resource Manager REST API. Call it directly with
    # an access token; this evaluates EFFECTIVE permissions, including any granted
    # via group membership. (No jq dependency — grep the JSON, matching the script's
    # no-JSON-parser style.)
    local token
    token=$(gcloud auth print-access-token 2>/dev/null) || token=""
    if [[ -z "$token" ]]; then
        warn "Could not obtain a gcloud access token (run 'gcloud auth login'); skipping permission test on ${project}"
        return
    fi

    local perms_json resp granted
    perms_json=$(printf '"%s",' "${permissions[@]}")
    perms_json="[${perms_json%,}]"

    # The access token is passed via `-K`, reading a config file from a process
    # substitution pipe, instead of `-H` on the command line — a command line can
    # be inspected by other local processes for as long as the call runs. `printf`
    # is a bash builtin, so the token never lands in any process's arguments.
    # Same hardening as detect-region.sh and verify-cloud-status.sh.
    resp=$(curl -s -X POST \
        -K <(printf 'header = "Authorization: Bearer %s"\n' "$token") \
        -H "Content-Type: application/json" \
        "https://cloudresourcemanager.googleapis.com/v1/projects/${project}:testIamPermissions" \
        -d "{\"permissions\":${perms_json}}" 2>/dev/null) || {
        warn "Could not reach the Resource Manager API to test permissions on ${project}"
        return
    }

    if grep -q '"error"' <<< "$resp"; then
        local msg
        msg=$(grep -oE '"message"[[:space:]]*:[[:space:]]*"[^"]*"' <<< "$resp" | head -1 \
            | sed -E 's/.*"message"[[:space:]]*:[[:space:]]*"([^"]*)"/\1/')
        warn "Permission test failed on ${project}: ${msg:-unknown error}"
        return
    fi

    # Granted permission strings are dotted tokens (e.g. "iam.roles.create");
    # the "permissions" JSON key has no dot, so it is not matched.
    granted=$(grep -oE '"[a-z0-9_]+(\.[a-zA-Z0-9_]+)+"' <<< "$resp" | tr -d '"')

    local perm
    for perm in "${permissions[@]}"; do
        if grep -qxF "$perm" <<< "$granted"; then
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
    sub_id=$(az account show --query id --output tsv 2>/dev/null) || sub_id=""
    tenant_id=$(az account show --query tenantId --output tsv 2>/dev/null) || tenant_id=""
    info "Subscription: ${sub_name} (${sub_id})"
    info "Tenant: ${tenant_id}"

    # Get the current identity's object ID. 'az ad signed-in-user show' only
    # works for a delegated USER login; a non-interactive service-principal
    # login (az login --service-principal / ARM_CLIENT_ID env) returns no
    # signed-in user, so fall back to resolving the SP's own object id. Both
    # the RBAC (--assignee) and Entra (principalId eq) queries below accept an
    # SP object id, so this makes the preflight accurate for SP-based installs.
    local user_id
    user_id=$(az ad signed-in-user show --query id --output tsv 2>/dev/null) || user_id=""
    if [[ -z "$user_id" ]]; then
        local acct_type acct_name
        acct_type=$(az account show --query user.type --output tsv 2>/dev/null) || acct_type=""
        acct_name=$(az account show --query user.name --output tsv 2>/dev/null) || acct_name=""
        if [[ "$acct_type" == "servicePrincipal" && -n "$acct_name" ]]; then
            user_id=$(az ad sp show --id "$acct_name" --query id --output tsv 2>/dev/null) || user_id=""
            if [[ -n "$user_id" ]]; then
                info "Authenticated as a service principal (appId ${acct_name}); checking its role assignments."
            fi
        fi
        if [[ -z "$user_id" ]]; then
            warn "Cannot resolve the signed-in identity's object id. Some RBAC/Entra ID checks will be skipped."
        fi
    fi

    # Check Azure RBAC role assignments
    echo ""
    echo "  Azure RBAC Roles:"

    # Collect the identity's role assignments once, across every scope that can
    # grant the install the rights it needs. Two queries are required and their
    # flags are mutually exclusive in the Azure CLI:
    #   --all                            → assignments *under* the subscription
    #                                      (resource groups / resources)
    #   --scope <sub> --include-inherited → the subscription itself PLUS
    #                                      assignments inherited from a parent
    #                                      management group or the tenant root
    # Using only --all reports a false negative for an installer who holds Owner
    # or User Access Administrator at a management group, which blocks a
    # legitimate install.
    local sub_tree_roles inherited_roles all_roles
    sub_tree_roles=$(az role assignment list --assignee "${user_id:-unknown}" \
        --all --query "[].roleDefinitionName" --output tsv 2>/dev/null) || sub_tree_roles=""
    inherited_roles=$(az role assignment list --assignee "${user_id:-unknown}" \
        --scope "/subscriptions/${sub_id}" --include-inherited \
        --query "[].roleDefinitionName" --output tsv 2>/dev/null) || inherited_roles=""
    all_roles=$(printf '%s\n%s\n' "$sub_tree_roles" "$inherited_roles")
    if [[ -z "${sub_tree_roles}${inherited_roles}" ]]; then
        warn "Cannot list role assignments (no assignments returned, or the identity" \
             "lacks Microsoft.Authorization/roleAssignments/read). The RBAC checks below" \
             "may report false negatives."
    fi

    # Check for User Access Administrator
    if echo "$all_roles" | grep -qi "User Access Administrator"; then
        pass "User Access Administrator (RBAC)"
    else
        fail "User Access Administrator — not found on the subscription, inherited from a" \
             "management group, or under the subscription"
    fi

    # Contributor / Owner. CDR (Event Hub) needs at least Contributor; Host and
    # Workload Scanning assign roles (disk-snapshot / container access) and set
    # up Azure Lighthouse, which require Owner (Contributor cannot assign roles).
    local has_owner=false has_contrib=false
    echo "$all_roles" | grep -qi "^Owner$" && has_owner=true
    echo "$all_roles" | grep -qi "^Contributor$" && has_contrib=true

    if [[ "$features" == *"vm"* ]] || [[ "$features" == *"workload_scanning"* ]]; then
        if [[ "$has_owner" == "true" ]]; then
            pass "Owner (RBAC) — required to assign Host/Workload Scanning roles"
        elif [[ "$has_contrib" == "true" ]]; then
            warn "Owner not found (only Contributor). Host/Workload Scanning assign roles" \
                 "(disk-snapshot / container access) and set up Lighthouse, which Contributor" \
                 "cannot do — Owner (or User Access Administrator for the assignments) is" \
                 "required at apply time."
        else
            fail "Owner — not found (required to assign Host/Workload Scanning roles)"
        fi
    elif [[ "$features" == *"cdr"* ]] || [[ "$features" == *"ciem"* ]]; then
        if [[ "$has_owner" == "true" || "$has_contrib" == "true" ]]; then
            pass "Contributor/Owner (RBAC) — needed to create the Event Hub for CDR"
        else
            fail "Contributor — not found (required to create the Event Hub for CDR)"
        fi
    fi

    # Microsoft.ManagedServices provider registration (Azure Lighthouse backs
    # agentless Host Scanning). A subscription prerequisite, not a Terraform
    # resource — the apply fails creating the Lighthouse definition if missing.
    if [[ "$features" == *"vm"* ]]; then
        local mms
        mms=$(az provider show --namespace Microsoft.ManagedServices \
            --query registrationState --output tsv 2>/dev/null) || mms=""
        if [[ "$mms" == "Registered" ]]; then
            pass "Microsoft.ManagedServices provider registered (Host Scanning / Lighthouse)"
        else
            warn "Microsoft.ManagedServices not registered (state: ${mms:-unknown}). Host Scanning" \
                 "needs it. Run: az provider register --namespace Microsoft.ManagedServices"
        fi
    fi

    # Check Entra ID roles.
    # NOTE: query the roleManagement API, NOT transitiveMemberOf with a
    # $filter=displayName — Graph rejects a $filter on that reference property
    # with Request_UnsupportedQuery. roleManagement/directory/roleAssignments
    # lists ACTIVE assignments only; a PIM-eligible role that has not been
    # activated will NOT appear (activate it before running terraform apply).
    echo ""
    echo "  Entra ID Roles:"

    if [[ -z "${user_id:-}" ]]; then
        warn "Entra ID roles — cannot verify (could not resolve an object id for the current" \
             "identity: neither a signed-in user nor a service principal)." \
             "Need Application Administrator + Privileged Role Administrator (or Global Administrator)."
    else
        # NOTE: the query MUST be guarded by 'if !' rather than assigning and
        # testing $? afterwards — under 'set -e' a bare assignment from a failing
        # command substitution aborts the whole script, so the warn branch would
        # be unreachable and the run would end mid-report with exit 1. A
        # service-principal token commonly lacks RoleManagement.Read.Directory,
        # which is exactly when this call fails.
        local entra_roles
        if ! entra_roles=$(az rest --method GET \
            --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?\$filter=principalId eq '${user_id}'&\$expand=roleDefinition" \
            --query "value[].roleDefinition.displayName" --output tsv 2>/dev/null); then
            warn "Entra ID roles — could not query the roleManagement API (insufficient Graph" \
                 "permission on this token, e.g. RoleManagement.Read.Directory is not granted)." \
                 "Verify manually: Entra ID > Roles and administrators" \
                 "(need Application Administrator + Privileged Role Administrator, or Global Administrator)."
        else
            local r
            for r in "Application Administrator" "Privileged Role Administrator"; do
                if echo "$entra_roles" | grep -qiE "^${r}\$|^Global Administrator\$"; then
                    pass "${r} (Entra ID)"
                else
                    warn "${r} — not among your ACTIVE Entra roles. If it is PIM-eligible, activate" \
                         "it before 'terraform apply'; otherwise it must be assigned. (Entra ID >" \
                         "Roles and administrators)"
                fi
            done
        fi
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <provider> [scope] [features] [--aws-profile NAME]"
    echo "  provider: aws | gcp | azure"
    echo "  scope:    single | organization | tenant (default: single)"
    echo "  features: comma-separated (default: cspm)"
    echo "            valid: cspm, cdr, cdr_cloudlogs, ciem, vm,"
    echo "                   workload_scanning"
    echo "            cdr = EventBridge mode, cdr_cloudlogs = CloudTrail/S3 mode"
    echo "  --aws-profile NAME: use a specific AWS CLI profile"
    echo ""
    echo "Examples:"
    echo "  $0 aws single cspm,cdr"
    echo "  $0 aws single cspm,cdr_cloudlogs"
    echo "  $0 aws single cspm,vm,workload_scanning"
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

# Ambient static credentials (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY) take
# precedence over AWS_PROFILE in the AWS CLI. If a profile is in effect (via the
# --aws-profile flag or an inherited AWS_PROFILE) AND ambient env creds are set,
# every aws call below would silently run as the env-cred identity instead of the
# profile's — so the check reports on the WRONG principal. Neutralize the env
# creds within this script's process so the requested profile is authoritative.
if [[ "$PROVIDER" == "aws" && -n "${AWS_PROFILE:-}" && -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
    echo ""
    echo -e "  ${YELLOW}!${NC} AWS_PROFILE=${AWS_PROFILE} is set, but ambient AWS_ACCESS_KEY_ID would" \
            "override it — unsetting env credentials for this check so the profile is honored." \
            "Confirm the resolved 'Identity:' below is the account you intend to onboard."
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
fi

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
