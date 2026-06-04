# Sysdig SysQL — Entity Relationships

Navigation map of the SysQL data model. For every queryable node
(Entity, Union and Query alias) it lists the relationships an LLM
can traverse to reach another node, in the form:

    Source --[ relationshipName : RELATIONSHIP_NAME ]--> Destination

Where:
- `relationshipName` is the field used inside SysQL queries (e.g. `packages`).
- `RELATIONSHIP_NAME` is the underlying graph edge label (e.g. `HAS_INSTALLED`).
- The arrow direction reflects the `direction` declared in the schema:
  - `-->` for `direction: out` (the source is the start of the edge).
  - `<--` for `direction: in`  (the source is the end of the edge).
- Virtual relationships expose a path through one or more intermediate
  relationships and are annotated with `(virtual via: a -> b -> c)`.
- Node kinds:
  - **Entity** — a concrete node type.
  - **Union** — a polymorphic node that resolves to one of several Entities
    (e.g. `CloudResource` → `AWSResource | AzureResource | …`).
  - **Query** — a named alias over a base entity, sometimes adding
    relationships not declared on the base entity (e.g. `Endpoint`).

**Hidden relationships are intentionally omitted.** Only public, queryable
relationships are listed here. Source schema:
[`schema.md`](schema.md).

---

## Index

- **Compute**
  - [AWSLambda](#awslambda) *(query)*
  - [AzureFunction](#azurefunction-azureresource) *(query, via AzureResource)*
  - [AzureFunction](#azurefunction-cloudresource) *(query, via CloudResource)*
  - [AzureVirtualMachine](#azurevirtualmachine) *(query)*
  - [CloudFunction](#cloudfunction) *(query)*
  - [CloudRunJob](#cloudrunjob) *(query)*
  - [CloudRunService](#cloudrunservice) *(query)*
  - [ContainerApp](#containerapp) *(query)*
  - [ContainerAppJob](#containerappjob) *(query)*
  - [ContainerInstance](#containerinstance) *(query)*
  - [EC2Instance](#ec2instance) *(query)*
  - [EC2LaunchTemplate](#ec2launchtemplate) *(query)*
  - [ECSClusterTask](#ecsclustertask) *(query)*
  - [ECSFargateService](#ecsfargateservice) *(query)*
  - [ECSService](#ecsservice) *(query)*
  - [GCPCloudFunction](#gcpcloudfunction) *(query)*
  - [GCPComputeInstance](#gcpcomputeinstance) *(query)*
  - [Host](#host)
  - [Instance](#instance) *(hidden)*
  - [VirtualMachine](#virtualmachine) *(query, hidden)*
- **Detections**
  - [RuntimeEvent](#runtimeevent)
  - [Threat](#threat)
- **Environment**
  - [AWSRegion](#awsregion) *(hidden)*
  - [AWSResource](#awsresource) *(hidden)*
  - [AzureManagementGroup](#azuremanagementgroup) *(hidden)*
  - [AzureOrganization](#azureorganization)
  - [AzureRegion](#azureregion) *(hidden)*
  - [AzureResource](#azureresource) *(hidden)*
  - [AzureSubscription](#azuresubscription)
  - [CloudAccount](#cloudaccount) *(union)*
  - [CloudResource](#cloudresource) *(union)*
  - [Endpoint](#endpoint) *(query)*
  - [ExposureEndpoint](#exposureendpoint) *(hidden)*
  - [GCPFolder](#gcpfolder) *(hidden)*
  - [GCPOrganization](#gcporganization)
  - [GCPProject](#gcpproject)
  - [GCPRegion](#gcpregion) *(hidden)*
  - [GCPResource](#gcpresource) *(hidden)*
  - [GitCloudResource](#gitcloudresource) *(hidden)*
  - [IBMAccount](#ibmaccount)
  - [IBMAccountGroup](#ibmaccountgroup) *(hidden)*
  - [IBMOrganization](#ibmorganization) *(hidden)*
  - [IBMRegion](#ibmregion) *(hidden)*
  - [IBMResource](#ibmresource)
  - [OCICompartment](#ocicompartment)
  - [OCIRegion](#ociregion) *(hidden)*
  - [OCIResource](#ociresource)
  - [OCITenancy](#ocitenancy) *(hidden)*
  - [Owner](#owner) *(hidden)*
  - [PublicEndpoint](#publicendpoint) *(query, hidden)*
  - [Region](#region) *(union)*
  - [Resource](#resource) *(union, hidden)*
  - [RuntimeResource](#runtimeresource) *(hidden)*
  - [ValidatedExposure](#validatedexposure) *(hidden)*
  - [Zone](#zone)
- **Findings**
  - [AIPackage](#aipackage) *(query)*
  - [CompromisedState](#compromisedstate) *(hidden)*
  - [Control](#control)
  - [IdentityFinding](#identityfinding) *(hidden)*
  - [Malware](#malware)
  - [Policy](#policy) *(hidden)*
  - [PrivilegedControl](#privilegedcontrol) *(query)*
  - [RiskFinding](#riskfinding) *(hidden)*
  - [RuntimeMetadata](#runtimemetadata) *(hidden)*
  - [S3AcceptsHTTP](#s3acceptshttp) *(query)*
  - [S3VersioningDisabled](#s3versioningdisabled) *(query)*
  - [SensitiveData](#sensitivedata)
  - [SensitiveDataFinding](#sensitivedatafinding) *(hidden)*
  - [SensitiveDataFindingDetail](#sensitivedatafindingdetail) *(hidden)*
  - [SourceCodeFile](#sourcecodefile) *(hidden)*
  - [SourceCodeRepository](#sourcecoderepository) *(hidden)*
  - [VulnerabilityNew](#vulnerabilitynew) *(query, hidden)*
- **Identity**
  - [CIEMAccessGroup](#ciemaccessgroup) *(hidden)*
  - [CIEMAccessPolicy](#ciemaccesspolicy) *(hidden)*
  - [CIEMAccessRole](#ciemaccessrole) *(hidden)*
  - [CIEMAccessServiceIdentity](#ciemaccessserviceidentity) *(hidden)*
  - [CIEMAccessUnionUser](#ciemaccessunionuser) *(union, hidden)*
  - [CIEMAccessUser](#ciemaccessuser) *(hidden)*
  - [CIEMResource](#ciemresource) *(union, hidden)*
  - [CIEMUnionUser](#ciemunionuser) *(union, hidden)*
  - [CloudGroup](#cloudgroup)
  - [CloudIAMGroup](#cloudiamgroup) *(hidden)*
  - [CloudIAMPolicy](#cloudiampolicy) *(hidden)*
  - [CloudIAMRole](#cloudiamrole) *(hidden)*
  - [CloudIAMServiceIdentity](#cloudiamserviceidentity) *(hidden)*
  - [CloudIAMServiceIdentityKey](#cloudiamserviceidentitykey) *(hidden)*
  - [CloudIAMUser](#cloudiamuser) *(hidden)*
  - [CloudPolicy](#cloudpolicy)
  - [CloudRole](#cloudrole)
  - [CloudServiceIdentity](#cloudserviceidentity)
  - [CloudUser](#clouduser)
  - [IAMInstanceProfile](#iaminstanceprofile)
  - [ScopedIAMGroup](#scopediamgroup) *(hidden)*
  - [ScopedIAMPolicy](#scopediampolicy) *(hidden)*
  - [ScopedIAMResource](#scopediamresource) *(union, hidden)*
  - [ScopedIAMRole](#scopediamrole) *(hidden)*
  - [ScopedIAMServiceIdentity](#scopediamserviceidentity) *(hidden)*
  - [ScopedIAMUser](#scopediamuser) *(hidden)*
- **Kubernetes**
  - [GitKubeWorkload](#gitkubeworkload)
  - [KubeCluster](#kubecluster)
  - [KubeIdentity](#kubeidentity)
  - [KubeIngress](#kubeingress)
  - [KubeNode](#kubenode)
  - [KubeResource](#kuberesource)
  - [KubeService](#kubeservice)
  - [KubeWorkload](#kubeworkload)
- **Metadata**
  - [Label](#label) *(hidden)*
  - [SageEnvironment](#sageenvironment) *(hidden)*
  - [SageLabel](#sagelabel) *(hidden)*
- **None**
  - [Component](#component) *(hidden)*
  - [FeatureHealthAlert](#featurehealthalert) *(hidden)*
  - [HostInternal](#hostinternal) *(hidden)*
  - [SubComponent](#subcomponent) *(hidden)*
- **Risk**
  - [AcceptedRiskDef](#acceptedriskdef) *(hidden)*
- **Security & Compliance**
  - [Requirement](#requirement) *(hidden)*
- **Software**
  - [Application](#application)
  - [ContainerNew](#containernew) *(query, hidden)*
  - [Image](#image)
  - [ImageNew](#imagenew) *(query, hidden)*
  - [ImageRepository](#imagerepository) *(hidden)*
  - [ImageTag](#imagetag) *(hidden)*
  - [Package](#package)
  - [PackageNew](#packagenew) *(query, hidden)*
  - [SBOMComponent](#sbomcomponent)
  - [ScanEventVM](#scaneventvm) *(hidden)*
  - [ScanResult](#scanresult) *(hidden)*
  - [ScanStatus](#scanstatus)
- **Storage**
  - [AWSRDSDatabaseCluster](#awsrdsdatabasecluster) *(query)*
  - [AWSRDSDatabaseInstance](#awsrdsdatabaseinstance) *(query)*
  - [AzureStorageAccountBlobService](#azurestorageaccountblobservice) *(query)*
  - [AzureStorageAccountBlobServiceContainer](#azurestorageaccountblobservicecontainer) *(query)*
  - [GCPCloudStorageBucket](#gcpcloudstoragebucket) *(query)*
  - [S3Bucket](#s3bucket) *(query)*

---

## Category: Compute

### AWSLambda

- **Kind:** Query
- **Display name:** AWS Lambda
- **Provider:** AWS
- **Base entity:** [`AWSResource`](#awsresource)
- **Description:** An AWS Lambda represents a serverless compute function that runs in response to events provided by AWS.

_No public relationships._

### AzureFunction (AzureResource)

- **Kind:** Query
- **Display name:** AzureFunction
- **Provider:** Azure
- **Base entity:** [`AzureResource`](#azureresource)
- **Description:** Azure Functions is a serverless compute service provided by Azure that enables you to run event-driven code without managing infrastructure, supporting multiple programming languages and automatic scaling.

_No public relationships._

### AzureFunction (CloudResource)

- **Kind:** Query
- **Display name:** Azure Function
- **Provider:** Azure
- **Base entity:** [`CloudResource`](#cloudresource)
- **Description:** An Azure Function represents a serverless compute function that executes code in response to events.

_No public relationships._

### AzureVirtualMachine

- **Kind:** Query
- **Display name:** Azure Virtual Machine
- **Provider:** Azure
- **Base entity:** [`CloudResource`](#cloudresource)
- **Description:** An Azure Virtual Machine represents a compute instance running in the Azure cloud.

_No public relationships._

### CloudFunction

- **Kind:** Query
- **Display name:** Cloud Function
- **Provider:** GCP
- **Base entity:** [`GCPResource`](#gcpresource)
- **Description:** A Cloud Function is a lightweight, event-driven compute service provided by GCP that allows you to run code in response to events without provisioning or managing servers.

_No public relationships._

### CloudRunJob

- **Kind:** Query
- **Display name:** Cloud Run Job
- **Provider:** GCP
- **Base entity:** [`GCPResource`](#gcpresource)
- **Description:** A Cloud Run Job is a serverless platform for running containerized tasks provided by GCP that execute to completion and then stop, ideal for batch processing, data analysis, or scheduled workloads.

_No public relationships._

### CloudRunService

- **Kind:** Query
- **Display name:** Cloud Run Service
- **Provider:** GCP
- **Base entity:** [`GCPResource`](#gcpresource)
- **Description:** A Cloud Run Service is a fully managed serverless platform provided by GCP that automatically scales containerized applications based on incoming requests.

_No public relationships._

### ContainerApp

- **Kind:** Query
- **Display name:** Container App
- **Provider:** Azure
- **Base entity:** [`AzureResource`](#azureresource)
- **Description:** A Container App is a fully managed serverless container service provided by Azure that enables you to run containerized applications and microservices with built-in scaling, load balancing, and service discovery.

_No public relationships._

### ContainerAppJob

- **Kind:** Query
- **Display name:** Container App Job
- **Provider:** Azure
- **Base entity:** [`AzureResource`](#azureresource)
- **Description:** A Container App Job is a serverless compute service provided by Azure that allows you to run containerized batch jobs and scheduled tasks with automatic scaling and job lifecycle management.

_No public relationships._

### ContainerInstance

- **Kind:** Query
- **Display name:** Container Instance
- **Provider:** Azure
- **Base entity:** [`AzureResource`](#azureresource)
- **Description:** A Container Instance is a serverless compute service provided by Azure that allows you to run containerized applications without managing the underlying infrastructure.

_No public relationships._

### EC2Instance

- **Kind:** Query
- **Display name:** EC2 Instance
- **Provider:** AWS
- **Base entity:** [`CloudResource`](#cloudresource)
- **Description:** An EC2 Instance represents a virtual machine running on AWS Elastic Compute Cloud (EC2).

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtLaunchTemplates` | `LAUNCHED_FROM` | `out` --> | [`EC2LaunchTemplate`](#ec2launchtemplate) | virtual via: `launchTemplates`; display: _That Is Launched From_ |
| `packages` | `HAS_INSTALLED` | `out` --> | [`Package`](#package) | virtual via: `runtimeMetadata -> packages`; display: _That Has Installed_ |
| `applications` | `HAS_INSTALLED` | `out` --> | [`Application`](#application) | virtual via: `runtimeMetadata -> applications`; display: _That Has Installed_ |
| `vulnerabilities` | `AFFECTED_BY` | `out` --> | [`Vulnerability`](#vulnerability) | virtual via: `runtimeMetadata -> vulnerabilities`; display: _That Is Affected By_ |
| `iamRoles3Buckets` | `?` | `?` <-> | [`?`](#?) |  |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `vrtHasKubeNode` | `DEPLOYS` | `out` --> | [`KubeNode`](#kubenode) | virtual via: `hasKubeNode`; display: _That Deploys_ |
| `containers` | `HAS` | `out` --> | [`Container`](#container) | display: _That Has_ |
| `iamInstanceProfiles` | `ASSOCIATED_WITH` | `out` --> | [`IAMInstanceProfile`](#iaminstanceprofile) | display: _That Is Associated With_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `vrtMalwareFindings` | `CONTAINS` | `out` --> | [`Malware`](#malware) | virtual via: `malwareFindings`; display: _Contains_ |
| `exposedCloudResources` | `EXPOSES` | `out` --> | [`CloudResource`](#cloudresource) | display: _With Exposed_ |
| `vrtPackages` | `PACKAGE_INSTALLED_ON` | `out` --> | [`Package`](#package) | virtual via: `runtimeMetadata -> packages`; display: _That Has Installed_ |
| `sbomComponents` | `HAS_INSTALLED` | `out` --> | [`SBOMComponent`](#sbomcomponent) | virtual via: `runtimeMetadata -> sbomComponents`; display: _That Has Installed_ |
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _With_ |
| `aiPackages` | `VIOLATES` | `out` --> | [`AIPackage`](#aipackage) | display: _That Contains_ |

Paths:

```
EC2Instance --[ vrtLaunchTemplates : LAUNCHED_FROM ]--> EC2LaunchTemplate   (virtual via: launchTemplates)
EC2Instance --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
EC2Instance --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
EC2Instance --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
EC2Instance --[ iamRoles3Buckets : ? ]<-> ?
EC2Instance --[ zones : IN ]--> Zone
EC2Instance --[ vrtHasKubeNode : DEPLOYS ]--> KubeNode   (virtual via: hasKubeNode)
EC2Instance --[ containers : HAS ]--> Container
EC2Instance --[ iamInstanceProfiles : ASSOCIATED_WITH ]--> IAMInstanceProfile
EC2Instance --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
EC2Instance --[ vrtMalwareFindings : CONTAINS ]--> Malware   (virtual via: malwareFindings)
EC2Instance --[ exposedCloudResources : EXPOSES ]--> CloudResource
EC2Instance --[ vrtPackages : PACKAGE_INSTALLED_ON ]--> Package   (virtual via: runtimeMetadata -> packages)
EC2Instance --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
EC2Instance --[ acceptedControls : ACCEPTS ]--> Control
EC2Instance --[ failedControls : VIOLATES ]--> Control
EC2Instance --[ regions : IN ]--> Region
EC2Instance --[ aiPackages : VIOLATES ]--> AIPackage
```

### EC2LaunchTemplate

- **Kind:** Query
- **Display name:** EC2 Launch Template
- **Provider:** AWS
- **Base entity:** [`AWSResource`](#awsresource)
- **Description:** An EC2 Launch Template defines the configuration for launching EC2 instances, including AMI, instance type, security groups, and other launch parameters.

_No public relationships._

### ECSClusterTask

- **Kind:** Query
- **Display name:** ECS Cluster Task
- **Provider:** AWS
- **Base entity:** [`AWSResource`](#awsresource)
- **Description:** A running instance of a containerized application within an ECS cluster provided by AWS.

_No public relationships._

### ECSFargateService

- **Kind:** Query
- **Display name:** ECS Fargate Service
- **Provider:** AWS
- **Base entity:** [`AWSResource`](#awsresource)
- **Description:** Serverless container orchestration service that runs Docker containers without managing underlying servers provided by AWS.

_No public relationships._

### ECSService

- **Kind:** Query
- **Display name:** ECS Service
- **Provider:** AWS
- **Base entity:** [`AWSResource`](#awsresource)
- **Description:** Container orchestration platform that manages Docker containers at scale provided by AWS.

_No public relationships._

### GCPCloudFunction

- **Kind:** Query
- **Display name:** GCP Cloud Function
- **Provider:** GCP
- **Base entity:** [`CloudResource`](#cloudresource)
- **Description:** A GCP Cloud Function represents a serverless compute function that executes in response to events.

_No public relationships._

### GCPComputeInstance

- **Kind:** Query
- **Display name:** GCP Compute Instance
- **Provider:** GCP
- **Base entity:** [`CloudResource`](#cloudresource)
- **Description:** A GCP Compute Instance represents a virtual machine running on Google Cloud Compute Engine.

_No public relationships._

### Host

- **Kind:** Entity
- **Description:** A Host represents a physical or virtual machine running software workloads.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `packages` | `HAS_INSTALLED` | `out` --> | [`Package`](#package) | virtual via: `runtimeMetadata -> packages`; display: _That Has Installed_ |
| `sbomComponents` | `HAS_INSTALLED` | `out` --> | [`SBOMComponent`](#sbomcomponent) | virtual via: `runtimeMetadata -> sbomComponents`; display: _That Has Installed_ |
| `applications` | `HAS_INSTALLED` | `out` --> | [`Application`](#application) | virtual via: `runtimeMetadata -> applications`; display: _That Has Installed_ |
| `vulnerabilities` | `AFFECTED_BY` | `out` --> | [`Vulnerability`](#vulnerability) | virtual via: `runtimeMetadata -> vulnerabilities`; display: _That Is Affected By_ |
| `kubeNodes` | `DEPLOYED_ON` | `in` <-- | [`KubeNode`](#kubenode) | display: _That Is Deployed On_ |
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `exposedCloudResources` | `EXPOSES` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Exposes_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `vrtMalwareFindings` | `CONTAINS` | `out` --> | [`Malware`](#malware) | virtual via: `malwareFindings`; display: _Contains_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `exposedBy` | `EXPOSED_BY` | `out` --> | [`Endpoint`](#endpoint) | display: _That listens_ |
| `publiclyExposedBy` | `PUBLICLY_EXPOSED_BY` | `out` --> | [`PublicEndpoint`](#publicendpoint) | virtual via: `exposedBy -> validatedBy`; display: _That publicly listens_ |

Paths:

```
Host --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
Host --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
Host --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
Host --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
Host --[ kubeNodes : DEPLOYED_ON ]<-- KubeNode
Host --[ regions : IN ]--> Region
Host --[ exposedCloudResources : EXPOSES ]--> CloudResource
Host --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
Host --[ vrtMalwareFindings : CONTAINS ]--> Malware   (virtual via: malwareFindings)
Host --[ failedControls : VIOLATES ]--> Control
Host --[ zones : IN ]--> Zone
Host --[ exposedBy : EXPOSED_BY ]--> Endpoint
Host --[ publiclyExposedBy : PUBLICLY_EXPOSED_BY ]--> PublicEndpoint   (virtual via: exposedBy -> validatedBy)
```

### Instance

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An Instance represents a compute instance.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _With_ |
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |
| `passedControls` | `PASSES` | `out` --> | [`Control`](#control) | display: _That Passes_ |
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |

Paths:

```
Instance --[ zones : IN ]--> Zone
Instance --[ failedControls : VIOLATES ]--> Control
Instance --[ acceptedControls : ACCEPTS ]--> Control
Instance --[ passedControls : PASSES ]--> Control
Instance --[ regions : IN ]--> Region
```

### VirtualMachine

- **Kind:** Query
- **Display name:** Virtual Machine
- **Base entity:** [`Host`](#host)
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Represents a virtual machine.

_No public relationships._

## Category: Detections

### RuntimeEvent

- **Kind:** Entity
- **Display name:** Runtime Event
- **Description:** Sysdig Runtime Events refer to security and system activity events detected in real-time by Sysdig Secure during the execution of applications and containers. These events are generated based on Falco rules, which define security policies and anomalous behaviors

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `cloudResources` | `GENERATED_BY` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Is Generated By_ |
| `workloads` | `GENERATED_BY` | `out` --> | [`KubeWorkload`](#kubeworkload) | display: _That Is Generated By_ |
| `gcpProjects` | `GENERATED_BY` | `out` --> | [`GCPProject`](#gcpproject) | display: _That Is Generated By_ |
| `azureSubscriptions` | `GENERATED_BY` | `out` --> | [`AzureSubscription`](#azuresubscription) | display: _That Is Generated By_ |
| `awsAccounts` | `GENERATED_BY` | `out` --> | [`AWSAccount`](#awsaccount) | display: _That Is Generated By_ |
| `kubeResources` | `GENERATED_BY` | `out` --> | [`KubeResource`](#kuberesource) | display: _That Is Generated By_ |
| `iamUsers` | `GENERATED_BY` | `out` --> | [`IAMUser`](#iamuser) | display: _That Is Generated By_ |

Paths:

```
RuntimeEvent --[ cloudResources : GENERATED_BY ]--> CloudResource
RuntimeEvent --[ workloads : GENERATED_BY ]--> KubeWorkload
RuntimeEvent --[ gcpProjects : GENERATED_BY ]--> GCPProject
RuntimeEvent --[ azureSubscriptions : GENERATED_BY ]--> AzureSubscription
RuntimeEvent --[ awsAccounts : GENERATED_BY ]--> AWSAccount
RuntimeEvent --[ kubeResources : GENERATED_BY ]--> KubeResource
RuntimeEvent --[ iamUsers : GENERATED_BY ]--> IAMUser
```

### Threat

- **Kind:** Entity
- **Display name:** Threat
- **Description:** Threats surface context and security signals to highlight malicious activity detected for a resource.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `kubeNodes` | `GENERATED_BY` | `out` --> | [`KubeNode`](#kubenode) | display: _That Is Generated By_ |
| `kubeWorkload` | `GENERATED_BY` | `out` --> | [`KubeWorkload`](#kubeworkload) | display: _That Is Generated By_ |
| `imageManifest` | `GENERATED_BY` | `out` --> | [`Image`](#image) | display: _That Is Generated By_ |
| `awsResources` | `GENERATED_BY` | `out` --> | [`AWSResource`](#awsresource) | display: _That Is Generated By_ |
| `azureResources` | `GENERATED_BY` | `out` --> | [`AzureResource`](#azureresource) | display: _That Is Generated By_ |
| `gcpResources` | `GENERATED_BY` | `out` --> | [`GCPResource`](#gcpresource) | display: _That Is Generated By_ |

Paths:

```
Threat --[ kubeNodes : GENERATED_BY ]--> KubeNode
Threat --[ kubeWorkload : GENERATED_BY ]--> KubeWorkload
Threat --[ imageManifest : GENERATED_BY ]--> Image
Threat --[ awsResources : GENERATED_BY ]--> AWSResource
Threat --[ azureResources : GENERATED_BY ]--> AzureResource
Threat --[ gcpResources : GENERATED_BY ]--> GCPResource
```

## Category: Environment

### AWSRegion

- **Kind:** Entity
- **Display name:** AWS Region
- **Provider:** AWS
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An AWSRegion represents a region in AWS.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtCloudResources` | `CONTAINS` | `out` --> | [`CloudResource`](#cloudresource) | virtual via: `cloudResources`; display: _That Contains_ |
| `vrtIamUsers` | `CONTAINS` | `out` --> | [`IAMUser`](#iamuser) | virtual via: `iamUsers`; display: _That Contains_ |
| `vrIamRoles` | `CONTAINS` | `out` --> | [`IAMRole`](#iamrole) | virtual via: `iamRoles`; display: _That Contains_ |
| `vrtIamPolicies` | `CONTAINS` | `out` --> | [`IAMPolicy`](#iampolicy) | virtual via: `iamPolicies`; display: _That Contains_ |
| `vrtRegions` | `CONTAINS` | `out` --> | [`Region`](#region) | virtual via: `regions`; display: _That Can Access To_ |
| `awsAccounts` | `IN` | `out` --> | [`AWSAccount`](#awsaccount) | display: _With_ |
| `vrtAwsAccounts` | `CONTAINS` | `out` --> | [`AWSAccount`](#awsaccount) | virtual via: `awsAccounts`; display: _That Contains_ |
| `vrtIamGroups` | `CONTAINS` | `out` --> | [`IAMGroup`](#iamgroup) | virtual via: `iamGroups`; display: _That Contains_ |

Paths:

```
AWSRegion --[ vrtCloudResources : CONTAINS ]--> CloudResource   (virtual via: cloudResources)
AWSRegion --[ vrtIamUsers : CONTAINS ]--> IAMUser   (virtual via: iamUsers)
AWSRegion --[ vrIamRoles : CONTAINS ]--> IAMRole   (virtual via: iamRoles)
AWSRegion --[ vrtIamPolicies : CONTAINS ]--> IAMPolicy   (virtual via: iamPolicies)
AWSRegion --[ vrtRegions : CONTAINS ]--> Region   (virtual via: regions)
AWSRegion --[ awsAccounts : IN ]--> AWSAccount
AWSRegion --[ vrtAwsAccounts : CONTAINS ]--> AWSAccount   (virtual via: awsAccounts)
AWSRegion --[ vrtIamGroups : CONTAINS ]--> IAMGroup   (virtual via: iamGroups)
```

### AWSResource

- **Kind:** Entity
- **Display name:** AWS Resource
- **Provider:** AWS
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An AWSResource represents a resource in AWS  (e.g. IAM policy, S3 Bucket, EC2 Instance).

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `packages` | `HAS_INSTALLED` | `out` --> | [`Package`](#package) | virtual via: `runtimeMetadata -> packages`; display: _That Has Installed_ |
| `applications` | `HAS_INSTALLED` | `out` --> | [`Application`](#application) | virtual via: `runtimeMetadata -> applications`; display: _That Has Installed_ |
| `vulnerabilities` | `AFFECTED_BY` | `out` --> | [`Vulnerability`](#vulnerability) | virtual via: `runtimeMetadata -> vulnerabilities`; display: _That Is Affected By_ |
| `vrtPackages` | `PACKAGE_INSTALLED_ON` | `out` --> | [`Package`](#package) | virtual via: `runtimeMetadata -> packages`; display: _That Has Installed_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `vrtHasKubeNode` | `DEPLOYS` | `out` --> | [`KubeNode`](#kubenode) | virtual via: `hasKubeNode`; display: _That Deploys_ |
| `vrtRunsContainer` | `RUNS` | `out` --> | [`Container`](#container) | virtual via: `containers`; display: _Runs Container_ |
| `iamInstanceProfiles` | `ASSOCIATED_WITH` | `out` --> | [`IAMInstanceProfile`](#iaminstanceprofile) | display: _That Is Associated With_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `vrtThreats` | `GENERATES` | `out` --> | [`Threat`](#threat) | virtual via: `threats`; display: _That Generates_ |
| `vrtMalwareFindings` | `CONTAINS` | `out` --> | [`Malware`](#malware) | virtual via: `malwareFindings`; display: _Contains_ |
| `sensitiveData` | `CONTAINS` | `out` --> | [`SensitiveData`](#sensitivedata) | display: _Contains_ |
| `exposedCloudResources` | `EXPOSES` | `out` --> | [`CloudResource`](#cloudresource) | display: _With Exposed_ |
| `sbomComponents` | `HAS_INSTALLED` | `out` --> | [`SBOMComponent`](#sbomcomponent) | virtual via: `runtimeMetadata -> sbomComponents`; display: _That Has Installed_ |
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _With_ |
| `aiPackages` | `VIOLATES` | `out` --> | [`AIPackage`](#aipackage) | display: _That Contains_ |

Paths:

```
AWSResource --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
AWSResource --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
AWSResource --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
AWSResource --[ vrtPackages : PACKAGE_INSTALLED_ON ]--> Package   (virtual via: runtimeMetadata -> packages)
AWSResource --[ zones : IN ]--> Zone
AWSResource --[ vrtHasKubeNode : DEPLOYS ]--> KubeNode   (virtual via: hasKubeNode)
AWSResource --[ vrtRunsContainer : RUNS ]--> Container   (virtual via: containers)
AWSResource --[ iamInstanceProfiles : ASSOCIATED_WITH ]--> IAMInstanceProfile
AWSResource --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
AWSResource --[ vrtThreats : GENERATES ]--> Threat   (virtual via: threats)
AWSResource --[ vrtMalwareFindings : CONTAINS ]--> Malware   (virtual via: malwareFindings)
AWSResource --[ sensitiveData : CONTAINS ]--> SensitiveData
AWSResource --[ exposedCloudResources : EXPOSES ]--> CloudResource
AWSResource --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
AWSResource --[ acceptedControls : ACCEPTS ]--> Control
AWSResource --[ failedControls : VIOLATES ]--> Control
AWSResource --[ regions : IN ]--> Region
AWSResource --[ aiPackages : VIOLATES ]--> AIPackage
```

### AzureManagementGroup

- **Kind:** Entity
- **Display name:** Azure management group
- **Provider:** Azure
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A container for management groups

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `azureOrganizations` | `IN` | `out` --> | [`AzureOrganization`](#azureorganization) | display: _In_ |
| `azureManagementGroups` | `IN` | `out` --> | [`AzureManagementGroup`](#azuremanagementgroup) | display: _In_ |

Paths:

```
AzureManagementGroup --[ azureOrganizations : IN ]--> AzureOrganization
AzureManagementGroup --[ azureManagementGroups : IN ]--> AzureManagementGroup
```

### AzureOrganization

- **Kind:** Entity
- **Display name:** Azure Organization
- **Provider:** Azure
- **Description:** An Azure Organization represents a collection of Azure subscriptions managed under a single entity.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtAzureSubscriptions` | `CONTAINS` | `out` --> | [`AzureSubscription`](#azuresubscription) | virtual via: `azureSubscriptions`; display: _That Contains_ |

Paths:

```
AzureOrganization --[ vrtAzureSubscriptions : CONTAINS ]--> AzureSubscription   (virtual via: azureSubscriptions)
```

### AzureRegion

- **Kind:** Entity
- **Display name:** Azure Region
- **Provider:** Azure
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An AzureRegion represents a region in Azure.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `azureSubscriptions` | `IN` | `out` --> | [`AzureSubscription`](#azuresubscription) | display: _That Is In_ |
| `vrtCloudResources` | `CONTAINS` | `out` --> | [`CloudResource`](#cloudresource) | virtual via: `cloudResources`; display: _That Contains_ |

Paths:

```
AzureRegion --[ azureSubscriptions : IN ]--> AzureSubscription
AzureRegion --[ vrtCloudResources : CONTAINS ]--> CloudResource   (virtual via: cloudResources)
```

### AzureResource

- **Kind:** Entity
- **Display name:** Azure Resource
- **Provider:** Azure
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An AzureResource represents a resource in Azure (e.g. VM, Storage Account, SQL Database).

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `packages` | `HAS_INSTALLED` | `out` --> | [`Package`](#package) | virtual via: `runtimeMetadata -> packages`; display: _That Has Installed_ |
| `sbomComponents` | `HAS_INSTALLED` | `out` --> | [`SBOMComponent`](#sbomcomponent) | virtual via: `runtimeMetadata -> sbomComponents`; display: _That Has Installed_ |
| `applications` | `HAS_INSTALLED` | `out` --> | [`Application`](#application) | virtual via: `runtimeMetadata -> applications`; display: _That Has Installed_ |
| `vulnerabilities` | `AFFECTED_BY` | `out` --> | [`Vulnerability`](#vulnerability) | virtual via: `runtimeMetadata -> vulnerabilities`; display: _That Is Affected By_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `vrtThreats` | `GENERATES` | `out` --> | [`Threat`](#threat) | virtual via: `threats`; display: _That Generates_ |
| `vrtMalwareFindings` | `CONTAINS` | `out` --> | [`Malware`](#malware) | virtual via: `malwareFindings`; display: _Contains_ |
| `sensitiveData` | `CONTAINS` | `out` --> | [`SensitiveData`](#sensitivedata) | display: _Contains_ |
| `azureRegions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |
| `aiPackages` | `VIOLATES` | `out` --> | [`AIPackage`](#aipackage) | display: _That Contains_ |

Paths:

```
AzureResource --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
AzureResource --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
AzureResource --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
AzureResource --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
AzureResource --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
AzureResource --[ vrtThreats : GENERATES ]--> Threat   (virtual via: threats)
AzureResource --[ vrtMalwareFindings : CONTAINS ]--> Malware   (virtual via: malwareFindings)
AzureResource --[ sensitiveData : CONTAINS ]--> SensitiveData
AzureResource --[ azureRegions : IN ]--> Region
AzureResource --[ failedControls : VIOLATES ]--> Control
AzureResource --[ zones : IN ]--> Zone
AzureResource --[ acceptedControls : ACCEPTS ]--> Control
AzureResource --[ aiPackages : VIOLATES ]--> AIPackage
```

### AzureSubscription

- **Kind:** Entity
- **Display name:** Azure Subscription
- **Provider:** Azure
- **Description:** An Azure Subscription represents a billing and access management entity for Azure resources.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `cloudResources` | `OWNS` | `out` --> | [`CloudResource`](#cloudresource) | virtual via: `azureRegions -> cloudResources`; display: _That Owns_ |
| `vrtAzureRegions` | `CONTAINS` | `out` --> | [`Region`](#region) | virtual via: `azureRegions`; display: _That Can Access To_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |

Paths:

```
AzureSubscription --[ cloudResources : OWNS ]--> CloudResource   (virtual via: azureRegions -> cloudResources)
AzureSubscription --[ vrtAzureRegions : CONTAINS ]--> Region   (virtual via: azureRegions)
AzureSubscription --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
```

### CloudAccount

- **Kind:** Union
- **Display name:** Cloud Account
- **Resolves to:** [ AWSAccount, AzureSubscription, GCPProject ]
- **Description:** A Cloud Account represents a cloud provider account. Supports AWS, Azure, and GCP.

_No public relationships._

### CloudResource

- **Kind:** Union
- **Display name:** Cloud Resource
- **Resolves to:** [ AWSResource, AzureResource, GCPResource, IBMResource, OCIResource ]
- **Description:** A Cloud Resource represents a resource in a cloud provider. Supports AWS, Azure, GCP, IBM, and OCI.

_No public relationships._

### Endpoint

- **Kind:** Query
- **Base entity:** [`ExposureEndpoint`](#exposureendpoint)
- **Description:** The exposure endpoint of a resource

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `validatedBy` | `VALIDATED_BY` | `out` --> | [`PublicEndpoint`](#publicendpoint) |  |

Paths:

```
Endpoint --[ validatedBy : VALIDATED_BY ]--> PublicEndpoint
```

### ExposureEndpoint

- **Kind:** Entity
- **Display name:** Exposure Endpoint
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** The exposure endpoint of a resource

_No public relationships._

### GCPFolder

- **Kind:** Entity
- **Display name:** A GCP folder
- **Provider:** GCP
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A container for GCP folders.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `gcpOrganizations` | `IN` | `out` --> | [`GCPOrganization`](#gcporganization) | display: _In_ |
| `gcpFolders` | `IN` | `out` --> | [`GCPFolder`](#gcpfolder) | display: _In_ |

Paths:

```
GCPFolder --[ gcpOrganizations : IN ]--> GCPOrganization
GCPFolder --[ gcpFolders : IN ]--> GCPFolder
```

### GCPOrganization

- **Kind:** Entity
- **Display name:** GCP Organization
- **Provider:** GCP
- **Description:** A GCP Organization represents the top-level container for GCP resources, including projects.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `gcpProjects` | `IN` | `out` --> | [`GCPProject`](#gcpproject) | display: _That Is In_ |

Paths:

```
GCPOrganization --[ gcpProjects : IN ]--> GCPProject
```

### GCPProject

- **Kind:** Entity
- **Display name:** GCP Project
- **Provider:** GCP
- **Description:** A GCP Project represents a set of cloud resources organized under a single entity.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `cloudResources` | `OWNS` | `out` --> | [`CloudResource`](#cloudresource) | virtual via: `gcpRegions -> cloudResources`; display: _That Owns_ |
| `vrtGcpRegions` | `CONTAINS` | `out` --> | [`Region`](#region) | virtual via: `gcpRegions`; display: _That Can Access To_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `gcpOrganizations` | `IN` | `out` --> | [`GCPOrganization`](#gcporganization) | display: _That Is In_ |

Paths:

```
GCPProject --[ cloudResources : OWNS ]--> CloudResource   (virtual via: gcpRegions -> cloudResources)
GCPProject --[ vrtGcpRegions : CONTAINS ]--> Region   (virtual via: gcpRegions)
GCPProject --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
GCPProject --[ gcpOrganizations : IN ]--> GCPOrganization
```

### GCPRegion

- **Kind:** Entity
- **Display name:** GCP Region
- **Provider:** GCP
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A GCPRegion represents a region in Google Cloud Platform.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtCloudResources` | `CONTAINS` | `out` --> | [`CloudResource`](#cloudresource) | virtual via: `cloudResources`; display: _That Contains_ |

Paths:

```
GCPRegion --[ vrtCloudResources : CONTAINS ]--> CloudResource   (virtual via: cloudResources)
```

### GCPResource

- **Kind:** Entity
- **Display name:** GCP Resource
- **Provider:** GCP
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A GCPResource represents a resource in Google Cloud Platform.

_No public relationships._

### GitCloudResource

- **Kind:** Entity
- **Display name:** Git Cloud Resource
- **Provider:** Git
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A GitCloudResource represents a resource in a Git platform.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With Zone_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |

Paths:

```
GitCloudResource --[ acceptedControls : ACCEPTS ]--> Control
GitCloudResource --[ zones : IN ]--> Zone
GitCloudResource --[ failedControls : VIOLATES ]--> Control
```

### IBMAccount

- **Kind:** Entity
- **Display name:** IBM Account
- **Provider:** IBM
- **Description:** An IBMAccount

_No public relationships._

### IBMAccountGroup

- **Kind:** Entity
- **Display name:** IBM Account group
- **Provider:** IBM
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A container for account groups.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `ibmAccountGroups` | `IN` | `out` --> | [`IBMAccountGroup`](#ibmaccountgroup) | display: _In_ |

Paths:

```
IBMAccountGroup --[ ibmAccountGroups : IN ]--> IBMAccountGroup
```

### IBMOrganization

- **Kind:** Entity
- **Display name:** IBM Organization
- **Provider:** IBM
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An IBMOrganization

_No public relationships._

### IBMRegion

- **Kind:** Entity
- **Display name:** IBM Region
- **Provider:** IBM
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An IBMRegion

_No public relationships._

### IBMResource

- **Kind:** Entity
- **Display name:** IBM Resource
- **Provider:** IBM
- **Description:** An IBMResource represents a resource in IBM  (e.g. IBM IAM policy).

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `acceptsControl` | `ACCEPTS` | `out` --> | [`Control`](#control) |  |
| `passesControl` | `PASSES` | `out` --> | [`Control`](#control) |  |
| `violatesControl` | `VIOLATES` | `out` --> | [`Control`](#control) |  |
| `inZone` | `IN` | `out` --> | [`Zone`](#zone) |  |

Paths:

```
IBMResource --[ acceptsControl : ACCEPTS ]--> Control
IBMResource --[ passesControl : PASSES ]--> Control
IBMResource --[ violatesControl : VIOLATES ]--> Control
IBMResource --[ inZone : IN ]--> Zone
```

### OCICompartment

- **Kind:** Entity
- **Display name:** OCI Compartment
- **Provider:** OCI
- **Description:** An Oracle Cloud Infrastructure Compartment

_No public relationships._

### OCIRegion

- **Kind:** Entity
- **Display name:** OCI Region
- **Provider:** OCI
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An Oracle Cloud Infrastructure Region

_No public relationships._

### OCIResource

- **Kind:** Entity
- **Display name:** OCI Resource
- **Provider:** OCI
- **Description:** An OCIResource represents a resource in the Oracle Cloud Infrastructure .

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `passesControl` | `PASSES` | `out` --> | [`Control`](#control) |  |
| `violatesControl` | `VIOLATES` | `out` --> | [`Control`](#control) |  |
| `inZone` | `IN` | `out` --> | [`Zone`](#zone) |  |

Paths:

```
OCIResource --[ passesControl : PASSES ]--> Control
OCIResource --[ violatesControl : VIOLATES ]--> Control
OCIResource --[ inZone : IN ]--> Zone
```

### OCITenancy

- **Kind:** Entity
- **Display name:** OCI Tenancy
- **Provider:** OCI
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An Oracle Cloud Infrastructure Tenancy

_No public relationships._

### Owner

- **Kind:** Entity
- **Display name:** Owner
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Owner represents entities such as users or teams that own a resource and are responsible for it

_No public relationships._

### PublicEndpoint

- **Kind:** Query
- **Base entity:** [`ValidatedExposure`](#validatedexposure)
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** The validated exposure of a resource

_No public relationships._

### Region

- **Kind:** Union
- **Resolves to:** [ AWSRegion, AzureRegion, GCPRegion, IBMRegion, OCIRegion ]
- **Description:** A Region represents a geographical location where cloud services are deployed.

_No public relationships._

### Resource

- **Kind:** Union
- **Resolves to:** [ AWSResource, GCPResource, AzureResource, KubeResource, KubeCluster, KubeWorkload, KubeIdentity, KubeNode, IBMResource, OCIResource, GitCloudResource, GitKubeWorkload ]
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Represents a generic resource in the customer environment. A resource can be any cloud resource or any Kubernetes resource. Use the resourceType field to specify the type of the resource.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `acceptsControl` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _Accepts_ |
| `violatesControl` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `passesControl` | `PASSES` | `out` --> | [`Control`](#control) | display: _That Passes_ |
| `testedByControl` | `TESTED_BY` | `out` --> | [`Control`](#control) | display: _Tested by_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `aiPackages` | `VIOLATES` | `out` --> | [`AIPackage`](#aipackage) | display: _That Contains_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `containers` | `RUNS_CONTAINER` | `out` --> | [`Container`](#container) | display: _Runs Container_ |
| `vulnerabilities` | `AFFECTED_BY` | `out` --> | [`Vulnerability`](#vulnerability) | virtual via: `runtimeMetadata -> vulnerabilities`; display: _That Is Affected By_ |

Paths:

```
Resource --[ acceptsControl : ACCEPTS ]--> Control
Resource --[ violatesControl : VIOLATES ]--> Control
Resource --[ passesControl : PASSES ]--> Control
Resource --[ testedByControl : TESTED_BY ]--> Control
Resource --[ zones : IN ]--> Zone
Resource --[ regions : IN ]--> Region
Resource --[ aiPackages : VIOLATES ]--> AIPackage
Resource --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
Resource --[ containers : RUNS_CONTAINER ]--> Container
Resource --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
```

### RuntimeResource

- **Kind:** Entity
- **Display name:** Runtime Resource
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A RuntimeResource represents a compute resource that can run workloads across multiple cloud platforms and environments.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `packages` | `HAS_INSTALLED` | `out` --> | [`Package`](#package) | virtual via: `runtimeMetadata -> packages`; display: _That Has Installed_ |
| `sbomComponents` | `HAS_INSTALLED` | `out` --> | [`SBOMComponent`](#sbomcomponent) | virtual via: `runtimeMetadata -> sbomComponents`; display: _That Has Installed_ |
| `applications` | `HAS_INSTALLED` | `out` --> | [`Application`](#application) | virtual via: `runtimeMetadata -> applications`; display: _That Has Installed_ |
| `vulnerabilities` | `AFFECTED_BY` | `out` --> | [`Vulnerability`](#vulnerability) | virtual via: `runtimeMetadata -> vulnerabilities`; display: _That Is Affected By_ |
| `containers` | `RUNS` | `out` --> | [`Container`](#container) | display: _That Has_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `vrtMalwareFindings` | `CONTAINS` | `out` --> | [`Malware`](#malware) | virtual via: `malwareFindings`; display: _Contains_ |

Paths:

```
RuntimeResource --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
RuntimeResource --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
RuntimeResource --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
RuntimeResource --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
RuntimeResource --[ containers : RUNS ]--> Container
RuntimeResource --[ zones : IN ]--> Zone
RuntimeResource --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
RuntimeResource --[ vrtMalwareFindings : CONTAINS ]--> Malware   (virtual via: malwareFindings)
```

### ValidatedExposure

- **Kind:** Entity
- **Display name:** Validated Exposure
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** The validated exposure of a resource

_No public relationships._

### Zone

- **Kind:** Entity
- **Description:** A zone, in Sysdig, is a collection of scopes that represent important areas of your business. For example, you can create a zone for your production environment, a staging environment, or a region.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtIamPolicies` | `CONTAINS` | `out` --> | [`IAMPolicy`](#iampolicy) | virtual via: `iamPolicies`; display: _That Contains_ |
| `vrtContainers` | `CONTAINS` | `out` --> | [`Container`](#container) | virtual via: `images -> containers`; display: _That Contains_ |
| `vrtImages` | `CONTAINS` | `out` --> | [`Image`](#image) | virtual via: `images`; display: _That Contains_ |
| `vrtIamUsers` | `CONTAINS` | `out` --> | [`IAMUser`](#iamuser) | virtual via: `iamUsers`; display: _That Contains_ |
| `vrtKubeIdentities` | `CONTAINS` | `out` --> | [`KubeIdentity`](#kubeidentity) | virtual via: `kubeIdentities`; display: _That Contains_ |
| `vrtCloudResources` | `CONTAINS` | `out` --> | [`CloudResource`](#cloudresource) | virtual via: `cloudResources`; display: _That Contains_ |
| `vrtKubeNodes` | `CONTAINS` | `out` --> | [`KubeNode`](#kubenode) | virtual via: `kubeNodes`; display: _That Contains_ |
| `vrtIamRoles` | `CONTAINS` | `out` --> | [`IAMRole`](#iamrole) | virtual via: `iamRoles`; display: _That Contains_ |
| `vrtIamGroups` | `CONTAINS` | `out` --> | [`IAMGroup`](#iamgroup) | virtual via: `iamGroups`; display: _That Contains_ |
| `vrtKubeWorkloads` | `CONTAINS` | `out` --> | [`KubeWorkload`](#kubeworkload) | virtual via: `kubeWorkloads`; display: _That Contains_ |
| `vrtKubeResources` | `CONTAINS` | `out` --> | [`KubeResource`](#kuberesource) | virtual via: `kubeResources`; display: _That Contains_ |
| `containsHost` | `CONTAINS` | `out` --> | [`Host`](#host) | virtual via: `host`; display: _That Contains_ |
| `host` | `IN` | `in` <-- | [`Host`](#host) | display: _With_ |

Paths:

```
Zone --[ vrtIamPolicies : CONTAINS ]--> IAMPolicy   (virtual via: iamPolicies)
Zone --[ vrtContainers : CONTAINS ]--> Container   (virtual via: images -> containers)
Zone --[ vrtImages : CONTAINS ]--> Image   (virtual via: images)
Zone --[ vrtIamUsers : CONTAINS ]--> IAMUser   (virtual via: iamUsers)
Zone --[ vrtKubeIdentities : CONTAINS ]--> KubeIdentity   (virtual via: kubeIdentities)
Zone --[ vrtCloudResources : CONTAINS ]--> CloudResource   (virtual via: cloudResources)
Zone --[ vrtKubeNodes : CONTAINS ]--> KubeNode   (virtual via: kubeNodes)
Zone --[ vrtIamRoles : CONTAINS ]--> IAMRole   (virtual via: iamRoles)
Zone --[ vrtIamGroups : CONTAINS ]--> IAMGroup   (virtual via: iamGroups)
Zone --[ vrtKubeWorkloads : CONTAINS ]--> KubeWorkload   (virtual via: kubeWorkloads)
Zone --[ vrtKubeResources : CONTAINS ]--> KubeResource   (virtual via: kubeResources)
Zone --[ containsHost : CONTAINS ]--> Host   (virtual via: host)
Zone --[ host : IN ]<-- Host
```

## Category: Findings

### AIPackage

- **Kind:** Query
- **Display name:** AI Package
- **Base entity:** [`Control`](#control)
- **Description:** Represents a control indicating that the workload contains an AI package.

_No public relationships._

### CompromisedState

- **Kind:** Entity
- **Display name:** Compromised State
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A CompromisedState that can affect an IAMUser.

_No public relationships._

### Control

- **Kind:** Entity
- **Description:** Sysdig posture controls are built on the Open Policy Agent (OPA) engine, using the OPA policy language Rego. The platform exposes the code used to create these controls and the inputs they evaluate. These controls are available in Sysdig's Posture Controls library.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtFailedIAMPolicies` | `IAM_POLICY_VIOLATES` | `out` --> | [`IAMPolicy`](#iampolicy) | virtual via: `failedIAMPolicies`; display: _That Violates_ |
| `vrtAcceptedKubeWorkloads` | `KUBE_WORKLOAD_ACCEPTS` | `out` --> | [`KubeWorkload`](#kubeworkload) | virtual via: `acceptedKubeWorkloads`; display: _That Accepts_ |
| `vrtAcceptedIAMPolicies` | `IAM_POLICY_ACCEPTS` | `out` --> | [`IAMPolicy`](#iampolicy) | virtual via: `acceptedIAMPolicies`; display: _That Accepts_ |
| `vrtCloudAcceptedResources` | `RESOURCE_ACCEPTS` | `out` --> | [`CloudResource`](#cloudresource) | virtual via: `acceptedCloudResources`; display: _That Accepts_ |
| `vrtFailedKubeIdentities` | `KUBE_IDENTITY_VIOLATES` | `out` --> | [`KubeIdentity`](#kubeidentity) | virtual via: `failedKubeIdentities`; display: _That Violates_ |
| `vrtFailedKubeWorkloads` | `KUBE_WORKLOAD_VIOLATES` | `out` --> | [`KubeWorkload`](#kubeworkload) | virtual via: `failedKubeWorkloads`; display: _That Violates_ |
| `vrtAcceptedKubeIdentities` | `KUBE_IDENTITY_ACCEPTS` | `out` --> | [`KubeIdentity`](#kubeidentity) | virtual via: `acceptedKubeIdentities`; display: _That Accepts_ |
| `vrtCloudFailedResources` | `RESOURCE_VIOLATES` | `out` --> | [`CloudResource`](#cloudresource) | virtual via: `failedCloudResources`; display: _That Violates_ |
| `passingCloudResources` | `PASSES` | `in` <-- | [`CloudResource`](#cloudresource) | display: _That Pass_ |
| `vrtPassingCloudResources` | `PASSED_BY` | `out` --> | [`CloudResource`](#cloudresource) | virtual via: `passingCloudResources`; display: _That is Passed By_ |
| `passingKubeResources` | `KUBE_RESOURCE_PASSES` | `in` <-- | [`KubeResource`](#kuberesource) | display: _That Pass_ |
| `vrtPassingKubeResources` | `KUBE_RESOURCE_PASSED_BY` | `out` --> | [`KubeResource`](#kuberesource) | virtual via: `passingKubeResources`; display: _That is Passed By_ |
| `failingKubeResources` | `VIOLATES` | `in` <-- | [`KubeResource`](#kuberesource) | display: _That Violates_ |
| `vrtfailingKubeResources` | `KUBE_RESOURCE_VIOLATES` | `out` --> | [`KubeResource`](#kuberesource) | virtual via: `failingKubeResources`; display: _That is Failed By_ |
| `acceptingKubeResources` | `ACCEPTS` | `in` <-- | [`KubeResource`](#kuberesource) | display: _That Accepts_ |
| `vrtAcceptingKubeResources` | `KUBE_RESOURCE_ACCEPTS` | `out` --> | [`KubeResource`](#kuberesource) | virtual via: `acceptingKubeResources`; display: _That is Accepted By_ |
| `passedKubeNodes` | `KUBE_NODE_PASSES` | `in` <-- | [`KubeNode`](#kubenode) | virtual via: `kubeNodes`; display: _That Passes_ |
| `violatedKubeNodes` | `KUBE_NODE_VIOLATES` | `in` <-- | [`KubeNode`](#kubenode) | virtual via: `kubeNodes`; display: _That Violates_ |
| `acceptedKubeNodes` | `KUBE_NODE_ACCEPTS` | `in` <-- | [`KubeNode`](#kubenode) | virtual via: `kubeNodes`; display: _That Accepts_ |

Paths:

```
Control --[ vrtFailedIAMPolicies : IAM_POLICY_VIOLATES ]--> IAMPolicy   (virtual via: failedIAMPolicies)
Control --[ vrtAcceptedKubeWorkloads : KUBE_WORKLOAD_ACCEPTS ]--> KubeWorkload   (virtual via: acceptedKubeWorkloads)
Control --[ vrtAcceptedIAMPolicies : IAM_POLICY_ACCEPTS ]--> IAMPolicy   (virtual via: acceptedIAMPolicies)
Control --[ vrtCloudAcceptedResources : RESOURCE_ACCEPTS ]--> CloudResource   (virtual via: acceptedCloudResources)
Control --[ vrtFailedKubeIdentities : KUBE_IDENTITY_VIOLATES ]--> KubeIdentity   (virtual via: failedKubeIdentities)
Control --[ vrtFailedKubeWorkloads : KUBE_WORKLOAD_VIOLATES ]--> KubeWorkload   (virtual via: failedKubeWorkloads)
Control --[ vrtAcceptedKubeIdentities : KUBE_IDENTITY_ACCEPTS ]--> KubeIdentity   (virtual via: acceptedKubeIdentities)
Control --[ vrtCloudFailedResources : RESOURCE_VIOLATES ]--> CloudResource   (virtual via: failedCloudResources)
Control --[ passingCloudResources : PASSES ]<-- CloudResource
Control --[ vrtPassingCloudResources : PASSED_BY ]--> CloudResource   (virtual via: passingCloudResources)
Control --[ passingKubeResources : KUBE_RESOURCE_PASSES ]<-- KubeResource
Control --[ vrtPassingKubeResources : KUBE_RESOURCE_PASSED_BY ]--> KubeResource   (virtual via: passingKubeResources)
Control --[ failingKubeResources : VIOLATES ]<-- KubeResource
Control --[ vrtfailingKubeResources : KUBE_RESOURCE_VIOLATES ]--> KubeResource   (virtual via: failingKubeResources)
Control --[ acceptingKubeResources : ACCEPTS ]<-- KubeResource
Control --[ vrtAcceptingKubeResources : KUBE_RESOURCE_ACCEPTS ]--> KubeResource   (virtual via: acceptingKubeResources)
Control --[ passedKubeNodes : KUBE_NODE_PASSES ]<-- KubeNode   (virtual via: kubeNodes)
Control --[ violatedKubeNodes : KUBE_NODE_VIOLATES ]<-- KubeNode   (virtual via: kubeNodes)
Control --[ acceptedKubeNodes : KUBE_NODE_ACCEPTS ]<-- KubeNode   (virtual via: kubeNodes)
```

### IdentityFinding

- **Kind:** Entity
- **Display name:** Identity Finding
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An Identity Finding

_No public relationships._

### Malware

- **Kind:** Entity
- **Display name:** Malware Finding
- **Description:** When a Malware Control policy is created, depending on the options selected, Sysdig Agent can use a managed database to monitor executions in a container/on the node for any malware. When a malicious binary is detected, the agent generates an event and can optionally block the execution from starting.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `host` | `FOUND_IN` | `out` --> | [`Host`](#host) | display: _That Is Found In_ |
| `cloudResources` | `FOUND_IN` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Is Found In_ |

Paths:

```
Malware --[ host : FOUND_IN ]--> Host
Malware --[ cloudResources : FOUND_IN ]--> CloudResource
```

### Policy

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Policy represents a policy in Sysdig Secure.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _In_ |

Paths:

```
Policy --[ zones : IN ]--> Zone
```

### PrivilegedControl

- **Kind:** Query
- **Display name:** Privileged Control
- **Base entity:** [`Control`](#control)
- **Description:** Represents a privileged control.

_No public relationships._

### RiskFinding

- **Kind:** Entity
- **Display name:** Risk Finding
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A RiskFinding that can affect an IAM resource.

_No public relationships._

### RuntimeMetadata

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A RuntimeMetadata represents an intermediate node between RuntimeResource and Vulnerability where image/container metadata is stored.

_No public relationships._

### S3AcceptsHTTP

- **Kind:** Query
- **Display name:** S3 Accepts HTTP
- **Base entity:** [`Control`](#control)
- **Description:** Represents a control that accepts HTTP requests to S3.

_No public relationships._

### S3VersioningDisabled

- **Kind:** Query
- **Display name:** S3 Versioning Disabled
- **Base entity:** [`Control`](#control)
- **Description:** Represents a control that disables versioning on S3 buckets.

_No public relationships._

### SensitiveData

- **Kind:** Entity
- **Display name:** Sensitive Data
- **Description:** Sensitive Data is part of a hierarchy of data classes and data categories of sensitive data.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `childrenSensitiveData` | `PARENT_OF` | `out` --> | [`SensitiveData`](#sensitivedata) | display: _Parent Of_ |
| `parentSensitiveData` | `PARENT_OF` | `in` <-- | [`SensitiveData`](#sensitivedata) | display: _Parent Of_ |
| `virtParentSensitiveData` | `CHILD_OF` | `in` <-- | [`SensitiveData`](#sensitivedata) | virtual via: `parentSensitiveData`; display: _Parent Sensitive Data Finding_ |

Paths:

```
SensitiveData --[ childrenSensitiveData : PARENT_OF ]--> SensitiveData
SensitiveData --[ parentSensitiveData : PARENT_OF ]<-- SensitiveData
SensitiveData --[ virtParentSensitiveData : CHILD_OF ]<-- SensitiveData   (virtual via: parentSensitiveData)
```

### SensitiveDataFinding

- **Kind:** Entity
- **Display name:** Sensitive Data Finding
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A SensitiveDataFinding can affect cloud resources related to data (blob storage, file systems, etc)

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `findingDetails` | `PARENT_OF` | `out` --> | [`SensitiveDataFindingDetail`](#sensitivedatafindingdetail) | display: _Parent Of_ |

Paths:

```
SensitiveDataFinding --[ findingDetails : PARENT_OF ]--> SensitiveDataFindingDetail
```

### SensitiveDataFindingDetail

- **Kind:** Entity
- **Display name:** Sensitive Data Finding Detail
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Finding Detail is a particular instance of a Sensitive Data violation such as a file, DB record, etc.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `finding` | `PARENT_OF` | `in` <-- | [`SensitiveDataFinding`](#sensitivedatafinding) |  |
| `virtFindings` | `CHILD_OF` | `in` <-- | [`SensitiveDataFinding`](#sensitivedatafinding) | virtual via: `finding`; display: _Parent Sensitive Data Finding_ |

Paths:

```
SensitiveDataFindingDetail --[ finding : PARENT_OF ]<-- SensitiveDataFinding
SensitiveDataFindingDetail --[ virtFindings : CHILD_OF ]<-- SensitiveDataFinding   (virtual via: finding)
```

### SourceCodeFile

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Source Code File represents a file in the source code repository.

_No public relationships._

### SourceCodeRepository

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Source Code Repository represents a repository in the external source code management system.

_No public relationships._

### VulnerabilityNew

- **Kind:** Query
- **Base entity:** [`Vulnerability`](#vulnerability)
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Vulnerability represents a security weakness in a system or application.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtImagesNew` | `AFFECTS` | `out` --> | [`ImageNew`](#imagenew) | virtual; display: _That Affects_ |
| `packagesNew` | `REFERS_TO_PACKAGE` | `out` --> | [`PackageNew`](#packagenew) | display: _Refers To Package_ |
| `vrtKubeWorkloads` | `AFFECTS` | `out` --> | [`KubeWorkload`](#kubeworkload) | virtual; display: _That Affects_ |
| `vrtHosts` | `AFFECTS` | `out` --> | [`Host`](#host) | virtual; display: _That Affects_ |

Paths:

```
VulnerabilityNew --[ vrtImagesNew : AFFECTS ]--> ImageNew
VulnerabilityNew --[ packagesNew : REFERS_TO_PACKAGE ]--> PackageNew
VulnerabilityNew --[ vrtKubeWorkloads : AFFECTS ]--> KubeWorkload
VulnerabilityNew --[ vrtHosts : AFFECTS ]--> Host
```

## Category: Identity

### CIEMAccessGroup

- **Kind:** Entity
- **Display name:** Group Access
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Group Access

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `cloudIAMGroups` | `PARENT_OF` | `in` <-- | [`CloudIAMGroup`](#cloudiamgroup) | display: _With_ |

Paths:

```
CIEMAccessGroup --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
CIEMAccessGroup --[ cloudIAMGroups : PARENT_OF ]<-- CloudIAMGroup
```

### CIEMAccessPolicy

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Policy Access

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `cloudIAMPolicies` | `PARENT_OF` | `in` <-- | [`CloudIAMPolicy`](#cloudiampolicy) | display: _With_ |

Paths:

```
CIEMAccessPolicy --[ cloudIAMPolicies : PARENT_OF ]<-- CloudIAMPolicy
```

### CIEMAccessRole

- **Kind:** Entity
- **Display name:** Role Access
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Role Access

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `cloudResources` | `HAS_ACCESS` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Has Access_ |
| `cloudIAMRoles` | `PARENT_OF` | `in` <-- | [`CloudIAMRole`](#cloudiamrole) | display: _With_ |

Paths:

```
CIEMAccessRole --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
CIEMAccessRole --[ cloudResources : HAS_ACCESS ]--> CloudResource
CIEMAccessRole --[ cloudIAMRoles : PARENT_OF ]<-- CloudIAMRole
```

### CIEMAccessServiceIdentity

- **Kind:** Entity
- **Display name:** Service Identity Access
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Service Identity Access

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `cloudResources` | `HAS_ACCESS` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Has Access_ |
| `cloudIAMServiceIdentities` | `PARENT_OF` | `in` <-- | [`CloudIAMServiceIdentity`](#cloudiamserviceidentity) | display: _With_ |

Paths:

```
CIEMAccessServiceIdentity --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
CIEMAccessServiceIdentity --[ cloudResources : HAS_ACCESS ]--> CloudResource
CIEMAccessServiceIdentity --[ cloudIAMServiceIdentities : PARENT_OF ]<-- CloudIAMServiceIdentity
```

### CIEMAccessUnionUser

- **Kind:** Union
- **Display name:** CIEM Access Union User
- **Resolves to:** [ CIEMAccessUser, CIEMAccessRole, CIEMAccessServiceIdentity ]
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** CIEM access union user to fetch users/roles/service identities CIEM access nodes with one label

_No public relationships._

### CIEMAccessUser

- **Kind:** Entity
- **Display name:** User Access
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** User Access

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `cloudResources` | `HAS_ACCESS` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Has Access_ |
| `cloudIAMUsers` | `PARENT_OF` | `in` <-- | [`CloudIAMUser`](#cloudiamuser) | display: _With_ |

Paths:

```
CIEMAccessUser --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
CIEMAccessUser --[ cloudResources : HAS_ACCESS ]--> CloudResource
CIEMAccessUser --[ cloudIAMUsers : PARENT_OF ]<-- CloudIAMUser
```

### CIEMResource

- **Kind:** Union
- **Resolves to:** [ CIEMAccessUser, CIEMAccessRole, CIEMAccessPolicy, CIEMAccessGroup, CIEMAccessServiceIdentity ]
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Represents a generic resource in the customer environment. A resource can be any cloud resource or any Kubernetes resource. Use the resourceType field to specify the type of the resource.

_No public relationships._

### CIEMUnionUser

- **Kind:** Union
- **Display name:** CIEM Union User
- **Resolves to:** [ CloudIAMUser, CloudIAMRole, CloudIAMServiceIdentity ]
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** CIEM union user to fetch users/roles/service identities with one label

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |

Paths:

```
CIEMUnionUser --[ zones : IN ]--> Zone
```

### CloudGroup

- **Kind:** Entity
- **Display name:** Cloud Group
- **Provider:** MultiCloud
- **Description:** Identity resource of type Group

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |

Paths:

```
CloudGroup --[ regions : IN ]--> Region
CloudGroup --[ zones : IN ]--> Zone
```

### CloudIAMGroup

- **Kind:** Entity
- **Display name:** Cloud IAM Group
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Cloud IAM Group represents a collection of users for managing cloud access permissions.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `roles` | `HAS_ROLE` | `out` --> | [`CloudIAMRole`](#cloudiamrole) | display: _That Has_ |
| `groupsMember` | `MEMBER_OF` | `out` --> | [`CloudIAMGroup`](#cloudiamgroup) | display: _Is Member Of_ |
| `users` | `MEMBER_OF` | `in` <-- | [`CloudIAMUser`](#cloudiamuser) | display: _Contains_ |
| `serviceIdentities` | `MEMBER_OF` | `in` <-- | [`CloudIAMServiceIdentity`](#cloudiamserviceidentity) | display: _Contains_ |
| `groupsParent` | `MEMBER_OF` | `in` <-- | [`CloudIAMGroup`](#cloudiamgroup) | display: _Contains_ |
| `cloudResources` | `PARENT_OF` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Is Parent Of_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |

Paths:

```
CloudIAMGroup --[ regions : IN ]--> Region
CloudIAMGroup --[ roles : HAS_ROLE ]--> CloudIAMRole
CloudIAMGroup --[ groupsMember : MEMBER_OF ]--> CloudIAMGroup
CloudIAMGroup --[ users : MEMBER_OF ]<-- CloudIAMUser
CloudIAMGroup --[ serviceIdentities : MEMBER_OF ]<-- CloudIAMServiceIdentity
CloudIAMGroup --[ groupsParent : MEMBER_OF ]<-- CloudIAMGroup
CloudIAMGroup --[ cloudResources : PARENT_OF ]--> CloudResource
CloudIAMGroup --[ zones : IN ]--> Zone
```

### CloudIAMPolicy

- **Kind:** Entity
- **Display name:** Cloud IAM Policy
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Cloud IAM Policy defines rules and permissions for cloud IAM entities.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |

Paths:

```
CloudIAMPolicy --[ regions : IN ]--> Region
CloudIAMPolicy --[ zones : IN ]--> Zone
```

### CloudIAMRole

- **Kind:** Entity
- **Display name:** Cloud IAM Role
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Cloud IAM Role represents a set of permissions for cloud access control.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `s3Buckets` | `HAS_ACCESS` | `out` --> | [`S3Bucket`](#s3bucket) | display: _That Has Access to_ |
| `cloudResources` | `HAS_ACCESS` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Has Access_ |
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `users` | `HAS_ROLE` | `in` <-- | [`CloudIAMUser`](#cloudiamuser) | display: _Users that have this role_ |
| `groups` | `HAS_ROLE` | `in` <-- | [`CloudIAMGroup`](#cloudiamgroup) | display: _Groups that have this role_ |
| `serviceIdentities` | `HAS_ROLE` | `in` <-- | [`CloudIAMServiceIdentity`](#cloudiamserviceidentity) | display: _Service Identities that have this role_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |

Paths:

```
CloudIAMRole --[ s3Buckets : HAS_ACCESS ]--> S3Bucket
CloudIAMRole --[ cloudResources : HAS_ACCESS ]--> CloudResource
CloudIAMRole --[ regions : IN ]--> Region
CloudIAMRole --[ users : HAS_ROLE ]<-- CloudIAMUser
CloudIAMRole --[ groups : HAS_ROLE ]<-- CloudIAMGroup
CloudIAMRole --[ serviceIdentities : HAS_ROLE ]<-- CloudIAMServiceIdentity
CloudIAMRole --[ zones : IN ]--> Zone
```

### CloudIAMServiceIdentity

- **Kind:** Entity
- **Display name:** Cloud IAM Service Identity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Cloud IAM Service Identity represents a cloud-based identity used by services.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `roles` | `HAS_ROLE` | `out` --> | [`CloudIAMRole`](#cloudiamrole) | display: _That Has Role_ |
| `groups` | `MEMBER_OF` | `out` --> | [`CloudIAMGroup`](#cloudiamgroup) | display: _Is Member Of_ |
| `keys` | `HAS_KEY` | `out` --> | [`CloudIAMServiceIdentityKey`](#cloudiamserviceidentitykey) | display: _Has Key_ |
| `cloudResources` | `PARENT_OF` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Is Parent Of_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |

Paths:

```
CloudIAMServiceIdentity --[ regions : IN ]--> Region
CloudIAMServiceIdentity --[ roles : HAS_ROLE ]--> CloudIAMRole
CloudIAMServiceIdentity --[ groups : MEMBER_OF ]--> CloudIAMGroup
CloudIAMServiceIdentity --[ keys : HAS_KEY ]--> CloudIAMServiceIdentityKey
CloudIAMServiceIdentity --[ cloudResources : PARENT_OF ]--> CloudResource
CloudIAMServiceIdentity --[ zones : IN ]--> Zone
```

### CloudIAMServiceIdentityKey

- **Kind:** Entity
- **Display name:** Cloud IAM Service Identity Key
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Cloud IAM Service Identity Key represents a credential for a cloud service identity.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `serviceIdentities` | `HAS_KEY` | `in` <-- | [`CloudIAMServiceIdentity`](#cloudiamserviceidentity) | display: _Service Accounts that have this key_ |
| `vrtServiceIdentities` | `KEY_OF` | `out` --> | [`CloudIAMServiceIdentity`](#cloudiamserviceidentity) | virtual via: `serviceIdentities`; display: _Keys held by Service Account_ |

Paths:

```
CloudIAMServiceIdentityKey --[ serviceIdentities : HAS_KEY ]<-- CloudIAMServiceIdentity
CloudIAMServiceIdentityKey --[ vrtServiceIdentities : KEY_OF ]--> CloudIAMServiceIdentity   (virtual via: serviceIdentities)
```

### CloudIAMUser

- **Kind:** Entity
- **Display name:** Cloud IAM User
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Cloud IAM User represents an identity for managing cloud resources.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `roles` | `HAS_ROLE` | `out` --> | [`CloudIAMRole`](#cloudiamrole) | display: _That Has Role_ |
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `cloudResources` | `HAS_ACCESS` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Has Access_ |

Paths:

```
CloudIAMUser --[ regions : IN ]--> Region
CloudIAMUser --[ roles : HAS_ROLE ]--> CloudIAMRole
CloudIAMUser --[ acceptedControls : ACCEPTS ]--> Control
CloudIAMUser --[ failedControls : VIOLATES ]--> Control
CloudIAMUser --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
CloudIAMUser --[ zones : IN ]--> Zone
CloudIAMUser --[ cloudResources : HAS_ACCESS ]--> CloudResource
```

### CloudPolicy

- **Kind:** Entity
- **Display name:** Cloud Policy
- **Provider:** MultiCloud
- **Description:** An IAM Policy defines rules and permissions for cloud IAM entities at the cloud provider tenant/organization level.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |

Paths:

```
CloudPolicy --[ regions : IN ]--> Region
CloudPolicy --[ zones : IN ]--> Zone
CloudPolicy --[ failedControls : VIOLATES ]--> Control
```

### CloudRole

- **Kind:** Entity
- **Display name:** Cloud Role
- **Provider:** MultiCloud
- **Description:** Identity resource of type Role

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `cloudResources` | `HAS_ACCESS` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Has Access_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |

Paths:

```
CloudRole --[ regions : IN ]--> Region
CloudRole --[ cloudResources : HAS_ACCESS ]--> CloudResource
CloudRole --[ zones : IN ]--> Zone
```

### CloudServiceIdentity

- **Kind:** Entity
- **Display name:** Cloud Service Identity
- **Provider:** MultiCloud
- **Description:** A Service Identity represents a cloud-based identity used by services at the cloud provider tenant/organization level.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |

Paths:

```
CloudServiceIdentity --[ regions : IN ]--> Region
CloudServiceIdentity --[ zones : IN ]--> Zone
```

### CloudUser

- **Kind:** Entity
- **Display name:** Cloud User
- **Provider:** MultiCloud
- **Description:** Identity resource of type User

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `runtimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `ciemAccessUsers -> runtimeEvents`; display: _That Generates_ |

Paths:

```
CloudUser --[ regions : IN ]--> Region
CloudUser --[ zones : IN ]--> Zone
CloudUser --[ acceptedControls : ACCEPTS ]--> Control
CloudUser --[ failedControls : VIOLATES ]--> Control
CloudUser --[ runtimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: ciemAccessUsers -> runtimeEvents)
```

### IAMInstanceProfile

- **Kind:** Entity
- **Display name:** IAM Instance Profile
- **Provider:** AWS
- **Description:** An IAM Instance Profile represents a container for IAM roles assigned to EC2 instances.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `regions` | `IN` | `out` --> | [`Region`](#region) | display: _That Is In_ |
| `iamRoles` | `CONTAINS` | `out` --> | [`IAMRole`](#iamrole) | display: _That Contains_ |

Paths:

```
IAMInstanceProfile --[ regions : IN ]--> Region
IAMInstanceProfile --[ iamRoles : CONTAINS ]--> IAMRole
```

### ScopedIAMGroup

- **Kind:** Entity
- **Display name:** Scoped IAM Group
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Cloud group scoped to a particular account/project/subscription

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `cloudIAMGroups` | `SCOPED_AS` | `in` <-- | [`CloudIAMGroup`](#cloudiamgroup) |  |

Paths:

```
ScopedIAMGroup --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
ScopedIAMGroup --[ cloudIAMGroups : SCOPED_AS ]<-- CloudIAMGroup
```

### ScopedIAMPolicy

- **Kind:** Entity
- **Display name:** Scoped IAM Policy
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Cloud Policy scoped to a particular account/project/subscription

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `cloudIAMPolicies` | `SCOPED_AS` | `in` <-- | [`CloudIAMPolicy`](#cloudiampolicy) | display: _Scoped As_ |

Paths:

```
ScopedIAMPolicy --[ cloudIAMPolicies : SCOPED_AS ]<-- CloudIAMPolicy
```

### ScopedIAMResource

- **Kind:** Union
- **Resolves to:** [ ScopedIAMUser, ScopedIAMRole, ScopedIAMPolicy, ScopedIAMGroup, ScopedIAMServiceIdentity ]
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Represents a generic IAM resource that is scoped to the context of an account/project/subscription.

_No public relationships._

### ScopedIAMRole

- **Kind:** Entity
- **Display name:** Scoped IAM Role
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Cloud Role scoped to a particular account/project/subscription

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `cloudResources` | `HAS_ACCESS` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Has Access_ |
| `s3Buckets` | `HAS_ACCESS` | `out` --> | [`S3Bucket`](#s3bucket) | display: _That Has Access to_ |
| `cloudIAMRoles` | `SCOPED_AS` | `in` <-- | [`CloudIAMRole`](#cloudiamrole) | display: _Scoped As_ |

Paths:

```
ScopedIAMRole --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
ScopedIAMRole --[ cloudResources : HAS_ACCESS ]--> CloudResource
ScopedIAMRole --[ s3Buckets : HAS_ACCESS ]--> S3Bucket
ScopedIAMRole --[ cloudIAMRoles : SCOPED_AS ]<-- CloudIAMRole
```

### ScopedIAMServiceIdentity

- **Kind:** Entity
- **Display name:** Scoped IAM Service Identity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Cloud Service Identity scoped to a particular account/project/subscription

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `cloudResources` | `HAS_ACCESS` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Has Access_ |
| `cloudIAMServiceIdentities` | `SCOPED_AS` | `in` <-- | [`CloudIAMServiceIdentity`](#cloudiamserviceidentity) | display: _Scoped As_ |

Paths:

```
ScopedIAMServiceIdentity --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
ScopedIAMServiceIdentity --[ cloudResources : HAS_ACCESS ]--> CloudResource
ScopedIAMServiceIdentity --[ cloudIAMServiceIdentities : SCOPED_AS ]<-- CloudIAMServiceIdentity
```

### ScopedIAMUser

- **Kind:** Entity
- **Display name:** Scoped IAM User
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Cloud User scoped to a particular account/project/subscription

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `cloudResources` | `HAS_ACCESS` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Has Access_ |
| `cloudIAMUsers` | `SCOPED_AS` | `in` <-- | [`CloudIAMUser`](#cloudiamuser) | display: _Scoped As_ |
| `vrtCloudIAMUsers` | `REPRESENTS` | `out` --> | [`CloudIAMUser`](#cloudiamuser) | virtual via: `cloudIAMUsers`; display: _Cloud user represented_ |

Paths:

```
ScopedIAMUser --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
ScopedIAMUser --[ cloudResources : HAS_ACCESS ]--> CloudResource
ScopedIAMUser --[ cloudIAMUsers : SCOPED_AS ]<-- CloudIAMUser
ScopedIAMUser --[ vrtCloudIAMUsers : REPRESENTS ]--> CloudIAMUser   (virtual via: cloudIAMUsers)
```

## Category: Kubernetes

### GitKubeWorkload

- **Kind:** Entity
- **Display name:** Git Kubernetes Workload
- **Provider:** Git
- **Description:** A Kubernetes Workload represents an application or process running in Kubernetes.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |

Paths:

```
GitKubeWorkload --[ failedControls : VIOLATES ]--> Control
GitKubeWorkload --[ acceptedControls : ACCEPTS ]--> Control
GitKubeWorkload --[ zones : IN ]--> Zone
```

### KubeCluster

- **Kind:** Entity
- **Display name:** Kubernetes Cluster
- **Provider:** Kubernetes
- **Description:** A Kubernetes Cluster represents a set of nodes running containerized workloads.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _That Is In_ |
| `vrtKubeNamespaces` | `CONTAINS` | `out` --> | [`KubeNamespace`](#kubenamespace) | virtual via: `kubeNamespaces`; display: _That Contains_ |
| `vrtKubeNodes` | `CONTAINS` | `out` --> | [`KubeNode`](#kubenode) | virtual via: `kubeNodes`; display: _That Contains_ |
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `regions` | `IN` | `out` --> | [`Region`](#region) | virtual via: `kubeNodes -> deployedOnCloudResource -> regions`; display: _That Is In_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `kubeNamespaces -> kubeWorkloads -> runtimeEvents`; display: _That Generates_ |

Paths:

```
KubeCluster --[ zones : IN ]--> Zone
KubeCluster --[ vrtKubeNamespaces : CONTAINS ]--> KubeNamespace   (virtual via: kubeNamespaces)
KubeCluster --[ vrtKubeNodes : CONTAINS ]--> KubeNode   (virtual via: kubeNodes)
KubeCluster --[ acceptedControls : ACCEPTS ]--> Control
KubeCluster --[ failedControls : VIOLATES ]--> Control
KubeCluster --[ regions : IN ]--> Region   (virtual via: kubeNodes -> deployedOnCloudResource -> regions)
KubeCluster --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: kubeNamespaces -> kubeWorkloads -> runtimeEvents)
```

### KubeIdentity

- **Kind:** Entity
- **Display name:** Kubernetes Identity
- **Provider:** Kubernetes
- **Description:** A Kubernetes Identity represents a user or service account within a Kubernetes cluster.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `namespaces` | `IN` | `out` --> | [`KubeNamespace`](#kubenamespace) | display: _That Is In_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |

Paths:

```
KubeIdentity --[ zones : IN ]--> Zone
KubeIdentity --[ namespaces : IN ]--> KubeNamespace
KubeIdentity --[ failedControls : VIOLATES ]--> Control
KubeIdentity --[ acceptedControls : ACCEPTS ]--> Control
```

### KubeIngress

- **Kind:** Entity
- **Display name:** Kubernetes Ingress
- **Provider:** Kubernetes
- **Description:** A Kubernetes Ingress represents an API object that manages external access to services.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `kubeNamespaces` | `IN` | `out` --> | [`KubeNamespace`](#kubenamespace) | display: _That Is In_ |
| `kubeServices` | `EXPOSES` | `out` --> | [`KubeService`](#kubeservice) | display: _That Exposes_ |
| `aiPackages` | `VIOLATES` | `out` --> | [`AIPackage`](#aipackage) | display: _That Contains_ |

Paths:

```
KubeIngress --[ kubeNamespaces : IN ]--> KubeNamespace
KubeIngress --[ kubeServices : EXPOSES ]--> KubeService
KubeIngress --[ aiPackages : VIOLATES ]--> AIPackage
```

### KubeNode

- **Kind:** Entity
- **Display name:** Kubernetes Node
- **Provider:** Kubernetes
- **Description:** A KubeNode represents a worker node in a Kubernetes cluster.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `packages` | `HAS_INSTALLED` | `out` --> | [`Package`](#package) | virtual via: `runtimeMetadata -> packages`; display: _That Has Installed_ |
| `sbomComponents` | `HAS_INSTALLED` | `out` --> | [`SBOMComponent`](#sbomcomponent) | virtual via: `runtimeMetadata -> sbomComponents`; display: _That Has Installed_ |
| `applications` | `HAS_INSTALLED` | `out` --> | [`Application`](#application) | virtual via: `runtimeMetadata -> applications`; display: _That Has Installed_ |
| `vulnerabilities` | `AFFECTED_BY` | `out` --> | [`Vulnerability`](#vulnerability) | virtual via: `runtimeMetadata -> vulnerabilities`; display: _That Is Affected By_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `kubeClusters` | `IN` | `out` --> | [`KubeCluster`](#kubecluster) | display: _That Is In_ |
| `deployedOnCloudResource` | `DEPLOYED_ON` | `out` --> | [`CloudResource`](#cloudresource) | display: _That Is Deployed On_ |
| `regions` | `IN` | `out` --> | [`Region`](#region) | virtual via: `deployedOnCloudResource -> regions`; display: _That Is In_ |
| `vrtThreats` | `GENERATES` | `out` --> | [`Threat`](#threat) | virtual via: `threats`; display: _That Generates_ |

Paths:

```
KubeNode --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
KubeNode --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
KubeNode --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
KubeNode --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
KubeNode --[ zones : IN ]--> Zone
KubeNode --[ kubeClusters : IN ]--> KubeCluster
KubeNode --[ deployedOnCloudResource : DEPLOYED_ON ]--> CloudResource
KubeNode --[ regions : IN ]--> Region   (virtual via: deployedOnCloudResource -> regions)
KubeNode --[ vrtThreats : GENERATES ]--> Threat   (virtual via: threats)
```

### KubeResource

- **Kind:** Entity
- **Display name:** Kubernetes Resource
- **Provider:** Kubernetes
- **Description:** A Kubernetes Resource represents an entity managed within a Kubernetes cluster.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _That Is In_ |
| `kubeNamespaces` | `IN` | `out` --> | [`KubeNamespace`](#kubenamespace) | display: _That Is In_ |
| `containers` | `HAS` | `out` --> | [`Container`](#container) | display: _That Has_ |
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `passedControls` | `PASSES` | `out` --> | [`Control`](#control) | display: _That Passes_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `vulnerabilities` | `AFFECTED_BY` | `out` --> | [`Vulnerability`](#vulnerability) | virtual via: `containers -> images -> containerImages -> vulnerabilities`; display: _That Is Affected By_ |
| `packages` | `HAS_INSTALLED` | `out` --> | [`Package`](#package) | virtual via: `containers -> images -> containerImages -> packages`; display: _That Has Installed_ |
| `sbomComponents` | `HAS_INSTALLED` | `out` --> | [`SBOMComponent`](#sbomcomponent) | virtual via: `containers -> images -> containerImages -> sbomComponents`; display: _That Has Installed_ |
| `applications` | `HAS_INSTALLED` | `out` --> | [`Application`](#application) | virtual via: `containers -> images -> containerImages -> applications`; display: _That Has Installed_ |

Paths:

```
KubeResource --[ zones : IN ]--> Zone
KubeResource --[ kubeNamespaces : IN ]--> KubeNamespace
KubeResource --[ containers : HAS ]--> Container
KubeResource --[ acceptedControls : ACCEPTS ]--> Control
KubeResource --[ failedControls : VIOLATES ]--> Control
KubeResource --[ passedControls : PASSES ]--> Control
KubeResource --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
KubeResource --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: containers -> images -> containerImages -> vulnerabilities)
KubeResource --[ packages : HAS_INSTALLED ]--> Package   (virtual via: containers -> images -> containerImages -> packages)
KubeResource --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: containers -> images -> containerImages -> sbomComponents)
KubeResource --[ applications : HAS_INSTALLED ]--> Application   (virtual via: containers -> images -> containerImages -> applications)
```

### KubeService

- **Kind:** Entity
- **Display name:** Kubernetes Service
- **Provider:** Kubernetes
- **Description:** A Kubernetes Service represents a logical abstraction of a group of pods.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtKubeIngress` | `EXPOSED_BY` | `out` --> | [`KubeIngress`](#kubeingress) | virtual via: `kubeIngress`; display: _That Is Exposed By_ |
| `kubeWorkloads` | `EXPOSES` | `out` --> | [`KubeWorkload`](#kubeworkload) | display: _That Exposes_ |
| `kubeResources` | `EXPOSES` | `out` --> | [`KubeResource`](#kuberesource) | display: _That Exposes_ |

Paths:

```
KubeService --[ vrtKubeIngress : EXPOSED_BY ]--> KubeIngress   (virtual via: kubeIngress)
KubeService --[ kubeWorkloads : EXPOSES ]--> KubeWorkload
KubeService --[ kubeResources : EXPOSES ]--> KubeResource
```

### KubeWorkload

- **Kind:** Entity
- **Display name:** Kubernetes Workload
- **Provider:** Kubernetes
- **Description:** A KubeWorkload represents a workload in a Kubernetes cluster.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `containersNew` | `HAS` | `out` --> | [`ContainerNew`](#containernew) | display: _Has_ |
| `vrtContainersNew` | `RUNS` | `out` --> | [`ContainerNew`](#containernew) | display: _That Runs_ |
| `containers` | `HAS` | `out` --> | [`Container`](#container) | display: _With_ |
| `vrtContainers` | `RUNS` | `out` --> | [`Container`](#container) | display: _That Runs_ |
| `vrtVulnerabilitiesNew` | `AFFECTED_BY` | `out` --> | [`VulnerabilityNew`](#vulnerabilitynew) | virtual; display: _That Is Affected By_ |
| `vulnerabilities` | `AFFECTED_BY` | `out` --> | [`Vulnerability`](#vulnerability) | virtual via: `containers -> images -> containerImages -> vulnerabilities`; display: _That Is Affected By_ |
| `vrKubeServices` | `EXPOSED_BY` | `out` --> | [`KubeService`](#kubeservice) | virtual via: `kubeServices`; display: _That Is Exposed By_ |
| `namespaces` | `IN` | `out` --> | [`KubeNamespace`](#kubenamespace) | display: _With_ |
| `acceptedControls` | `ACCEPTS` | `out` --> | [`Control`](#control) | display: _That Accepts_ |
| `vrtRuntimeEvents` | `GENERATES` | `out` --> | [`RuntimeEvent`](#runtimeevent) | virtual via: `runtimeEvents`; display: _That Generates_ |
| `vrtThreats` | `GENERATES` | `out` --> | [`Threat`](#threat) | virtual via: `threats`; display: _That Generates_ |
| `kubeClusters` | `IN` | `out` --> | [`KubeCluster`](#kubecluster) | virtual via: `namespaces -> kubeClusters`; display: _With_ |
| `failedControls` | `VIOLATES` | `out` --> | [`Control`](#control) | display: _That Violates_ |
| `passedControls` | `PASSES` | `out` --> | [`Control`](#control) | display: _That Passes_ |
| `aiPackages` | `VIOLATES` | `out` --> | [`AIPackage`](#aipackage) | display: _That Contains_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `regions` | `IN` | `out` --> | [`Region`](#region) | virtual via: `namespaces -> kubeClusters -> kubeNodes -> deployedOnCloudResource -> regions`; display: _That Is In_ |

Paths:

```
KubeWorkload --[ containersNew : HAS ]--> ContainerNew
KubeWorkload --[ vrtContainersNew : RUNS ]--> ContainerNew
KubeWorkload --[ containers : HAS ]--> Container
KubeWorkload --[ vrtContainers : RUNS ]--> Container
KubeWorkload --[ vrtVulnerabilitiesNew : AFFECTED_BY ]--> VulnerabilityNew
KubeWorkload --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: containers -> images -> containerImages -> vulnerabilities)
KubeWorkload --[ vrKubeServices : EXPOSED_BY ]--> KubeService   (virtual via: kubeServices)
KubeWorkload --[ namespaces : IN ]--> KubeNamespace
KubeWorkload --[ acceptedControls : ACCEPTS ]--> Control
KubeWorkload --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
KubeWorkload --[ vrtThreats : GENERATES ]--> Threat   (virtual via: threats)
KubeWorkload --[ kubeClusters : IN ]--> KubeCluster   (virtual via: namespaces -> kubeClusters)
KubeWorkload --[ failedControls : VIOLATES ]--> Control
KubeWorkload --[ passedControls : PASSES ]--> Control
KubeWorkload --[ aiPackages : VIOLATES ]--> AIPackage
KubeWorkload --[ zones : IN ]--> Zone
KubeWorkload --[ regions : IN ]--> Region   (virtual via: namespaces -> kubeClusters -> kubeNodes -> deployedOnCloudResource -> regions)
```

## Category: Metadata

### Label

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Label represents a label attached to a resource.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtCloudResources` | `RESOURCE_HAS_LABEL` | `out` --> | [`CloudResource`](#cloudresource) | virtual via: `cloudResources`; display: _That Is Attached To_ |
| `vrKubeWorkloads` | `KUBE_WORKLOAD_HAS_LABEL` | `out` --> | [`KubeWorkload`](#kubeworkload) | virtual via: `KubeWorkloads`; display: _That Is Attached To_ |
| `vrKubeIdentities` | `KUBE_IDENTITY_HAS_LABEL` | `out` --> | [`KubeIdentity`](#kubeidentity) | virtual via: `kubeIdentities`; display: _That Is Attached To_ |
| `vrKubeResources` | `KUBE_RESOURCE_HAS_LABEL` | `out` --> | [`KubeResource`](#kuberesource) | virtual via: `kubeResources`; display: _That Is Attached To_ |

Paths:

```
Label --[ vrtCloudResources : RESOURCE_HAS_LABEL ]--> CloudResource   (virtual via: cloudResources)
Label --[ vrKubeWorkloads : KUBE_WORKLOAD_HAS_LABEL ]--> KubeWorkload   (virtual via: KubeWorkloads)
Label --[ vrKubeIdentities : KUBE_IDENTITY_HAS_LABEL ]--> KubeIdentity   (virtual via: kubeIdentities)
Label --[ vrKubeResources : KUBE_RESOURCE_HAS_LABEL ]--> KubeResource   (virtual via: kubeResources)
```

### SageEnvironment

- **Kind:** Entity
- **Provider:** Sage
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An AI environment label generated by Sage.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtKubeNamespaces` | `CONTAINS` | `out` --> | [`KubeNamespace`](#kubenamespace) | virtual via: `kubeNamespaces`; display: _That Contains_ |
| `vrtKubeClusters` | `CONTAINS` | `out` --> | [`KubeCluster`](#kubecluster) | virtual via: `kubeClusters`; display: _That Contains_ |

Paths:

```
SageEnvironment --[ vrtKubeNamespaces : CONTAINS ]--> KubeNamespace   (virtual via: kubeNamespaces)
SageEnvironment --[ vrtKubeClusters : CONTAINS ]--> KubeCluster   (virtual via: kubeClusters)
```

### SageLabel

- **Kind:** Entity
- **Provider:** Sage
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An AI label generated by Sage.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtKubeNamespaces` | `CONTAINS` | `out` --> | [`KubeNamespace`](#kubenamespace) | virtual via: `kubeNamespaces`; display: _That Contains_ |
| `vrtKubeClusters` | `CONTAINS` | `out` --> | [`KubeCluster`](#kubecluster) | virtual via: `kubeClusters`; display: _That Contains_ |

Paths:

```
SageLabel --[ vrtKubeNamespaces : CONTAINS ]--> KubeNamespace   (virtual via: kubeNamespaces)
SageLabel --[ vrtKubeClusters : CONTAINS ]--> KubeCluster   (virtual via: kubeClusters)
```

## Category: None

### Component

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An entity representing the edge components like Cluster Shield, Host Shield.

_No public relationships._

### FeatureHealthAlert

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An entity representing an alert related to a feature of an edge component.

_No public relationships._

### HostInternal

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An entity used for host reconciliation.

_No public relationships._

### SubComponent

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An entity representing a feature of an edge component.

_No public relationships._

## Category: Risk

### AcceptedRiskDef

- **Kind:** Entity
- **Display name:** Accepted Risk Definition
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An AcceptedRiskDef represents a risk accepted by a customer.

_No public relationships._

## Category: Security & Compliance

### Requirement

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Requirement represents a requirement in Sysdig Secure.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtControls` | `WITH` | `out` --> | [`Control`](#control) | virtual via: `controls`; display: _With_ |

Paths:

```
Requirement --[ vrtControls : WITH ]--> Control   (virtual via: controls)
```

## Category: Software

### Application

- **Kind:** Entity
- **Description:** An Application represents a software application installed in some resource.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtHosts` | `INSTALLED_IN` | `out` --> | [`Host`](#host) | virtual via: `runtimeMetadata -> hosts`; display: _That Is Installed In_ |
| `vrtImages` | `PRESENT_IN` | `out` --> | [`Image`](#image) | virtual via: `containerImages -> images`; display: _That Is Present In_ |

Paths:

```
Application --[ vrtHosts : INSTALLED_IN ]--> Host   (virtual via: runtimeMetadata -> hosts)
Application --[ vrtImages : PRESENT_IN ]--> Image   (virtual via: containerImages -> images)
```

### ContainerNew

- **Kind:** Query
- **Base entity:** [`Container`](#container)
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** Represents a container image.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtKubeWorkloads` | `RUNS_IN` | `out` --> | [`KubeWorkload`](#kubeworkload) | virtual; display: _That Runs In_ |
| `vrtPackagesInUseNew` | `USES` | `out` --> | [`PackageNew`](#packagenew) | virtual; display: _That Uses_ |

Paths:

```
ContainerNew --[ vrtKubeWorkloads : RUNS_IN ]--> KubeWorkload
ContainerNew --[ vrtPackagesInUseNew : USES ]--> PackageNew
```

### Image

- **Kind:** Entity
- **Description:** An ImageManifest represents the manifest of a container image.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtContainers` | `RUN_BY` | `out` --> | [`Container`](#container) | virtual via: `containers`; display: _That Is Run By_ |
| `vrtVulnerabilities` | `AFFECTED_BY` | `out` --> | [`Vulnerability`](#vulnerability) | virtual via: `containerImages -> vulnerabilities`; display: _Is Affected By_ |
| `packages` | `HAS_INSTALLED` | `out` --> | [`Package`](#package) | virtual via: `containerImages -> packages`; display: _That Has Installed_ |
| `applications` | `HAS_INSTALLED` | `out` --> | [`Application`](#application) | virtual via: `containerImages -> applications`; display: _That Has Installed_ |
| `sbomComponents` | `HAS_INSTALLED` | `out` --> | [`SBOMComponent`](#sbomcomponent) | virtual via: `containerImages -> sbomComponents`; display: _That Has Installed_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |
| `vrtThreats` | `GENERATES` | `out` --> | [`Threat`](#threat) | virtual via: `threats`; display: _That Generates_ |

Paths:

```
Image --[ vrtContainers : RUN_BY ]--> Container   (virtual via: containers)
Image --[ vrtVulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: containerImages -> vulnerabilities)
Image --[ packages : HAS_INSTALLED ]--> Package   (virtual via: containerImages -> packages)
Image --[ applications : HAS_INSTALLED ]--> Application   (virtual via: containerImages -> applications)
Image --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: containerImages -> sbomComponents)
Image --[ zones : IN ]--> Zone
Image --[ vrtThreats : GENERATES ]--> Threat   (virtual via: threats)
```

### ImageNew

- **Kind:** Query
- **Base entity:** [`Image`](#image)
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An Image represents a containerized software package ready for deployment.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtContainersNew` | `RUN_BY` | `out` --> | [`ContainerNew`](#containernew) | virtual; display: _That Is Run By_ |
| `packagesNew` | `HAS_INSTALLED` | `out` --> | [`PackageNew`](#packagenew) | display: _Has Installed_ |
| `zones` | `IN` | `out` --> | [`Zone`](#zone) | display: _With_ |

Paths:

```
ImageNew --[ vrtContainersNew : RUN_BY ]--> ContainerNew
ImageNew --[ packagesNew : HAS_INSTALLED ]--> PackageNew
ImageNew --[ zones : IN ]--> Zone
```

### ImageRepository

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An ImageRepository represents a repository of a container image.

_No public relationships._

### ImageTag

- **Kind:** Entity
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An ImageTag represents a tag of a container image.

_No public relationships._

### Package

- **Kind:** Entity
- **Description:** A Package represents a software package installed in some resource.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `containersInUse` | `IN_USE` | `out` --> | [`Container`](#container) | display: _That Is In Use_ |
| `hosts` | `HAS_INSTALLED` | `in` <-- | [`Host`](#host) | virtual via: `runtimeMetadata -> hosts`; display: _Has Installed_ |
| `vrtImages` | `PRESENT_IN` | `out` --> | [`Image`](#image) | virtual via: `containerImages -> images`; display: _That Is Present In_ |
| `vrtVulnerabilities` | `AFFECTED_BY` | `out` --> | [`Vulnerability`](#vulnerability) | virtual via: `vulnerabilities`; display: _That Is Affected By_ |

Paths:

```
Package --[ containersInUse : IN_USE ]--> Container
Package --[ hosts : HAS_INSTALLED ]<-- Host   (virtual via: runtimeMetadata -> hosts)
Package --[ vrtImages : PRESENT_IN ]--> Image   (virtual via: containerImages -> images)
Package --[ vrtVulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: vulnerabilities)
```

### PackageNew

- **Kind:** Query
- **Base entity:** [`Package`](#package)
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A Package represents a software package installed in some resource.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `containersInUse` | `IN_USE` | `out` --> | [`ContainerNew`](#containernew) | display: _That Is In Use In_ |
| `vrtCloudResources` | `INSTALLED_IN` | `out` --> | [`CloudResource`](#cloudresource) | virtual; display: _That Is Installed In_ |
| `vrtHosts` | `INSTALLED_IN` | `out` --> | [`Host`](#host) | virtual; display: _That Is Installed In_ |
| `vrtImagesNew` | `PRESENT_IN` | `out` --> | [`ImageNew`](#imagenew) | virtual; display: _That Is Present In_ |
| `vrtVulnerabilities` | `AFFECTED_BY` | `out` --> | [`VulnerabilityNew`](#vulnerabilitynew) | virtual; display: _That Is Affected By_ |

Paths:

```
PackageNew --[ containersInUse : IN_USE ]--> ContainerNew
PackageNew --[ vrtCloudResources : INSTALLED_IN ]--> CloudResource
PackageNew --[ vrtHosts : INSTALLED_IN ]--> Host
PackageNew --[ vrtImagesNew : PRESENT_IN ]--> ImageNew
PackageNew --[ vrtVulnerabilities : AFFECTED_BY ]--> VulnerabilityNew
```

### SBOMComponent

- **Kind:** Entity
- **Description:** An SBOMComponent represents a component installed in some resource.

| Field | Edge | Direction | Destination | Notes |
|-------|------|-----------|-------------|-------|
| `vrtHosts` | `INSTALLED_IN` | `out` --> | [`Host`](#host) | virtual via: `runtimeMetadata -> hosts`; display: _That Is Installed In_ |
| `vrtImages` | `PRESENT_IN` | `out` --> | [`Image`](#image) | virtual via: `containerImages -> images`; display: _That Is Present In_ |

Paths:

```
SBOMComponent --[ vrtHosts : INSTALLED_IN ]--> Host   (virtual via: runtimeMetadata -> hosts)
SBOMComponent --[ vrtImages : PRESENT_IN ]--> Image   (virtual via: containerImages -> images)
```

### ScanEventVM

- **Kind:** Entity
- **Display name:** Scan Event
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** An event that convey information regarding the vulnerability analysis status of resource.

_No public relationships._

### ScanResult

- **Kind:** Entity
- **Display name:** VM Scan Result
- **Hidden:** true (listed for reference; only its non-hidden relationships are shown)
- **Description:** A ScanResult represents the result of a vulnerability scan.

_No public relationships._

### ScanStatus

- **Kind:** Entity
- **Display name:** Scan Status
- **Description:** An event that convey information regarding the vulnerability analysis status of resource.

_No public relationships._

## Category: Storage

### AWSRDSDatabaseCluster

- **Kind:** Query
- **Display name:** RDS Database Cluster
- **Provider:** AWS
- **Base entity:** [`CloudResource`](#cloudresource)
- **Description:** An RDS Database Cluster represents a managed relational database cluster in AWS.

_No public relationships._

### AWSRDSDatabaseInstance

- **Kind:** Query
- **Display name:** RDS Database Instance
- **Provider:** AWS
- **Base entity:** [`CloudResource`](#cloudresource)
- **Description:** An RDS Database Instance represents a single managed relational database instance in AWS.

_No public relationships._

### AzureStorageAccountBlobService

- **Kind:** Query
- **Display name:** Azure Storage Account Blob Service
- **Provider:** Azure
- **Base entity:** [`CloudResource`](#cloudresource)
- **Description:** An Azure Storage Account Blob Service represents an object storage service in Azure.

_No public relationships._

### AzureStorageAccountBlobServiceContainer

- **Kind:** Query
- **Display name:** Azure Storage Account Blob Service Container
- **Provider:** Azure
- **Base entity:** [`CloudResource`](#cloudresource)
- **Description:** An Azure Storage Account Blob Service Container holds blobs within an Azure Storage Account.

_No public relationships._

### GCPCloudStorageBucket

- **Kind:** Query
- **Display name:** GCP Cloud Storage Bucket
- **Provider:** GCP
- **Base entity:** [`CloudResource`](#cloudresource)
- **Description:** A GCP Cloud Storage Bucket represents an object storage container in Google Cloud.

_No public relationships._

### S3Bucket

- **Kind:** Query
- **Display name:** S3 Bucket
- **Provider:** AWS
- **Base entity:** [`CloudResource`](#cloudresource)
- **Description:** An S3 Bucket represents an object storage container in AWS Simple Storage Service (S3).

_No public relationships._

---

## Appendix — Flat triple list

Every public path in the schema as `source --[field : EDGE]--> destination`.
Useful as a quick lookup when planning a multi-hop query.

```
AWSRegion --[ awsAccounts : IN ]--> AWSAccount
AWSRegion --[ vrIamRoles : CONTAINS ]--> IAMRole   (virtual via: iamRoles)
AWSRegion --[ vrtAwsAccounts : CONTAINS ]--> AWSAccount   (virtual via: awsAccounts)
AWSRegion --[ vrtCloudResources : CONTAINS ]--> CloudResource   (virtual via: cloudResources)
AWSRegion --[ vrtIamGroups : CONTAINS ]--> IAMGroup   (virtual via: iamGroups)
AWSRegion --[ vrtIamPolicies : CONTAINS ]--> IAMPolicy   (virtual via: iamPolicies)
AWSRegion --[ vrtIamUsers : CONTAINS ]--> IAMUser   (virtual via: iamUsers)
AWSRegion --[ vrtRegions : CONTAINS ]--> Region   (virtual via: regions)
AWSResource --[ acceptedControls : ACCEPTS ]--> Control
AWSResource --[ aiPackages : VIOLATES ]--> AIPackage
AWSResource --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
AWSResource --[ exposedCloudResources : EXPOSES ]--> CloudResource
AWSResource --[ failedControls : VIOLATES ]--> Control
AWSResource --[ iamInstanceProfiles : ASSOCIATED_WITH ]--> IAMInstanceProfile
AWSResource --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
AWSResource --[ regions : IN ]--> Region
AWSResource --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
AWSResource --[ sensitiveData : CONTAINS ]--> SensitiveData
AWSResource --[ vrtHasKubeNode : DEPLOYS ]--> KubeNode   (virtual via: hasKubeNode)
AWSResource --[ vrtMalwareFindings : CONTAINS ]--> Malware   (virtual via: malwareFindings)
AWSResource --[ vrtPackages : PACKAGE_INSTALLED_ON ]--> Package   (virtual via: runtimeMetadata -> packages)
AWSResource --[ vrtRunsContainer : RUNS ]--> Container   (virtual via: containers)
AWSResource --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
AWSResource --[ vrtThreats : GENERATES ]--> Threat   (virtual via: threats)
AWSResource --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
AWSResource --[ zones : IN ]--> Zone
Application --[ vrtHosts : INSTALLED_IN ]--> Host   (virtual via: runtimeMetadata -> hosts)
Application --[ vrtImages : PRESENT_IN ]--> Image   (virtual via: containerImages -> images)
AzureManagementGroup --[ azureManagementGroups : IN ]--> AzureManagementGroup
AzureManagementGroup --[ azureOrganizations : IN ]--> AzureOrganization
AzureOrganization --[ vrtAzureSubscriptions : CONTAINS ]--> AzureSubscription   (virtual via: azureSubscriptions)
AzureRegion --[ azureSubscriptions : IN ]--> AzureSubscription
AzureRegion --[ vrtCloudResources : CONTAINS ]--> CloudResource   (virtual via: cloudResources)
AzureResource --[ acceptedControls : ACCEPTS ]--> Control
AzureResource --[ aiPackages : VIOLATES ]--> AIPackage
AzureResource --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
AzureResource --[ azureRegions : IN ]--> Region
AzureResource --[ failedControls : VIOLATES ]--> Control
AzureResource --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
AzureResource --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
AzureResource --[ sensitiveData : CONTAINS ]--> SensitiveData
AzureResource --[ vrtMalwareFindings : CONTAINS ]--> Malware   (virtual via: malwareFindings)
AzureResource --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
AzureResource --[ vrtThreats : GENERATES ]--> Threat   (virtual via: threats)
AzureResource --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
AzureResource --[ zones : IN ]--> Zone
AzureSubscription --[ cloudResources : OWNS ]--> CloudResource   (virtual via: azureRegions -> cloudResources)
AzureSubscription --[ vrtAzureRegions : CONTAINS ]--> Region   (virtual via: azureRegions)
AzureSubscription --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
CIEMAccessGroup --[ cloudIAMGroups : PARENT_OF ]<-- CloudIAMGroup
CIEMAccessGroup --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
CIEMAccessPolicy --[ cloudIAMPolicies : PARENT_OF ]<-- CloudIAMPolicy
CIEMAccessRole --[ cloudIAMRoles : PARENT_OF ]<-- CloudIAMRole
CIEMAccessRole --[ cloudResources : HAS_ACCESS ]--> CloudResource
CIEMAccessRole --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
CIEMAccessServiceIdentity --[ cloudIAMServiceIdentities : PARENT_OF ]<-- CloudIAMServiceIdentity
CIEMAccessServiceIdentity --[ cloudResources : HAS_ACCESS ]--> CloudResource
CIEMAccessServiceIdentity --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
CIEMAccessUser --[ cloudIAMUsers : PARENT_OF ]<-- CloudIAMUser
CIEMAccessUser --[ cloudResources : HAS_ACCESS ]--> CloudResource
CIEMAccessUser --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
CIEMUnionUser --[ zones : IN ]--> Zone
CloudGroup --[ regions : IN ]--> Region
CloudGroup --[ zones : IN ]--> Zone
CloudIAMGroup --[ cloudResources : PARENT_OF ]--> CloudResource
CloudIAMGroup --[ groupsMember : MEMBER_OF ]--> CloudIAMGroup
CloudIAMGroup --[ groupsParent : MEMBER_OF ]<-- CloudIAMGroup
CloudIAMGroup --[ regions : IN ]--> Region
CloudIAMGroup --[ roles : HAS_ROLE ]--> CloudIAMRole
CloudIAMGroup --[ serviceIdentities : MEMBER_OF ]<-- CloudIAMServiceIdentity
CloudIAMGroup --[ users : MEMBER_OF ]<-- CloudIAMUser
CloudIAMGroup --[ zones : IN ]--> Zone
CloudIAMPolicy --[ regions : IN ]--> Region
CloudIAMPolicy --[ zones : IN ]--> Zone
CloudIAMRole --[ cloudResources : HAS_ACCESS ]--> CloudResource
CloudIAMRole --[ groups : HAS_ROLE ]<-- CloudIAMGroup
CloudIAMRole --[ regions : IN ]--> Region
CloudIAMRole --[ s3Buckets : HAS_ACCESS ]--> S3Bucket
CloudIAMRole --[ serviceIdentities : HAS_ROLE ]<-- CloudIAMServiceIdentity
CloudIAMRole --[ users : HAS_ROLE ]<-- CloudIAMUser
CloudIAMRole --[ zones : IN ]--> Zone
CloudIAMServiceIdentity --[ cloudResources : PARENT_OF ]--> CloudResource
CloudIAMServiceIdentity --[ groups : MEMBER_OF ]--> CloudIAMGroup
CloudIAMServiceIdentity --[ keys : HAS_KEY ]--> CloudIAMServiceIdentityKey
CloudIAMServiceIdentity --[ regions : IN ]--> Region
CloudIAMServiceIdentity --[ roles : HAS_ROLE ]--> CloudIAMRole
CloudIAMServiceIdentity --[ zones : IN ]--> Zone
CloudIAMServiceIdentityKey --[ serviceIdentities : HAS_KEY ]<-- CloudIAMServiceIdentity
CloudIAMServiceIdentityKey --[ vrtServiceIdentities : KEY_OF ]--> CloudIAMServiceIdentity   (virtual via: serviceIdentities)
CloudIAMUser --[ acceptedControls : ACCEPTS ]--> Control
CloudIAMUser --[ cloudResources : HAS_ACCESS ]--> CloudResource
CloudIAMUser --[ failedControls : VIOLATES ]--> Control
CloudIAMUser --[ regions : IN ]--> Region
CloudIAMUser --[ roles : HAS_ROLE ]--> CloudIAMRole
CloudIAMUser --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
CloudIAMUser --[ zones : IN ]--> Zone
CloudPolicy --[ failedControls : VIOLATES ]--> Control
CloudPolicy --[ regions : IN ]--> Region
CloudPolicy --[ zones : IN ]--> Zone
CloudRole --[ cloudResources : HAS_ACCESS ]--> CloudResource
CloudRole --[ regions : IN ]--> Region
CloudRole --[ zones : IN ]--> Zone
CloudServiceIdentity --[ regions : IN ]--> Region
CloudServiceIdentity --[ zones : IN ]--> Zone
CloudUser --[ acceptedControls : ACCEPTS ]--> Control
CloudUser --[ failedControls : VIOLATES ]--> Control
CloudUser --[ regions : IN ]--> Region
CloudUser --[ runtimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: ciemAccessUsers -> runtimeEvents)
CloudUser --[ zones : IN ]--> Zone
ContainerNew --[ vrtKubeWorkloads : RUNS_IN ]--> KubeWorkload
ContainerNew --[ vrtPackagesInUseNew : USES ]--> PackageNew
Control --[ acceptedKubeNodes : KUBE_NODE_ACCEPTS ]<-- KubeNode   (virtual via: kubeNodes)
Control --[ acceptingKubeResources : ACCEPTS ]<-- KubeResource
Control --[ failingKubeResources : VIOLATES ]<-- KubeResource
Control --[ passedKubeNodes : KUBE_NODE_PASSES ]<-- KubeNode   (virtual via: kubeNodes)
Control --[ passingCloudResources : PASSES ]<-- CloudResource
Control --[ passingKubeResources : KUBE_RESOURCE_PASSES ]<-- KubeResource
Control --[ violatedKubeNodes : KUBE_NODE_VIOLATES ]<-- KubeNode   (virtual via: kubeNodes)
Control --[ vrtAcceptedIAMPolicies : IAM_POLICY_ACCEPTS ]--> IAMPolicy   (virtual via: acceptedIAMPolicies)
Control --[ vrtAcceptedKubeIdentities : KUBE_IDENTITY_ACCEPTS ]--> KubeIdentity   (virtual via: acceptedKubeIdentities)
Control --[ vrtAcceptedKubeWorkloads : KUBE_WORKLOAD_ACCEPTS ]--> KubeWorkload   (virtual via: acceptedKubeWorkloads)
Control --[ vrtAcceptingKubeResources : KUBE_RESOURCE_ACCEPTS ]--> KubeResource   (virtual via: acceptingKubeResources)
Control --[ vrtCloudAcceptedResources : RESOURCE_ACCEPTS ]--> CloudResource   (virtual via: acceptedCloudResources)
Control --[ vrtCloudFailedResources : RESOURCE_VIOLATES ]--> CloudResource   (virtual via: failedCloudResources)
Control --[ vrtFailedIAMPolicies : IAM_POLICY_VIOLATES ]--> IAMPolicy   (virtual via: failedIAMPolicies)
Control --[ vrtFailedKubeIdentities : KUBE_IDENTITY_VIOLATES ]--> KubeIdentity   (virtual via: failedKubeIdentities)
Control --[ vrtFailedKubeWorkloads : KUBE_WORKLOAD_VIOLATES ]--> KubeWorkload   (virtual via: failedKubeWorkloads)
Control --[ vrtPassingCloudResources : PASSED_BY ]--> CloudResource   (virtual via: passingCloudResources)
Control --[ vrtPassingKubeResources : KUBE_RESOURCE_PASSED_BY ]--> KubeResource   (virtual via: passingKubeResources)
Control --[ vrtfailingKubeResources : KUBE_RESOURCE_VIOLATES ]--> KubeResource   (virtual via: failingKubeResources)
EC2Instance --[ acceptedControls : ACCEPTS ]--> Control
EC2Instance --[ aiPackages : VIOLATES ]--> AIPackage
EC2Instance --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
EC2Instance --[ containers : HAS ]--> Container
EC2Instance --[ exposedCloudResources : EXPOSES ]--> CloudResource
EC2Instance --[ failedControls : VIOLATES ]--> Control
EC2Instance --[ iamInstanceProfiles : ASSOCIATED_WITH ]--> IAMInstanceProfile
EC2Instance --[ iamRoles3Buckets : ? ]<-> ?
EC2Instance --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
EC2Instance --[ regions : IN ]--> Region
EC2Instance --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
EC2Instance --[ vrtHasKubeNode : DEPLOYS ]--> KubeNode   (virtual via: hasKubeNode)
EC2Instance --[ vrtLaunchTemplates : LAUNCHED_FROM ]--> EC2LaunchTemplate   (virtual via: launchTemplates)
EC2Instance --[ vrtMalwareFindings : CONTAINS ]--> Malware   (virtual via: malwareFindings)
EC2Instance --[ vrtPackages : PACKAGE_INSTALLED_ON ]--> Package   (virtual via: runtimeMetadata -> packages)
EC2Instance --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
EC2Instance --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
EC2Instance --[ zones : IN ]--> Zone
Endpoint --[ validatedBy : VALIDATED_BY ]--> PublicEndpoint
GCPFolder --[ gcpFolders : IN ]--> GCPFolder
GCPFolder --[ gcpOrganizations : IN ]--> GCPOrganization
GCPOrganization --[ gcpProjects : IN ]--> GCPProject
GCPProject --[ cloudResources : OWNS ]--> CloudResource   (virtual via: gcpRegions -> cloudResources)
GCPProject --[ gcpOrganizations : IN ]--> GCPOrganization
GCPProject --[ vrtGcpRegions : CONTAINS ]--> Region   (virtual via: gcpRegions)
GCPProject --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
GCPRegion --[ vrtCloudResources : CONTAINS ]--> CloudResource   (virtual via: cloudResources)
GitCloudResource --[ acceptedControls : ACCEPTS ]--> Control
GitCloudResource --[ failedControls : VIOLATES ]--> Control
GitCloudResource --[ zones : IN ]--> Zone
GitKubeWorkload --[ acceptedControls : ACCEPTS ]--> Control
GitKubeWorkload --[ failedControls : VIOLATES ]--> Control
GitKubeWorkload --[ zones : IN ]--> Zone
Host --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
Host --[ exposedBy : EXPOSED_BY ]--> Endpoint
Host --[ exposedCloudResources : EXPOSES ]--> CloudResource
Host --[ failedControls : VIOLATES ]--> Control
Host --[ kubeNodes : DEPLOYED_ON ]<-- KubeNode
Host --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
Host --[ publiclyExposedBy : PUBLICLY_EXPOSED_BY ]--> PublicEndpoint   (virtual via: exposedBy -> validatedBy)
Host --[ regions : IN ]--> Region
Host --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
Host --[ vrtMalwareFindings : CONTAINS ]--> Malware   (virtual via: malwareFindings)
Host --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
Host --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
Host --[ zones : IN ]--> Zone
IAMInstanceProfile --[ iamRoles : CONTAINS ]--> IAMRole
IAMInstanceProfile --[ regions : IN ]--> Region
IBMAccountGroup --[ ibmAccountGroups : IN ]--> IBMAccountGroup
IBMResource --[ acceptsControl : ACCEPTS ]--> Control
IBMResource --[ inZone : IN ]--> Zone
IBMResource --[ passesControl : PASSES ]--> Control
IBMResource --[ violatesControl : VIOLATES ]--> Control
Image --[ applications : HAS_INSTALLED ]--> Application   (virtual via: containerImages -> applications)
Image --[ packages : HAS_INSTALLED ]--> Package   (virtual via: containerImages -> packages)
Image --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: containerImages -> sbomComponents)
Image --[ vrtContainers : RUN_BY ]--> Container   (virtual via: containers)
Image --[ vrtThreats : GENERATES ]--> Threat   (virtual via: threats)
Image --[ vrtVulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: containerImages -> vulnerabilities)
Image --[ zones : IN ]--> Zone
ImageNew --[ packagesNew : HAS_INSTALLED ]--> PackageNew
ImageNew --[ vrtContainersNew : RUN_BY ]--> ContainerNew
ImageNew --[ zones : IN ]--> Zone
Instance --[ acceptedControls : ACCEPTS ]--> Control
Instance --[ failedControls : VIOLATES ]--> Control
Instance --[ passedControls : PASSES ]--> Control
Instance --[ regions : IN ]--> Region
Instance --[ zones : IN ]--> Zone
KubeCluster --[ acceptedControls : ACCEPTS ]--> Control
KubeCluster --[ failedControls : VIOLATES ]--> Control
KubeCluster --[ regions : IN ]--> Region   (virtual via: kubeNodes -> deployedOnCloudResource -> regions)
KubeCluster --[ vrtKubeNamespaces : CONTAINS ]--> KubeNamespace   (virtual via: kubeNamespaces)
KubeCluster --[ vrtKubeNodes : CONTAINS ]--> KubeNode   (virtual via: kubeNodes)
KubeCluster --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: kubeNamespaces -> kubeWorkloads -> runtimeEvents)
KubeCluster --[ zones : IN ]--> Zone
KubeIdentity --[ acceptedControls : ACCEPTS ]--> Control
KubeIdentity --[ failedControls : VIOLATES ]--> Control
KubeIdentity --[ namespaces : IN ]--> KubeNamespace
KubeIdentity --[ zones : IN ]--> Zone
KubeIngress --[ aiPackages : VIOLATES ]--> AIPackage
KubeIngress --[ kubeNamespaces : IN ]--> KubeNamespace
KubeIngress --[ kubeServices : EXPOSES ]--> KubeService
KubeNode --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
KubeNode --[ deployedOnCloudResource : DEPLOYED_ON ]--> CloudResource
KubeNode --[ kubeClusters : IN ]--> KubeCluster
KubeNode --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
KubeNode --[ regions : IN ]--> Region   (virtual via: deployedOnCloudResource -> regions)
KubeNode --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
KubeNode --[ vrtThreats : GENERATES ]--> Threat   (virtual via: threats)
KubeNode --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
KubeNode --[ zones : IN ]--> Zone
KubeResource --[ acceptedControls : ACCEPTS ]--> Control
KubeResource --[ applications : HAS_INSTALLED ]--> Application   (virtual via: containers -> images -> containerImages -> applications)
KubeResource --[ containers : HAS ]--> Container
KubeResource --[ failedControls : VIOLATES ]--> Control
KubeResource --[ kubeNamespaces : IN ]--> KubeNamespace
KubeResource --[ packages : HAS_INSTALLED ]--> Package   (virtual via: containers -> images -> containerImages -> packages)
KubeResource --[ passedControls : PASSES ]--> Control
KubeResource --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: containers -> images -> containerImages -> sbomComponents)
KubeResource --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
KubeResource --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: containers -> images -> containerImages -> vulnerabilities)
KubeResource --[ zones : IN ]--> Zone
KubeService --[ kubeResources : EXPOSES ]--> KubeResource
KubeService --[ kubeWorkloads : EXPOSES ]--> KubeWorkload
KubeService --[ vrtKubeIngress : EXPOSED_BY ]--> KubeIngress   (virtual via: kubeIngress)
KubeWorkload --[ acceptedControls : ACCEPTS ]--> Control
KubeWorkload --[ aiPackages : VIOLATES ]--> AIPackage
KubeWorkload --[ containers : HAS ]--> Container
KubeWorkload --[ containersNew : HAS ]--> ContainerNew
KubeWorkload --[ failedControls : VIOLATES ]--> Control
KubeWorkload --[ kubeClusters : IN ]--> KubeCluster   (virtual via: namespaces -> kubeClusters)
KubeWorkload --[ namespaces : IN ]--> KubeNamespace
KubeWorkload --[ passedControls : PASSES ]--> Control
KubeWorkload --[ regions : IN ]--> Region   (virtual via: namespaces -> kubeClusters -> kubeNodes -> deployedOnCloudResource -> regions)
KubeWorkload --[ vrKubeServices : EXPOSED_BY ]--> KubeService   (virtual via: kubeServices)
KubeWorkload --[ vrtContainers : RUNS ]--> Container
KubeWorkload --[ vrtContainersNew : RUNS ]--> ContainerNew
KubeWorkload --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
KubeWorkload --[ vrtThreats : GENERATES ]--> Threat   (virtual via: threats)
KubeWorkload --[ vrtVulnerabilitiesNew : AFFECTED_BY ]--> VulnerabilityNew
KubeWorkload --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: containers -> images -> containerImages -> vulnerabilities)
KubeWorkload --[ zones : IN ]--> Zone
Label --[ vrKubeIdentities : KUBE_IDENTITY_HAS_LABEL ]--> KubeIdentity   (virtual via: kubeIdentities)
Label --[ vrKubeResources : KUBE_RESOURCE_HAS_LABEL ]--> KubeResource   (virtual via: kubeResources)
Label --[ vrKubeWorkloads : KUBE_WORKLOAD_HAS_LABEL ]--> KubeWorkload   (virtual via: KubeWorkloads)
Label --[ vrtCloudResources : RESOURCE_HAS_LABEL ]--> CloudResource   (virtual via: cloudResources)
Malware --[ cloudResources : FOUND_IN ]--> CloudResource
Malware --[ host : FOUND_IN ]--> Host
OCIResource --[ inZone : IN ]--> Zone
OCIResource --[ passesControl : PASSES ]--> Control
OCIResource --[ violatesControl : VIOLATES ]--> Control
Package --[ containersInUse : IN_USE ]--> Container
Package --[ hosts : HAS_INSTALLED ]<-- Host   (virtual via: runtimeMetadata -> hosts)
Package --[ vrtImages : PRESENT_IN ]--> Image   (virtual via: containerImages -> images)
Package --[ vrtVulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: vulnerabilities)
PackageNew --[ containersInUse : IN_USE ]--> ContainerNew
PackageNew --[ vrtCloudResources : INSTALLED_IN ]--> CloudResource
PackageNew --[ vrtHosts : INSTALLED_IN ]--> Host
PackageNew --[ vrtImagesNew : PRESENT_IN ]--> ImageNew
PackageNew --[ vrtVulnerabilities : AFFECTED_BY ]--> VulnerabilityNew
Policy --[ zones : IN ]--> Zone
Requirement --[ vrtControls : WITH ]--> Control   (virtual via: controls)
Resource --[ acceptsControl : ACCEPTS ]--> Control
Resource --[ aiPackages : VIOLATES ]--> AIPackage
Resource --[ containers : RUNS_CONTAINER ]--> Container
Resource --[ passesControl : PASSES ]--> Control
Resource --[ regions : IN ]--> Region
Resource --[ testedByControl : TESTED_BY ]--> Control
Resource --[ violatesControl : VIOLATES ]--> Control
Resource --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
Resource --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
Resource --[ zones : IN ]--> Zone
RuntimeEvent --[ awsAccounts : GENERATED_BY ]--> AWSAccount
RuntimeEvent --[ azureSubscriptions : GENERATED_BY ]--> AzureSubscription
RuntimeEvent --[ cloudResources : GENERATED_BY ]--> CloudResource
RuntimeEvent --[ gcpProjects : GENERATED_BY ]--> GCPProject
RuntimeEvent --[ iamUsers : GENERATED_BY ]--> IAMUser
RuntimeEvent --[ kubeResources : GENERATED_BY ]--> KubeResource
RuntimeEvent --[ workloads : GENERATED_BY ]--> KubeWorkload
RuntimeResource --[ applications : HAS_INSTALLED ]--> Application   (virtual via: runtimeMetadata -> applications)
RuntimeResource --[ containers : RUNS ]--> Container
RuntimeResource --[ packages : HAS_INSTALLED ]--> Package   (virtual via: runtimeMetadata -> packages)
RuntimeResource --[ sbomComponents : HAS_INSTALLED ]--> SBOMComponent   (virtual via: runtimeMetadata -> sbomComponents)
RuntimeResource --[ vrtMalwareFindings : CONTAINS ]--> Malware   (virtual via: malwareFindings)
RuntimeResource --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
RuntimeResource --[ vulnerabilities : AFFECTED_BY ]--> Vulnerability   (virtual via: runtimeMetadata -> vulnerabilities)
RuntimeResource --[ zones : IN ]--> Zone
SBOMComponent --[ vrtHosts : INSTALLED_IN ]--> Host   (virtual via: runtimeMetadata -> hosts)
SBOMComponent --[ vrtImages : PRESENT_IN ]--> Image   (virtual via: containerImages -> images)
SageEnvironment --[ vrtKubeClusters : CONTAINS ]--> KubeCluster   (virtual via: kubeClusters)
SageEnvironment --[ vrtKubeNamespaces : CONTAINS ]--> KubeNamespace   (virtual via: kubeNamespaces)
SageLabel --[ vrtKubeClusters : CONTAINS ]--> KubeCluster   (virtual via: kubeClusters)
SageLabel --[ vrtKubeNamespaces : CONTAINS ]--> KubeNamespace   (virtual via: kubeNamespaces)
ScopedIAMGroup --[ cloudIAMGroups : SCOPED_AS ]<-- CloudIAMGroup
ScopedIAMGroup --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
ScopedIAMPolicy --[ cloudIAMPolicies : SCOPED_AS ]<-- CloudIAMPolicy
ScopedIAMRole --[ cloudIAMRoles : SCOPED_AS ]<-- CloudIAMRole
ScopedIAMRole --[ cloudResources : HAS_ACCESS ]--> CloudResource
ScopedIAMRole --[ s3Buckets : HAS_ACCESS ]--> S3Bucket
ScopedIAMRole --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
ScopedIAMServiceIdentity --[ cloudIAMServiceIdentities : SCOPED_AS ]<-- CloudIAMServiceIdentity
ScopedIAMServiceIdentity --[ cloudResources : HAS_ACCESS ]--> CloudResource
ScopedIAMServiceIdentity --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
ScopedIAMUser --[ cloudIAMUsers : SCOPED_AS ]<-- CloudIAMUser
ScopedIAMUser --[ cloudResources : HAS_ACCESS ]--> CloudResource
ScopedIAMUser --[ vrtCloudIAMUsers : REPRESENTS ]--> CloudIAMUser   (virtual via: cloudIAMUsers)
ScopedIAMUser --[ vrtRuntimeEvents : GENERATES ]--> RuntimeEvent   (virtual via: runtimeEvents)
SensitiveData --[ childrenSensitiveData : PARENT_OF ]--> SensitiveData
SensitiveData --[ parentSensitiveData : PARENT_OF ]<-- SensitiveData
SensitiveData --[ virtParentSensitiveData : CHILD_OF ]<-- SensitiveData   (virtual via: parentSensitiveData)
SensitiveDataFinding --[ findingDetails : PARENT_OF ]--> SensitiveDataFindingDetail
SensitiveDataFindingDetail --[ finding : PARENT_OF ]<-- SensitiveDataFinding
SensitiveDataFindingDetail --[ virtFindings : CHILD_OF ]<-- SensitiveDataFinding   (virtual via: finding)
Threat --[ awsResources : GENERATED_BY ]--> AWSResource
Threat --[ azureResources : GENERATED_BY ]--> AzureResource
Threat --[ gcpResources : GENERATED_BY ]--> GCPResource
Threat --[ imageManifest : GENERATED_BY ]--> Image
Threat --[ kubeNodes : GENERATED_BY ]--> KubeNode
Threat --[ kubeWorkload : GENERATED_BY ]--> KubeWorkload
VulnerabilityNew --[ packagesNew : REFERS_TO_PACKAGE ]--> PackageNew
VulnerabilityNew --[ vrtHosts : AFFECTS ]--> Host
VulnerabilityNew --[ vrtImagesNew : AFFECTS ]--> ImageNew
VulnerabilityNew --[ vrtKubeWorkloads : AFFECTS ]--> KubeWorkload
Zone --[ containsHost : CONTAINS ]--> Host   (virtual via: host)
Zone --[ host : IN ]<-- Host
Zone --[ vrtCloudResources : CONTAINS ]--> CloudResource   (virtual via: cloudResources)
Zone --[ vrtContainers : CONTAINS ]--> Container   (virtual via: images -> containers)
Zone --[ vrtIamGroups : CONTAINS ]--> IAMGroup   (virtual via: iamGroups)
Zone --[ vrtIamPolicies : CONTAINS ]--> IAMPolicy   (virtual via: iamPolicies)
Zone --[ vrtIamRoles : CONTAINS ]--> IAMRole   (virtual via: iamRoles)
Zone --[ vrtIamUsers : CONTAINS ]--> IAMUser   (virtual via: iamUsers)
Zone --[ vrtImages : CONTAINS ]--> Image   (virtual via: images)
Zone --[ vrtKubeIdentities : CONTAINS ]--> KubeIdentity   (virtual via: kubeIdentities)
Zone --[ vrtKubeNodes : CONTAINS ]--> KubeNode   (virtual via: kubeNodes)
Zone --[ vrtKubeResources : CONTAINS ]--> KubeResource   (virtual via: kubeResources)
Zone --[ vrtKubeWorkloads : CONTAINS ]--> KubeWorkload   (virtual via: kubeWorkloads)
```
