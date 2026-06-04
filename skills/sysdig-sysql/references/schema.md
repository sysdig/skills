# SysQL Schema Reference

Compact reference of the SysQL data model, optimised for LLM consumption.

**What's in here**
- One section per **Entity**, **Query** (alias over a base entity) or
  **Union** (polymorphic node that resolves to several entities).
- Each section lists the queryable **fields** (`name`, `type`,
  optional description) and the **names** of the available relationships.

**What's omitted**
- Hidden fields and hidden relationships, and any hidden entity that is
  not referenced by a public node. Hidden entities used as the backing
  of a public **Query** alias or **Union** member are not shown as
  standalone sections — their fields and relationships are **inlined**
  into the public node, tagged with `via <SourceEntity>`.
- Edge labels, direction, virtual-path details for relationships. For
  that, consult [`relationships.md`](relationships.md).

**Type vocabulary**
`String`, `BigInt`, `Integer`, `Float`, `Boolean`, `DateTime`,
`Enum<primitive>` (with allowed values), `List<elementType>`.

---

## Index

### Compute

- [`AWSLambda`](#awslambda) — *Query*
- [`AzureFunction`](#azurefunction-azureresource) — *Query (via `AzureResource`)*
- [`AzureFunction`](#azurefunction-cloudresource) — *Query (via `CloudResource`)*
- [`AzureVirtualMachine`](#azurevirtualmachine) — *Query*
- [`CloudFunction`](#cloudfunction) — *Query*
- [`CloudRunJob`](#cloudrunjob) — *Query*
- [`CloudRunService`](#cloudrunservice) — *Query*
- [`ContainerApp`](#containerapp) — *Query*
- [`ContainerAppJob`](#containerappjob) — *Query*
- [`ContainerInstance`](#containerinstance) — *Query*
- [`EC2Instance`](#ec2instance) — *Query*
- [`EC2LaunchTemplate`](#ec2launchtemplate) — *Query*
- [`ECSClusterTask`](#ecsclustertask) — *Query*
- [`ECSFargateService`](#ecsfargateservice) — *Query*
- [`ECSService`](#ecsservice) — *Query*
- [`GCPCloudFunction`](#gcpcloudfunction) — *Query*
- [`GCPComputeInstance`](#gcpcomputeinstance) — *Query*
- [`Host`](#host)

### Detections

- [`RuntimeEvent`](#runtimeevent)
- [`Threat`](#threat)

### Environment

- [`AzureOrganization`](#azureorganization)
- [`AzureSubscription`](#azuresubscription)
- [`CloudAccount`](#cloudaccount) — *Union*
- [`CloudResource`](#cloudresource) — *Union*
- [`Endpoint`](#endpoint) — *Query*
- [`GCPOrganization`](#gcporganization)
- [`GCPProject`](#gcpproject)
- [`IBMAccount`](#ibmaccount)
- [`IBMResource`](#ibmresource)
- [`OCICompartment`](#ocicompartment)
- [`OCIResource`](#ociresource)
- [`Region`](#region) — *Union*
- [`Zone`](#zone)

### Findings

- [`AIPackage`](#aipackage) — *Query*
- [`Control`](#control)
- [`Malware`](#malware)
- [`PrivilegedControl`](#privilegedcontrol) — *Query*
- [`S3AcceptsHTTP`](#s3acceptshttp) — *Query*
- [`S3VersioningDisabled`](#s3versioningdisabled) — *Query*
- [`SensitiveData`](#sensitivedata)

### Identity

- [`CloudGroup`](#cloudgroup)
- [`CloudPolicy`](#cloudpolicy)
- [`CloudRole`](#cloudrole)
- [`CloudServiceIdentity`](#cloudserviceidentity)
- [`CloudUser`](#clouduser)
- [`IAMInstanceProfile`](#iaminstanceprofile)

### Kubernetes

- [`GitKubeWorkload`](#gitkubeworkload)
- [`KubeCluster`](#kubecluster)
- [`KubeIdentity`](#kubeidentity)
- [`KubeIngress`](#kubeingress)
- [`KubeNode`](#kubenode)
- [`KubeResource`](#kuberesource)
- [`KubeService`](#kubeservice)
- [`KubeWorkload`](#kubeworkload)

### Software

- [`Application`](#application)
- [`Image`](#image)
- [`Package`](#package)
- [`SBOMComponent`](#sbomcomponent)
- [`ScanStatus`](#scanstatus)

### Storage

- [`AWSRDSDatabaseCluster`](#awsrdsdatabasecluster) — *Query*
- [`AWSRDSDatabaseInstance`](#awsrdsdatabaseinstance) — *Query*
- [`AzureStorageAccountBlobService`](#azurestorageaccountblobservice) — *Query*
- [`AzureStorageAccountBlobServiceContainer`](#azurestorageaccountblobservicecontainer) — *Query*
- [`GCPCloudStorageBucket`](#gcpcloudstoragebucket) — *Query*
- [`S3Bucket`](#s3bucket) — *Query*

---

## Compute

### AWSLambda

- **Kind:** Query
- **Display name:** AWS Lambda
- **Provider:** AWS
- **Alias of:** `AWSResource`
- **Sub-query:** `MATCH AWSResource AS r WHERE r.type = "Lambda Function";`

An AWS Lambda represents a serverless compute function that runs in response to events provided by AWS.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `AWSResource`)* | `String` | The account ID of the resource. |
| `account` *(via `AWSResource`)* | `String` | The account of the resource. |
| `category` *(via `AWSResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `AWSResource`)* | `DateTime` |  |
| `name` *(via `AWSResource`)* | `String` | The name of the resource. |
| `organization` *(via `AWSResource`)* | `String` | The organization of the resource. |
| `platform` *(via `AWSResource`)* | `String` | The platform of the resource. |
| `location` *(via `AWSResource`)* | `String` | The location of the resource. |
| `type` *(via `AWSResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `AWSResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `AWSResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `AWSResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `AWSResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `AWSResource`)* | `DateTime` |  |
| `publicIPs` *(via `AWSResource`)* | `List<String>` |  |
| `privateIPs` *(via `AWSResource`)* | `List<String>` |  |
| `arn` *(via `AWSResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `AWSResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `AWSResource`)* | `String` | The task definition family of the resource. |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages` *(via `AWSResource`)*

See [`relationships.md`](relationships.md#awslambda) for edge labels, direction and destination entities.

### AzureFunction (AzureResource)

- **Kind:** Query
- **Provider:** Azure
- **Alias of:** `AzureResource`
- **Sub-query:** `MATCH AzureResource AS r WHERE r.type = "Function";`

Azure Functions is a serverless compute service provided by Azure that enables you to run event-driven code without managing infrastructure, supporting multiple programming languages and automatic scaling.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `lastModified` *(via `AzureResource`)* | `DateTime` |  |
| `location` *(via `AzureResource`)* | `String` | The location of the resource. |
| `name` *(via `AzureResource`)* | `String` | The name of the resource. |
| `organization` *(via `AzureResource`)* | `String` | The organization of the resource. |
| `platform` *(via `AzureResource`)* | `String` | The platform of the resource. |
| `type` *(via `AzureResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `AzureResource`)* | `Boolean` | Whether the resource is exposed. |
| `subscriptionId` *(via `AzureResource`)* | `String` | The subscription ID of the resource. |
| `firstSeen` *(via `AzureResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `AzureResource`)* | `DateTime` | The last date the resource was scanned. |
| `createdAt` *(via `AzureResource`)* | `DateTime` |  |
| `status` *(via `AzureResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `AzureResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `AzureResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `AzureResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `AzureResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `AzureResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `AzureResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `AzureResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `AzureResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |

**Relationships:** `packages`, `sbomComponents`, `applications`, `vulnerabilities`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `azureRegions`, `failedControls`, `zones`, `acceptedControls`, `aiPackages` *(via `AzureResource`)*

See [`relationships.md`](relationships.md#azurefunction-azureresource) for edge labels, direction and destination entities.

### AzureFunction (CloudResource)

- **Kind:** Query
- **Display name:** Azure Function
- **Provider:** Azure
- **Alias of:** [`CloudResource`](#cloudresource)
- **Sub-query:** `MATCH CloudResource AS r WHERE r.type = "Function" AND r.platform = "Azure";`

An Azure Function represents a serverless compute function that executes code in response to events.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `CloudResource`)* | `String` | The account ID of the resource. |
| `account` *(via `CloudResource`)* | `String` | The account of the resource. |
| `category` *(via `CloudResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `CloudResource`)* | `DateTime` |  |
| `name` *(via `CloudResource`)* | `String` | The name of the resource. |
| `organization` *(via `CloudResource`)* | `String` | The organization of the resource. |
| `platform` *(via `CloudResource`)* | `String` | The platform of the resource. |
| `location` *(via `CloudResource`)* | `String` | The location of the resource. |
| `type` *(via `CloudResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `CloudResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `CloudResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `CloudResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `CloudResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `CloudResource`)* | `DateTime` |  |
| `publicIPs` *(via `CloudResource`)* | `List<String>` |  |
| `privateIPs` *(via `CloudResource`)* | `List<String>` |  |
| `arn` *(via `CloudResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `CloudResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `CloudResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `CloudResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `CloudResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `CloudResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `CloudResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `CloudResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `CloudResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `CloudResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `CloudResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `CloudResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `CloudResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `CloudResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `CloudResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `CloudResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `CloudResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `CloudResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `CloudResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `CloudResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `CloudResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `CloudResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `CloudResource`)* | `String` |  |
| `nameLower` *(via `CloudResource`)* | `String` |  |
| `nativeId` *(via `CloudResource`)* | `String` |  |
| `resourceId` *(via `CloudResource`)* | `String` |  |
| `technicalType` *(via `CloudResource`)* | `String` |  |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages`, `azureRegions`, `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `CloudResource`)*

See [`relationships.md`](relationships.md#azurefunction-cloudresource) for edge labels, direction and destination entities.

### AzureVirtualMachine

- **Kind:** Query
- **Display name:** Azure Virtual Machine
- **Provider:** Azure
- **Alias of:** [`CloudResource`](#cloudresource)
- **Sub-query:** `MATCH CloudResource AS r WHERE r.type = "Virtual Machine" AND r.platform = "Azure";`

An Azure Virtual Machine represents a compute instance running in the Azure cloud.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `clusterName` | `String` | The name of the cluster the resource belongs to. |
| `accountId` *(via `CloudResource`)* | `String` | The account ID of the resource. |
| `account` *(via `CloudResource`)* | `String` | The account of the resource. |
| `category` *(via `CloudResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `CloudResource`)* | `DateTime` |  |
| `name` *(via `CloudResource`)* | `String` | The name of the resource. |
| `organization` *(via `CloudResource`)* | `String` | The organization of the resource. |
| `platform` *(via `CloudResource`)* | `String` | The platform of the resource. |
| `location` *(via `CloudResource`)* | `String` | The location of the resource. |
| `type` *(via `CloudResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `CloudResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `CloudResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `CloudResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `CloudResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `CloudResource`)* | `DateTime` |  |
| `publicIPs` *(via `CloudResource`)* | `List<String>` |  |
| `privateIPs` *(via `CloudResource`)* | `List<String>` |  |
| `arn` *(via `CloudResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `CloudResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `CloudResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `CloudResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `CloudResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `CloudResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `CloudResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `CloudResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `CloudResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `CloudResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `CloudResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `CloudResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `CloudResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `CloudResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `CloudResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `CloudResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `CloudResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `CloudResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `CloudResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `CloudResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `CloudResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `CloudResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `CloudResource`)* | `String` |  |
| `nameLower` *(via `CloudResource`)* | `String` |  |
| `nativeId` *(via `CloudResource`)* | `String` |  |
| `resourceId` *(via `CloudResource`)* | `String` |  |
| `technicalType` *(via `CloudResource`)* | `String` |  |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages`, `azureRegions`, `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `CloudResource`)*

See [`relationships.md`](relationships.md#azurevirtualmachine) for edge labels, direction and destination entities.

### CloudFunction

- **Kind:** Query
- **Display name:** Cloud Function
- **Provider:** GCP
- **Alias of:** `GCPResource`
- **Sub-query:** `MATCH GCPResource AS r WHERE r.type = "Cloud Functions Function";`

A Cloud Function is a lightweight, event-driven compute service provided by GCP that allows you to run code in response to events without provisioning or managing servers.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `lastModified` *(via `GCPResource`)* | `DateTime` |  |
| `location` *(via `GCPResource`)* | `String` | The location of the resource. |
| `name` *(via `GCPResource`)* | `String` | The name of the resource. |
| `organization` *(via `GCPResource`)* | `String` | The organization of the resource. |
| `platform` *(via `GCPResource`)* | `String` | The platform of the resource. |
| `projectId` *(via `GCPResource`)* | `String` | The project ID of the resource. |
| `type` *(via `GCPResource`)* | `String` | The type of the resource. It can be any GCP resource type, like GCPProject, GCPBucket, etc. |
| `createDate` *(via `GCPResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `GCPResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `GCPResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `GCPResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `GCPResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `GCPResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `GCPResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `GCPResource`)* | `String` | The reachability of the vulnerability. |

_No public relationships._

### CloudRunJob

- **Kind:** Query
- **Display name:** Cloud Run Job
- **Provider:** GCP
- **Alias of:** `GCPResource`
- **Sub-query:** `MATCH GCPResource AS r WHERE r.type = "Cloud Run Job";`

A Cloud Run Job is a serverless platform for running containerized tasks provided by GCP that execute to completion and then stop, ideal for batch processing, data analysis, or scheduled workloads.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `lastModified` *(via `GCPResource`)* | `DateTime` |  |
| `location` *(via `GCPResource`)* | `String` | The location of the resource. |
| `name` *(via `GCPResource`)* | `String` | The name of the resource. |
| `organization` *(via `GCPResource`)* | `String` | The organization of the resource. |
| `platform` *(via `GCPResource`)* | `String` | The platform of the resource. |
| `projectId` *(via `GCPResource`)* | `String` | The project ID of the resource. |
| `type` *(via `GCPResource`)* | `String` | The type of the resource. It can be any GCP resource type, like GCPProject, GCPBucket, etc. |
| `createDate` *(via `GCPResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `GCPResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `GCPResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `GCPResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `GCPResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `GCPResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `GCPResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `GCPResource`)* | `String` | The reachability of the vulnerability. |

_No public relationships._

### CloudRunService

- **Kind:** Query
- **Display name:** Cloud Run Service
- **Provider:** GCP
- **Alias of:** `GCPResource`
- **Sub-query:** `MATCH GCPResource AS r WHERE r.type = "Cloud Run Service";`

A Cloud Run Service is a fully managed serverless platform provided by GCP that automatically scales containerized applications based on incoming requests.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `lastModified` *(via `GCPResource`)* | `DateTime` |  |
| `location` *(via `GCPResource`)* | `String` | The location of the resource. |
| `name` *(via `GCPResource`)* | `String` | The name of the resource. |
| `organization` *(via `GCPResource`)* | `String` | The organization of the resource. |
| `platform` *(via `GCPResource`)* | `String` | The platform of the resource. |
| `projectId` *(via `GCPResource`)* | `String` | The project ID of the resource. |
| `type` *(via `GCPResource`)* | `String` | The type of the resource. It can be any GCP resource type, like GCPProject, GCPBucket, etc. |
| `createDate` *(via `GCPResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `GCPResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `GCPResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `GCPResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `GCPResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `GCPResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `GCPResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `GCPResource`)* | `String` | The reachability of the vulnerability. |

_No public relationships._

### ContainerApp

- **Kind:** Query
- **Display name:** Container App
- **Provider:** Azure
- **Alias of:** `AzureResource`
- **Sub-query:** `MATCH AzureResource AS r WHERE r.type = "Container App";`

A Container App is a fully managed serverless container service provided by Azure that enables you to run containerized applications and microservices with built-in scaling, load balancing, and service discovery.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `lastModified` *(via `AzureResource`)* | `DateTime` |  |
| `location` *(via `AzureResource`)* | `String` | The location of the resource. |
| `name` *(via `AzureResource`)* | `String` | The name of the resource. |
| `organization` *(via `AzureResource`)* | `String` | The organization of the resource. |
| `platform` *(via `AzureResource`)* | `String` | The platform of the resource. |
| `type` *(via `AzureResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `AzureResource`)* | `Boolean` | Whether the resource is exposed. |
| `subscriptionId` *(via `AzureResource`)* | `String` | The subscription ID of the resource. |
| `firstSeen` *(via `AzureResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `AzureResource`)* | `DateTime` | The last date the resource was scanned. |
| `createdAt` *(via `AzureResource`)* | `DateTime` |  |
| `status` *(via `AzureResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `AzureResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `AzureResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `AzureResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `AzureResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `AzureResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `AzureResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `AzureResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `AzureResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |

**Relationships:** `packages`, `sbomComponents`, `applications`, `vulnerabilities`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `azureRegions`, `failedControls`, `zones`, `acceptedControls`, `aiPackages` *(via `AzureResource`)*

See [`relationships.md`](relationships.md#containerapp) for edge labels, direction and destination entities.

### ContainerAppJob

- **Kind:** Query
- **Display name:** Container App Job
- **Provider:** Azure
- **Alias of:** `AzureResource`
- **Sub-query:** `MATCH AzureResource AS r WHERE r.type = "Container App Job";`

A Container App Job is a serverless compute service provided by Azure that allows you to run containerized batch jobs and scheduled tasks with automatic scaling and job lifecycle management.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `lastModified` *(via `AzureResource`)* | `DateTime` |  |
| `location` *(via `AzureResource`)* | `String` | The location of the resource. |
| `name` *(via `AzureResource`)* | `String` | The name of the resource. |
| `organization` *(via `AzureResource`)* | `String` | The organization of the resource. |
| `platform` *(via `AzureResource`)* | `String` | The platform of the resource. |
| `type` *(via `AzureResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `AzureResource`)* | `Boolean` | Whether the resource is exposed. |
| `subscriptionId` *(via `AzureResource`)* | `String` | The subscription ID of the resource. |
| `firstSeen` *(via `AzureResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `AzureResource`)* | `DateTime` | The last date the resource was scanned. |
| `createdAt` *(via `AzureResource`)* | `DateTime` |  |
| `status` *(via `AzureResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `AzureResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `AzureResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `AzureResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `AzureResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `AzureResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `AzureResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `AzureResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `AzureResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |

**Relationships:** `packages`, `sbomComponents`, `applications`, `vulnerabilities`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `azureRegions`, `failedControls`, `zones`, `acceptedControls`, `aiPackages` *(via `AzureResource`)*

See [`relationships.md`](relationships.md#containerappjob) for edge labels, direction and destination entities.

### ContainerInstance

- **Kind:** Query
- **Display name:** Container Instance
- **Provider:** Azure
- **Alias of:** `AzureResource`
- **Sub-query:** `MATCH AzureResource AS r WHERE r.type = "Container Instance";`

A Container Instance is a serverless compute service provided by Azure that allows you to run containerized applications without managing the underlying infrastructure.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `lastModified` *(via `AzureResource`)* | `DateTime` |  |
| `location` *(via `AzureResource`)* | `String` | The location of the resource. |
| `name` *(via `AzureResource`)* | `String` | The name of the resource. |
| `organization` *(via `AzureResource`)* | `String` | The organization of the resource. |
| `platform` *(via `AzureResource`)* | `String` | The platform of the resource. |
| `type` *(via `AzureResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `AzureResource`)* | `Boolean` | Whether the resource is exposed. |
| `subscriptionId` *(via `AzureResource`)* | `String` | The subscription ID of the resource. |
| `firstSeen` *(via `AzureResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `AzureResource`)* | `DateTime` | The last date the resource was scanned. |
| `createdAt` *(via `AzureResource`)* | `DateTime` |  |
| `status` *(via `AzureResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `AzureResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `AzureResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `AzureResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `AzureResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `AzureResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `AzureResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `AzureResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `AzureResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |

**Relationships:** `packages`, `sbomComponents`, `applications`, `vulnerabilities`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `azureRegions`, `failedControls`, `zones`, `acceptedControls`, `aiPackages` *(via `AzureResource`)*

See [`relationships.md`](relationships.md#containerinstance) for edge labels, direction and destination entities.

### EC2Instance

- **Kind:** Query
- **Display name:** EC2 Instance
- **Provider:** AWS
- **Alias of:** [`CloudResource`](#cloudresource)
- **Sub-query:** `MATCH CloudResource AS r WHERE r.type = "EC2 Instance" AND r.platform = "AWS";`

An EC2 Instance represents a virtual machine running on AWS Elastic Compute Cloud (EC2).

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `publicIPs` | `List<String>` |  |
| `privateIPs` | `List<String>` |  |
| `lastSeen` | `DateTime` |  |
| `machineImage` | `String` | Amazon Machine Image (AMI) Id used to launch the EC2 Instance. |
| `clusterName` | `String` | The name of the cluster the resource belongs to. |
| `accountId` *(via `CloudResource`)* | `String` | The account ID of the resource. |
| `account` *(via `CloudResource`)* | `String` | The account of the resource. |
| `category` *(via `CloudResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `CloudResource`)* | `DateTime` |  |
| `name` *(via `CloudResource`)* | `String` | The name of the resource. |
| `organization` *(via `CloudResource`)* | `String` | The organization of the resource. |
| `platform` *(via `CloudResource`)* | `String` | The platform of the resource. |
| `location` *(via `CloudResource`)* | `String` | The location of the resource. |
| `type` *(via `CloudResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `CloudResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `CloudResource`)* | `DateTime` | The first date the resource was scanned. |
| `hostname` *(via `CloudResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `CloudResource`)* | `DateTime` |  |
| `arn` *(via `CloudResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `CloudResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `CloudResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `CloudResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `CloudResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `CloudResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `CloudResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `CloudResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `CloudResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `CloudResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `CloudResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `CloudResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `CloudResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `CloudResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `CloudResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `CloudResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `CloudResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `CloudResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `CloudResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `CloudResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `CloudResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `CloudResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `CloudResource`)* | `String` |  |
| `nameLower` *(via `CloudResource`)* | `String` |  |
| `nativeId` *(via `CloudResource`)* | `String` |  |
| `resourceId` *(via `CloudResource`)* | `String` |  |
| `technicalType` *(via `CloudResource`)* | `String` |  |

**Relationships:** `vrtLaunchTemplates`, `packages`, `applications`, `vulnerabilities`, `iamRoles3Buckets`, `zones`, `vrtHasKubeNode`, `containers`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtMalwareFindings`, `exposedCloudResources`, `vrtPackages`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages`; `vrtRunsContainer`, `vrtThreats`, `sensitiveData`, `azureRegions`, `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `CloudResource`)*

See [`relationships.md`](relationships.md#ec2instance) for edge labels, direction and destination entities.

### EC2LaunchTemplate

- **Kind:** Query
- **Display name:** EC2 Launch Template
- **Provider:** AWS
- **Alias of:** `AWSResource`
- **Sub-query:** `MATCH AWSResource AS r WHERE r.type = "EC2 Launch template";`

An EC2 Launch Template defines the configuration for launching EC2 instances, including AMI, instance type, security groups, and other launch parameters.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `AWSResource`)* | `String` | The account ID of the resource. |
| `account` *(via `AWSResource`)* | `String` | The account of the resource. |
| `category` *(via `AWSResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `AWSResource`)* | `DateTime` |  |
| `name` *(via `AWSResource`)* | `String` | The name of the resource. |
| `organization` *(via `AWSResource`)* | `String` | The organization of the resource. |
| `platform` *(via `AWSResource`)* | `String` | The platform of the resource. |
| `location` *(via `AWSResource`)* | `String` | The location of the resource. |
| `type` *(via `AWSResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `AWSResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `AWSResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `AWSResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `AWSResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `AWSResource`)* | `DateTime` |  |
| `publicIPs` *(via `AWSResource`)* | `List<String>` |  |
| `privateIPs` *(via `AWSResource`)* | `List<String>` |  |
| `arn` *(via `AWSResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `AWSResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `AWSResource`)* | `String` | The task definition family of the resource. |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages` *(via `AWSResource`)*

See [`relationships.md`](relationships.md#ec2launchtemplate) for edge labels, direction and destination entities.

### ECSClusterTask

- **Kind:** Query
- **Display name:** ECS Cluster Task
- **Provider:** AWS
- **Alias of:** `AWSResource`
- **Sub-query:** `MATCH AWSResource AS r WHERE r.type = "ECS Cluster Task";`

A running instance of a containerized application within an ECS cluster provided by AWS.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `AWSResource`)* | `String` | The account ID of the resource. |
| `account` *(via `AWSResource`)* | `String` | The account of the resource. |
| `category` *(via `AWSResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `AWSResource`)* | `DateTime` |  |
| `name` *(via `AWSResource`)* | `String` | The name of the resource. |
| `organization` *(via `AWSResource`)* | `String` | The organization of the resource. |
| `platform` *(via `AWSResource`)* | `String` | The platform of the resource. |
| `location` *(via `AWSResource`)* | `String` | The location of the resource. |
| `type` *(via `AWSResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `AWSResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `AWSResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `AWSResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `AWSResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `AWSResource`)* | `DateTime` |  |
| `publicIPs` *(via `AWSResource`)* | `List<String>` |  |
| `privateIPs` *(via `AWSResource`)* | `List<String>` |  |
| `arn` *(via `AWSResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `AWSResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `AWSResource`)* | `String` | The task definition family of the resource. |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages` *(via `AWSResource`)*

See [`relationships.md`](relationships.md#ecsclustertask) for edge labels, direction and destination entities.

### ECSFargateService

- **Kind:** Query
- **Display name:** ECS Fargate Service
- **Provider:** AWS
- **Alias of:** `AWSResource`
- **Sub-query:** `MATCH AWSResource AS r WHERE r.type = "ECS Fargate Service";`

Serverless container orchestration service that runs Docker containers without managing underlying servers provided by AWS.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `AWSResource`)* | `String` | The account ID of the resource. |
| `account` *(via `AWSResource`)* | `String` | The account of the resource. |
| `category` *(via `AWSResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `AWSResource`)* | `DateTime` |  |
| `name` *(via `AWSResource`)* | `String` | The name of the resource. |
| `organization` *(via `AWSResource`)* | `String` | The organization of the resource. |
| `platform` *(via `AWSResource`)* | `String` | The platform of the resource. |
| `location` *(via `AWSResource`)* | `String` | The location of the resource. |
| `type` *(via `AWSResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `AWSResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `AWSResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `AWSResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `AWSResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `AWSResource`)* | `DateTime` |  |
| `publicIPs` *(via `AWSResource`)* | `List<String>` |  |
| `privateIPs` *(via `AWSResource`)* | `List<String>` |  |
| `arn` *(via `AWSResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `AWSResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `AWSResource`)* | `String` | The task definition family of the resource. |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages` *(via `AWSResource`)*

See [`relationships.md`](relationships.md#ecsfargateservice) for edge labels, direction and destination entities.

### ECSService

- **Kind:** Query
- **Display name:** ECS Service
- **Provider:** AWS
- **Alias of:** `AWSResource`
- **Sub-query:** `MATCH AWSResource AS r WHERE r.type = "ECS Service";`

Container orchestration platform that manages Docker containers at scale provided by AWS.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `AWSResource`)* | `String` | The account ID of the resource. |
| `account` *(via `AWSResource`)* | `String` | The account of the resource. |
| `category` *(via `AWSResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `AWSResource`)* | `DateTime` |  |
| `name` *(via `AWSResource`)* | `String` | The name of the resource. |
| `organization` *(via `AWSResource`)* | `String` | The organization of the resource. |
| `platform` *(via `AWSResource`)* | `String` | The platform of the resource. |
| `location` *(via `AWSResource`)* | `String` | The location of the resource. |
| `type` *(via `AWSResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `AWSResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `AWSResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `AWSResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `AWSResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `AWSResource`)* | `DateTime` |  |
| `publicIPs` *(via `AWSResource`)* | `List<String>` |  |
| `privateIPs` *(via `AWSResource`)* | `List<String>` |  |
| `arn` *(via `AWSResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `AWSResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `AWSResource`)* | `String` | The task definition family of the resource. |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages` *(via `AWSResource`)*

See [`relationships.md`](relationships.md#ecsservice) for edge labels, direction and destination entities.

### GCPCloudFunction

- **Kind:** Query
- **Display name:** GCP Cloud Function
- **Provider:** GCP
- **Alias of:** [`CloudResource`](#cloudresource)
- **Sub-query:** `MATCH CloudResource AS r WHERE r.type = "Cloud Function" AND r.platform = "GCP";`

A GCP Cloud Function represents a serverless compute function that executes in response to events.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `CloudResource`)* | `String` | The account ID of the resource. |
| `account` *(via `CloudResource`)* | `String` | The account of the resource. |
| `category` *(via `CloudResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `CloudResource`)* | `DateTime` |  |
| `name` *(via `CloudResource`)* | `String` | The name of the resource. |
| `organization` *(via `CloudResource`)* | `String` | The organization of the resource. |
| `platform` *(via `CloudResource`)* | `String` | The platform of the resource. |
| `location` *(via `CloudResource`)* | `String` | The location of the resource. |
| `type` *(via `CloudResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `CloudResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `CloudResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `CloudResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `CloudResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `CloudResource`)* | `DateTime` |  |
| `publicIPs` *(via `CloudResource`)* | `List<String>` |  |
| `privateIPs` *(via `CloudResource`)* | `List<String>` |  |
| `arn` *(via `CloudResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `CloudResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `CloudResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `CloudResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `CloudResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `CloudResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `CloudResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `CloudResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `CloudResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `CloudResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `CloudResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `CloudResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `CloudResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `CloudResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `CloudResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `CloudResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `CloudResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `CloudResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `CloudResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `CloudResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `CloudResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `CloudResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `CloudResource`)* | `String` |  |
| `nameLower` *(via `CloudResource`)* | `String` |  |
| `nativeId` *(via `CloudResource`)* | `String` |  |
| `resourceId` *(via `CloudResource`)* | `String` |  |
| `technicalType` *(via `CloudResource`)* | `String` |  |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages`, `azureRegions`, `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `CloudResource`)*

See [`relationships.md`](relationships.md#gcpcloudfunction) for edge labels, direction and destination entities.

### GCPComputeInstance

- **Kind:** Query
- **Display name:** GCP Compute Instance
- **Provider:** GCP
- **Alias of:** [`CloudResource`](#cloudresource)
- **Sub-query:** `MATCH CloudResource AS r WHERE r.type = "Compute Instance" AND r.platform = "GCP";`

A GCP Compute Instance represents a virtual machine running on Google Cloud Compute Engine.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `clusterName` | `String` | The name of the cluster the resource belongs to. |
| `accountId` *(via `CloudResource`)* | `String` | The account ID of the resource. |
| `account` *(via `CloudResource`)* | `String` | The account of the resource. |
| `category` *(via `CloudResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `CloudResource`)* | `DateTime` |  |
| `name` *(via `CloudResource`)* | `String` | The name of the resource. |
| `organization` *(via `CloudResource`)* | `String` | The organization of the resource. |
| `platform` *(via `CloudResource`)* | `String` | The platform of the resource. |
| `location` *(via `CloudResource`)* | `String` | The location of the resource. |
| `type` *(via `CloudResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `CloudResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `CloudResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `CloudResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `CloudResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `CloudResource`)* | `DateTime` |  |
| `publicIPs` *(via `CloudResource`)* | `List<String>` |  |
| `privateIPs` *(via `CloudResource`)* | `List<String>` |  |
| `arn` *(via `CloudResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `CloudResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `CloudResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `CloudResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `CloudResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `CloudResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `CloudResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `CloudResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `CloudResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `CloudResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `CloudResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `CloudResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `CloudResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `CloudResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `CloudResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `CloudResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `CloudResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `CloudResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `CloudResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `CloudResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `CloudResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `CloudResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `CloudResource`)* | `String` |  |
| `nameLower` *(via `CloudResource`)* | `String` |  |
| `nativeId` *(via `CloudResource`)* | `String` |  |
| `resourceId` *(via `CloudResource`)* | `String` |  |
| `technicalType` *(via `CloudResource`)* | `String` |  |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages`, `azureRegions`, `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `CloudResource`)*

See [`relationships.md`](relationships.md#gcpcomputeinstance) for edge labels, direction and destination entities.

### Host

- **Kind:** Entity

A Host represents a physical or virtual machine running software workloads.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `name` | `String` | The name of the host. |
| `location` | `String` | The location of the host. |
| `subscriptionId` | `String` | The subscription ID of the resource. |
| `accountId` | `String` | The cloud provider account ID. |
| `platform` | `String` | The platform of the resource. |
| `type` | `String` | The type of the resource. It can be any Azure resource type, like AzureProject, AzureBucket, etc. |
| `lastModified` | `DateTime` |  |
| `operatingSystem` | `String` | The operating system of the host. |
| `hostname` | `String` | The hostname of the host. |
| `architecture` | `String` | The architecture of the host. |
| `kernelVersion` | `String` | The kernel version of the host. |
| `firstSeen` | `DateTime` |  |
| `lastSeen` | `DateTime` |  |
| `isExposed` | `Boolean` | Whether the host is exposed. |
| `clusterName` | `String` | The name of the cluster the resource belongs to. |

**Relationships:** `packages`, `sbomComponents`, `applications`, `vulnerabilities`, `kubeNodes`, `regions`, `exposedCloudResources`, `vrtRuntimeEvents`, `vrtMalwareFindings`, `failedControls`, `zones`, `exposedBy`, `publiclyExposedBy`

See [`relationships.md`](relationships.md#host) for edge labels, direction and destination entities.


## Detections

### RuntimeEvent

- **Kind:** Entity
- **Display name:** Runtime Event

Sysdig Runtime Events refer to security and system activity events detected in real-time by Sysdig Secure during the execution of applications and containers. These events are generated based on Falco rules, which define security policies and anomalous behaviors

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `clusterName` | `String` | The name of the cluster. |
| `firstGeneratedTimestamp` | `DateTime` |  |
| `hostName` | `String` | The name of the host. |
| `key` | `String` | The key of the event. |
| `lastGeneratedTimestamp` | `DateTime` |  |
| `lastModified` | `DateTime` |  |
| `policyName` | `String` | The name of the policy that generated the event. |
| `processName` | `String` | The name of the process that generated the event. |
| `ruleName` | `String` | The name of the rule that generated the event. |
| `severity` | `Enum<String>` | The severity of the event. Values can be Critical, High, Medium, Low, or Info. Values: Info, Low, Medium, High, Critical. |
| `source` | `String` | The source of the event. |
| `eventType` | `String` | The type of detected event. |
| `fileDescriptorName` | `String` | The file descriptor name of the detected malware. |
| `malwareHash` | `String` | The hash signature of the detected malware. |
| `malwareCategory` | `String` | The category of the detected malware. |
| `malwareSizeInBytes` | `String` | The size of the malware file descriptor in bytes. |
| `matchType` | `String` | The match method used for malware identification. |

**Relationships:** `cloudResources`, `workloads`, `gcpProjects`, `azureSubscriptions`, `awsAccounts`, `kubeResources`, `iamUsers`

See [`relationships.md`](relationships.md#runtimeevent) for edge labels, direction and destination entities.

### Threat

- **Kind:** Entity

Threats surface context and security signals to highlight malicious activity detected for a resource.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `threatId` | `String` | The ID of the Threat |
| `name` | `String` | The name of the Threat |
| `type` | `String` | The type of the Threat (CLOUD, KUBERNETES_WORKLOAD, HOST, CONTAINER) |
| `status` | `String` | The status of the Threat |
| `detectedAt` | `DateTime` | Detection time of the Threat |
| `highConfidence` | `Boolean` | Wheater the threat is high confidence or not |
| `rules` | `List<String>` | List of triggered rules for the Threat |

**Relationships:** `kubeNodes`, `kubeWorkload`, `imageManifest`, `awsResources`, `azureResources`, `gcpResources`

See [`relationships.md`](relationships.md#threat) for edge labels, direction and destination entities.


## Environment

### AzureOrganization

- **Kind:** Entity
- **Display name:** Azure Organization
- **Provider:** Azure

An Azure Organization represents a collection of Azure subscriptions managed under a single entity.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the organization. |

**Relationships:** `vrtAzureSubscriptions`

See [`relationships.md`](relationships.md#azureorganization) for edge labels, direction and destination entities.

### AzureSubscription

- **Kind:** Entity
- **Display name:** Azure Subscription
- **Provider:** Azure

An Azure Subscription represents a billing and access management entity for Azure resources.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the subscription. |
| `id` | `String` | The id of the subscription. |

**Relationships:** `cloudResources`, `vrtAzureRegions`, `vrtRuntimeEvents`

See [`relationships.md`](relationships.md#azuresubscription) for edge labels, direction and destination entities.

### CloudAccount

- **Kind:** Union
- **Display name:** Cloud Account
- **Resolves to:** `AWSAccount`, [`AzureSubscription`](#azuresubscription), [`GCPProject`](#gcpproject)
- **Selector:** `abstractType` (`AWSAccount` → `AWSAccount`, `AzureSubscription` → [`AzureSubscription`](#azuresubscription), `GCPProject` → [`GCPProject`](#gcpproject))

A Cloud Account represents a cloud provider account. Supports AWS, Azure, and GCP.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `lastModified` *(via `AzureSubscription`)* | `DateTime` |  |
| `name` *(via `AzureSubscription`)* | `String` | The name of the subscription. |
| `id` *(via `AzureSubscription`)* | `String` | The id of the subscription. |

**Relationships:** `cloudResources`, `vrtAzureRegions`, `vrtRuntimeEvents` *(via `AzureSubscription`)*; `vrtGcpRegions`, `gcpOrganizations` *(via `GCPProject`)*

See [`relationships.md`](relationships.md#cloudaccount) for edge labels, direction and destination entities.

### CloudResource

- **Kind:** Union
- **Display name:** Cloud Resource
- **Resolves to:** `AWSResource`, `AzureResource`, `GCPResource`, [`IBMResource`](#ibmresource), [`OCIResource`](#ociresource)
- **Selector:** `platform` (`AWS` → `AWSResource`, `Azure` → `AzureResource`, `GCP` → `GCPResource`, `IBM` → [`IBMResource`](#ibmresource), `OCI` → [`OCIResource`](#ociresource))

A Cloud Resource represents a resource in a cloud provider. Supports AWS, Azure, GCP, IBM, and OCI.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `AWSResource`)* | `String` | The account ID of the resource. |
| `account` *(via `AWSResource`)* | `String` | The account of the resource. |
| `category` *(via `AWSResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `AWSResource`)* | `DateTime` |  |
| `name` *(via `AWSResource`)* | `String` | The name of the resource. |
| `organization` *(via `AWSResource`)* | `String` | The organization of the resource. |
| `platform` *(via `AWSResource`)* | `String` | The platform of the resource. |
| `location` *(via `AWSResource`)* | `String` | The location of the resource. |
| `type` *(via `AWSResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `AWSResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `AWSResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `AWSResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `AWSResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `AWSResource`)* | `DateTime` |  |
| `publicIPs` *(via `AWSResource`)* | `List<String>` |  |
| `privateIPs` *(via `AWSResource`)* | `List<String>` |  |
| `arn` *(via `AWSResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `AWSResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `AWSResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `AzureResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `AzureResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `AzureResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `AzureResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `AzureResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `AzureResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `AzureResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `AzureResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `AzureResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `AzureResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `GCPResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `GCPResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `GCPResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `GCPResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `GCPResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `GCPResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `GCPResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `GCPResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `GCPResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `IBMResource`)* | `String` |  |
| `nameLower` *(via `IBMResource`)* | `String` |  |
| `nativeId` *(via `IBMResource`)* | `String` |  |
| `resourceId` *(via `IBMResource`)* | `String` |  |
| `technicalType` *(via `IBMResource`)* | `String` |  |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages` *(via `AWSResource`)*; `azureRegions` *(via `AzureResource`)*; `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `IBMResource`)*

See [`relationships.md`](relationships.md#cloudresource) for edge labels, direction and destination entities.

### Endpoint

- **Kind:** Query
- **Alias of:** `ExposureEndpoint`
- **Sub-query:** `MATCH ExposureEndpoint;`

The exposure endpoint of a resource

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `portStart` *(via `ExposureEndpoint`)* | `BigInt` |  |
| `protocol` *(via `ExposureEndpoint`)* | `String` |  |
| `ipv4` *(via `ExposureEndpoint`)* | `Boolean` |  |
| `ip` *(via `ExposureEndpoint`)* | `String` |  |
| `customerId` *(via `ExposureEndpoint`)* | `BigInt` |  |
| `portEnd` *(via `ExposureEndpoint`)* | `BigInt` |  |
| `lastModified` *(via `ExposureEndpoint`)* | `DateTime` |  |
| `validationTaskId` *(via `ExposureEndpoint`)* | `String` |  |
| `taskId` *(via `ExposureEndpoint`)* | `String` |  |
| `scanDate` *(via `ExposureEndpoint`)* | `DateTime` |  |
| `domainsMap` *(via `ExposureEndpoint`)* | `String` |  |

**Relationships:** `validatedBy`

See [`relationships.md`](relationships.md#endpoint) for edge labels, direction and destination entities.

### GCPOrganization

- **Kind:** Entity
- **Display name:** GCP Organization
- **Provider:** GCP

A GCP Organization represents the top-level container for GCP resources, including projects.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the organization. |

**Relationships:** `gcpProjects`

See [`relationships.md`](relationships.md#gcporganization) for edge labels, direction and destination entities.

### GCPProject

- **Kind:** Entity
- **Display name:** GCP Project
- **Provider:** GCP

A GCP Project represents a set of cloud resources organized under a single entity.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the project. |
| `id` | `String` | The id of the project. |

**Relationships:** `cloudResources`, `vrtGcpRegions`, `vrtRuntimeEvents`, `gcpOrganizations`

See [`relationships.md`](relationships.md#gcpproject) for edge labels, direction and destination entities.

### IBMAccount

- **Kind:** Entity
- **Display name:** IBM Account
- **Provider:** IBM

An IBMAccount

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `platform` | `String` |  |
| `id` | `String` |  |
| `createdAt` | `DateTime` |  |
| `name` | `String` |  |
| `lastModified` | `DateTime` |  |

_No public relationships._

### IBMResource

- **Kind:** Entity
- **Display name:** IBM Resource
- **Provider:** IBM

An IBMResource represents a resource in IBM  (e.g. IBM IAM policy).

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `account` | `String` |  |
| `accountId` | `String` |  |
| `categoryV2` | `String` |  |
| `createdAt` | `DateTime` |  |
| `firstSeen` | `DateTime` |  |
| `lastModified` | `DateTime` |  |
| `lastSeen` | `DateTime` |  |
| `location` | `String` |  |
| `name` | `String` |  |
| `nameLower` | `String` |  |
| `nativeId` | `String` |  |
| `organization` | `String` |  |
| `platform` | `String` |  |
| `resourceId` | `String` |  |
| `technicalType` | `String` |  |
| `type` | `String` |  |

**Relationships:** `acceptsControl`, `passesControl`, `violatesControl`, `inZone`

See [`relationships.md`](relationships.md#ibmresource) for edge labels, direction and destination entities.

### OCICompartment

- **Kind:** Entity
- **Display name:** OCI Compartment
- **Provider:** OCI

An Oracle Cloud Infrastructure Compartment

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `platform` | `String` |  |
| `id` | `String` |  |
| `createdAt` | `DateTime` |  |
| `lastModified` | `DateTime` |  |
| `name` | `String` |  |

_No public relationships._

### OCIResource

- **Kind:** Entity
- **Display name:** OCI Resource
- **Provider:** OCI

An OCIResource represents a resource in the Oracle Cloud Infrastructure .

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `account` | `String` |  |
| `categoryV2` | `String` |  |
| `createdAt` | `DateTime` |  |
| `firstSeen` | `DateTime` |  |
| `lastModified` | `DateTime` |  |
| `lastSeen` | `DateTime` |  |
| `location` | `String` |  |
| `name` | `String` |  |
| `nameLower` | `String` |  |
| `nativeId` | `String` |  |
| `organization` | `String` |  |
| `platform` | `String` |  |
| `resourceId` | `String` |  |
| `technicalType` | `String` |  |
| `type` | `String` |  |

**Relationships:** `passesControl`, `violatesControl`, `inZone`

See [`relationships.md`](relationships.md#ociresource) for edge labels, direction and destination entities.

### Region

- **Kind:** Union
- **Resolves to:** `AWSRegion`, `AzureRegion`, `GCPRegion`, `IBMRegion`, `OCIRegion`
- **Selector:** `platform` (`AWS` → `AWSRegion`, `Azure` → `AzureRegion`, `GCP` → `GCPRegion`, `IBM` → `IBMRegion`, `OCI` → `OCIRegion`)

A Region represents a geographical location where cloud services are deployed.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `lastModified` *(via `AWSRegion`)* | `DateTime` |  |
| `name` *(via `AWSRegion`)* | `String` | The name of the region. |
| `accountId` *(via `IBMRegion`)* | `String` |  |
| `createdAt` *(via `IBMRegion`)* | `DateTime` |  |

**Relationships:** `vrtCloudResources`, `vrtIamUsers`, `vrIamRoles`, `vrtIamPolicies`, `vrtRegions`, `awsAccounts`, `vrtAwsAccounts`, `vrtIamGroups` *(via `AWSRegion`)*; `azureSubscriptions` *(via `AzureRegion`)*

See [`relationships.md`](relationships.md#region) for edge labels, direction and destination entities.

### Zone

- **Kind:** Entity

A zone, in Sysdig, is a collection of scopes that represent important areas of your business. For example, you can create a zone for your production environment, a staging environment, or a region.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `id` | `Float` | The ID of the zone. |
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the zone. |

**Relationships:** `vrtIamPolicies`, `vrtContainers`, `vrtImages`, `vrtIamUsers`, `vrtKubeIdentities`, `vrtCloudResources`, `vrtKubeNodes`, `vrtIamRoles`, `vrtIamGroups`, `vrtKubeWorkloads`, `vrtKubeResources`, `containsHost`, `host`

See [`relationships.md`](relationships.md#zone) for edge labels, direction and destination entities.


## Findings

### AIPackage

- **Kind:** Query
- **Display name:** AI Package
- **Alias of:** [`Control`](#control)
- **Sub-query:** `MATCH Control AS c WHERE c.id = 21551;`

Represents a control indicating that the workload contains an AI package.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `id` *(via `Control`)* | `BigInt` | The ID of the control. |
| `lastModified` *(via `Control`)* | `DateTime` |  |
| `name` *(via `Control`)* | `String` | The name of the control. |
| `severity` *(via `Control`)* | `Enum<String>` | The severity of the control. Values can be High, Medium, Low, or Info. Values: Info, Low, Medium, High. |
| `isPrivileged` *(via `Control`)* | `Boolean` | Whether the control is privileged. A privileged control is a control that has elevated permissions. |
| `isNetwork` *(via `Control`)* | `Boolean` | Whether the control is network-related. A network control is a control that is related to network security. |
| `authors` *(via `Control`)* | `String` | Authors of the control. |
| `type` *(via `Control`)* | `Integer` | The type of the control. |
| `description` *(via `Control`)* | `String` | The description of the control. |
| `isManual` *(via `Control`)* | `Boolean` | Whether the control is manual. A manual control is a control that requires human intervention. |
| `targetSystem` *(via `Control`)* | `BigInt` | The target system of the control. |
| `remediationDetails` *(via `Control`)* | `String` | The remediation details for the control. |
| `remediationId` *(via `Control`)* | `BigInt` | The ID to retrieve further remediation details for the control. |
| `platform` *(via `Control`)* | `String` |  |

**Relationships:** `vrtFailedIAMPolicies`, `vrtAcceptedKubeWorkloads`, `vrtAcceptedIAMPolicies`, `vrtCloudAcceptedResources`, `vrtFailedKubeIdentities`, `vrtFailedKubeWorkloads`, `vrtAcceptedKubeIdentities`, `vrtCloudFailedResources`, `passingCloudResources`, `vrtPassingCloudResources`, `passingKubeResources`, `vrtPassingKubeResources`, `failingKubeResources`, `vrtfailingKubeResources`, `acceptingKubeResources`, `vrtAcceptingKubeResources`, `passedKubeNodes`, `violatedKubeNodes`, `acceptedKubeNodes` *(via `Control`)*

See [`relationships.md`](relationships.md#aipackage) for edge labels, direction and destination entities.

### Control

- **Kind:** Entity

Sysdig posture controls are built on the Open Policy Agent (OPA) engine, using the OPA policy language Rego. The platform exposes the code used to create these controls and the inputs they evaluate. These controls are available in Sysdig's Posture Controls library.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `id` | `BigInt` | The ID of the control. |
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the control. |
| `severity` | `Enum<String>` | The severity of the control. Values can be High, Medium, Low, or Info. Values: Info, Low, Medium, High. |
| `isPrivileged` | `Boolean` | Whether the control is privileged. A privileged control is a control that has elevated permissions. |
| `isNetwork` | `Boolean` | Whether the control is network-related. A network control is a control that is related to network security. |
| `authors` | `String` | Authors of the control. |
| `type` | `Integer` | The type of the control. |
| `description` | `String` | The description of the control. |
| `isManual` | `Boolean` | Whether the control is manual. A manual control is a control that requires human intervention. |
| `targetSystem` | `BigInt` | The target system of the control. |
| `remediationDetails` | `String` | The remediation details for the control. |
| `remediationId` | `BigInt` | The ID to retrieve further remediation details for the control. |
| `platform` | `String` |  |

**Relationships:** `vrtFailedIAMPolicies`, `vrtAcceptedKubeWorkloads`, `vrtAcceptedIAMPolicies`, `vrtCloudAcceptedResources`, `vrtFailedKubeIdentities`, `vrtFailedKubeWorkloads`, `vrtAcceptedKubeIdentities`, `vrtCloudFailedResources`, `passingCloudResources`, `vrtPassingCloudResources`, `passingKubeResources`, `vrtPassingKubeResources`, `failingKubeResources`, `vrtfailingKubeResources`, `acceptingKubeResources`, `vrtAcceptingKubeResources`, `passedKubeNodes`, `violatedKubeNodes`, `acceptedKubeNodes`

See [`relationships.md`](relationships.md#control) for edge labels, direction and destination entities.

### Malware

- **Kind:** Entity
- **Display name:** Malware Finding

When a Malware Control policy is created, depending on the options selected, Sysdig Agent can use a managed database to monitor executions in a container/on the node for any malware. When a malicious binary is detected, the agent generates an event and can optionally block the execution from starting.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `description` | `String` | The description associated with the malware finding. |
| `severity` | `Enum<String>` | The severity of the event. Values can be High, Medium, Low, or Info. Values: Info, Low, Medium, High. |
| `fileDir` | `String` | The directory where the malware file was located. |
| `fileName` | `String` | The name of the malware file. |
| `fileType` | `String` | The file type of the malware file. |
| `matchType` | `String` | The match method used for malware identification. |
| `hostName` | `String` | The name of the host. |
| `malwareHash` | `String` | The hash signature of the malware file. |
| `malwareCategory` | `String` | The category of the malware. |
| `malwareSizeInBytes` | `String` | The size of the malware file descriptor in bytes. |
| `firstSeen` | `DateTime` | The timestamp when the malware file was first scanned. |
| `lastSeen` | `DateTime` | The timestamp when the malware file was last scanned. |
| `lastGenerated` | `DateTime` |  |
| `lastModified` | `DateTime` |  |

**Relationships:** `host`, `cloudResources`

See [`relationships.md`](relationships.md#malware) for edge labels, direction and destination entities.

### PrivilegedControl

- **Kind:** Query
- **Display name:** Privileged Control
- **Alias of:** [`Control`](#control)
- **Sub-query:** `MATCH Control AS c WHERE c.isPrivileged = true;`

Represents a privileged control.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `id` *(via `Control`)* | `BigInt` | The ID of the control. |
| `lastModified` *(via `Control`)* | `DateTime` |  |
| `name` *(via `Control`)* | `String` | The name of the control. |
| `severity` *(via `Control`)* | `Enum<String>` | The severity of the control. Values can be High, Medium, Low, or Info. Values: Info, Low, Medium, High. |
| `isPrivileged` *(via `Control`)* | `Boolean` | Whether the control is privileged. A privileged control is a control that has elevated permissions. |
| `isNetwork` *(via `Control`)* | `Boolean` | Whether the control is network-related. A network control is a control that is related to network security. |
| `authors` *(via `Control`)* | `String` | Authors of the control. |
| `type` *(via `Control`)* | `Integer` | The type of the control. |
| `description` *(via `Control`)* | `String` | The description of the control. |
| `isManual` *(via `Control`)* | `Boolean` | Whether the control is manual. A manual control is a control that requires human intervention. |
| `targetSystem` *(via `Control`)* | `BigInt` | The target system of the control. |
| `remediationDetails` *(via `Control`)* | `String` | The remediation details for the control. |
| `remediationId` *(via `Control`)* | `BigInt` | The ID to retrieve further remediation details for the control. |
| `platform` *(via `Control`)* | `String` |  |

**Relationships:** `vrtFailedIAMPolicies`, `vrtAcceptedKubeWorkloads`, `vrtAcceptedIAMPolicies`, `vrtCloudAcceptedResources`, `vrtFailedKubeIdentities`, `vrtFailedKubeWorkloads`, `vrtAcceptedKubeIdentities`, `vrtCloudFailedResources`, `passingCloudResources`, `vrtPassingCloudResources`, `passingKubeResources`, `vrtPassingKubeResources`, `failingKubeResources`, `vrtfailingKubeResources`, `acceptingKubeResources`, `vrtAcceptingKubeResources`, `passedKubeNodes`, `violatedKubeNodes`, `acceptedKubeNodes` *(via `Control`)*

See [`relationships.md`](relationships.md#privilegedcontrol) for edge labels, direction and destination entities.

### S3AcceptsHTTP

- **Kind:** Query
- **Display name:** S3 Accepts HTTP
- **Alias of:** [`Control`](#control)
- **Sub-query:** `MATCH Control AS c WHERE c.name = "S3 - Disabled HTTP Requests";`

Represents a control that accepts HTTP requests to S3.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `id` *(via `Control`)* | `BigInt` | The ID of the control. |
| `lastModified` *(via `Control`)* | `DateTime` |  |
| `name` *(via `Control`)* | `String` | The name of the control. |
| `severity` *(via `Control`)* | `Enum<String>` | The severity of the control. Values can be High, Medium, Low, or Info. Values: Info, Low, Medium, High. |
| `isPrivileged` *(via `Control`)* | `Boolean` | Whether the control is privileged. A privileged control is a control that has elevated permissions. |
| `isNetwork` *(via `Control`)* | `Boolean` | Whether the control is network-related. A network control is a control that is related to network security. |
| `authors` *(via `Control`)* | `String` | Authors of the control. |
| `type` *(via `Control`)* | `Integer` | The type of the control. |
| `description` *(via `Control`)* | `String` | The description of the control. |
| `isManual` *(via `Control`)* | `Boolean` | Whether the control is manual. A manual control is a control that requires human intervention. |
| `targetSystem` *(via `Control`)* | `BigInt` | The target system of the control. |
| `remediationDetails` *(via `Control`)* | `String` | The remediation details for the control. |
| `remediationId` *(via `Control`)* | `BigInt` | The ID to retrieve further remediation details for the control. |
| `platform` *(via `Control`)* | `String` |  |

**Relationships:** `vrtFailedIAMPolicies`, `vrtAcceptedKubeWorkloads`, `vrtAcceptedIAMPolicies`, `vrtCloudAcceptedResources`, `vrtFailedKubeIdentities`, `vrtFailedKubeWorkloads`, `vrtAcceptedKubeIdentities`, `vrtCloudFailedResources`, `passingCloudResources`, `vrtPassingCloudResources`, `passingKubeResources`, `vrtPassingKubeResources`, `failingKubeResources`, `vrtfailingKubeResources`, `acceptingKubeResources`, `vrtAcceptingKubeResources`, `passedKubeNodes`, `violatedKubeNodes`, `acceptedKubeNodes` *(via `Control`)*

See [`relationships.md`](relationships.md#s3acceptshttp) for edge labels, direction and destination entities.

### S3VersioningDisabled

- **Kind:** Query
- **Display name:** S3 Versioning Disabled
- **Alias of:** [`Control`](#control)
- **Sub-query:** `MATCH Control AS c WHERE c.name = "S3 - Enabled Versioning";`

Represents a control that disables versioning on S3 buckets.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `id` *(via `Control`)* | `BigInt` | The ID of the control. |
| `lastModified` *(via `Control`)* | `DateTime` |  |
| `name` *(via `Control`)* | `String` | The name of the control. |
| `severity` *(via `Control`)* | `Enum<String>` | The severity of the control. Values can be High, Medium, Low, or Info. Values: Info, Low, Medium, High. |
| `isPrivileged` *(via `Control`)* | `Boolean` | Whether the control is privileged. A privileged control is a control that has elevated permissions. |
| `isNetwork` *(via `Control`)* | `Boolean` | Whether the control is network-related. A network control is a control that is related to network security. |
| `authors` *(via `Control`)* | `String` | Authors of the control. |
| `type` *(via `Control`)* | `Integer` | The type of the control. |
| `description` *(via `Control`)* | `String` | The description of the control. |
| `isManual` *(via `Control`)* | `Boolean` | Whether the control is manual. A manual control is a control that requires human intervention. |
| `targetSystem` *(via `Control`)* | `BigInt` | The target system of the control. |
| `remediationDetails` *(via `Control`)* | `String` | The remediation details for the control. |
| `remediationId` *(via `Control`)* | `BigInt` | The ID to retrieve further remediation details for the control. |
| `platform` *(via `Control`)* | `String` |  |

**Relationships:** `vrtFailedIAMPolicies`, `vrtAcceptedKubeWorkloads`, `vrtAcceptedIAMPolicies`, `vrtCloudAcceptedResources`, `vrtFailedKubeIdentities`, `vrtFailedKubeWorkloads`, `vrtAcceptedKubeIdentities`, `vrtCloudFailedResources`, `passingCloudResources`, `vrtPassingCloudResources`, `passingKubeResources`, `vrtPassingKubeResources`, `failingKubeResources`, `vrtfailingKubeResources`, `acceptingKubeResources`, `vrtAcceptingKubeResources`, `passedKubeNodes`, `violatedKubeNodes`, `acceptedKubeNodes` *(via `Control`)*

See [`relationships.md`](relationships.md#s3versioningdisabled) for edge labels, direction and destination entities.

### SensitiveData

- **Kind:** Entity
- **Display name:** Sensitive Data

Sensitive Data is part of a hierarchy of data classes and data categories of sensitive data.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `dataClass` | `String` | dataClass of the SensitiveData |
| `severity` | `Enum<String>` | The severity of the sensitive data class. Values can be Critical, High, Medium, Low, or Info. Values: Info, Low, Medium, High, Critical. |
| `dataCategory` | `String` | dataCategory of the SensitiveData |

**Relationships:** `childrenSensitiveData`, `parentSensitiveData`, `virtParentSensitiveData`

See [`relationships.md`](relationships.md#sensitivedata) for edge labels, direction and destination entities.


## Identity

### CloudGroup

- **Kind:** Entity
- **Display name:** Cloud Group
- **Provider:** MultiCloud

Identity resource of type Group

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the resource. |
| `organization` | `String` | The organization of the resource. |
| `platform` | `String` | The platform of the resource. |
| `resourceId` | `String` | Id of a resource in the cloud |
| `firstSeen` | `DateTime` | The first date the resource was scanned. |
| `lastSeen` | `DateTime` | The last date the resource was scanned. |
| `createDate` | `DateTime` | The creation date of the resource. |
| `accountId` | `String` | The context id of resource (account, project, subscription, etc) |
| `lastActiveDate` | `DateTime` | The last time this resource accessed (CIEM). |
| `profilingStartTime` | `DateTime` | The time when profiling started for the resource (CIEM). |
| `permissionCriticality` | `String` | The risk category of the resource (CIEM). |

**Relationships:** `regions`, `zones`

See [`relationships.md`](relationships.md#cloudgroup) for edge labels, direction and destination entities.

### CloudPolicy

- **Kind:** Entity
- **Display name:** Cloud Policy
- **Provider:** MultiCloud

An IAM Policy defines rules and permissions for cloud IAM entities at the cloud provider tenant/organization level.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the resource. |
| `organization` | `String` | The organization of the resource. |
| `platform` | `String` | The platform of the resource. |
| `resourceId` | `String` | Id of a resource in the cloud |
| `firstSeen` | `DateTime` | The first date the resource was scanned. |
| `lastSeen` | `DateTime` | The last date the resource was scanned. |
| `createDate` | `DateTime` | The creation date of the resource. |
| `accountId` | `String` | The context id of resource (account, project, subscription, etc) |
| `lastActiveDate` | `DateTime` | The last time this resource accessed (CIEM). |
| `profilingStartTime` | `DateTime` | The time when profiling started for the resource (CIEM). |
| `permissionCriticality` | `String` | The risk category of the resource (CIEM). |

**Relationships:** `regions`, `zones`, `failedControls`

See [`relationships.md`](relationships.md#cloudpolicy) for edge labels, direction and destination entities.

### CloudRole

- **Kind:** Entity
- **Display name:** Cloud Role
- **Provider:** MultiCloud

Identity resource of type Role

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the resource. |
| `organization` | `String` | The organization of the resource. |
| `platform` | `String` | The platform of the resource. |
| `resourceId` | `String` | Id of a resource in the cloud |
| `firstSeen` | `DateTime` | The first date the resource was scanned. |
| `lastSeen` | `DateTime` | The last date the resource was scanned. |
| `createDate` | `DateTime` | The creation date of the resource. |
| `accountId` | `String` | The context id of resource (account, project, subscription, etc) |
| `permissionCriticality` | `String` | The risk category of the resource (CIEM). |
| `profilingStartTime` | `DateTime` | The time when profiling started for the resource (CIEM). |
| `isAdmin` | `Boolean` | Whether the role is an admin. |
| `isInactive` | `Boolean` | Whether the role is inactive. |
| `hasIAMRiskyPermissions` | `Boolean` | Whether the user has IAM risky permissions. |
| `hasEC2RiskyPermissions` | `Boolean` | Whether the user has EC2 risky permissions. |
| `hasS3RiskyPermissions` | `Boolean` | Whether the user has S3 risky permissions. |
| `hasLambdaRiskyPermissions` | `Boolean` | Whether the user has Lambda risky permissions. |
| `hasRDSRiskyPermissions` | `Boolean` | Whether the user has RDS risky permissions. |

**Relationships:** `regions`, `cloudResources`, `zones`

See [`relationships.md`](relationships.md#cloudrole) for edge labels, direction and destination entities.

### CloudServiceIdentity

- **Kind:** Entity
- **Display name:** Cloud Service Identity
- **Provider:** MultiCloud

A Service Identity represents a cloud-based identity used by services at the cloud provider tenant/organization level.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the resource. |
| `organization` | `String` | The organization of the resource. |
| `platform` | `String` | The platform of the resource. |
| `resourceId` | `String` | Id of a resource in the cloud |
| `firstSeen` | `DateTime` | The first date the resource was scanned. |
| `lastSeen` | `DateTime` | The last date the resource was scanned. |
| `createDate` | `DateTime` | The creation date of the resource. |
| `accountId` | `String` | The context id of resource (account, project, subscription, etc) |
| `permissionCriticality` | `String` | The risk category of the resource (CIEM). |
| `unusedPermissionCriticality` | `String` | The actionable risk category of the resource (CIEM). |

**Relationships:** `regions`, `zones`

See [`relationships.md`](relationships.md#cloudserviceidentity) for edge labels, direction and destination entities.

### CloudUser

- **Kind:** Entity
- **Display name:** Cloud User
- **Provider:** MultiCloud

Identity resource of type User

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the resource. |
| `organization` | `String` | The organization of the resource. |
| `platform` | `String` | The platform of the resource. |
| `resourceId` | `String` | Id of a resource in the cloud |
| `firstSeen` | `DateTime` | The first date the resource was scanned. |
| `lastSeen` | `DateTime` | The last date the resource was scanned. |
| `createDate` | `DateTime` | The creation date of the resource. |
| `accountId` | `String` | The context id of resource (account, project, subscription, etc) |
| `profilingStartTime` | `DateTime` | The time when profiling started for the resource (CIEM). |
| `permissionCriticality` | `String` | The risk category of the resource (CIEM). |
| `isAdmin` | `Boolean` | Whether the user is an admin. |
| `hasNoMFA` | `Boolean` | Whether the user has no MFA enabled. |
| `isCompromised` | `Boolean` | Whether the user is compromised. |
| `isPotentiallyCompromised` | `Boolean` | Whether the user is potentially compromised. |
| `isInactive` | `Boolean` | Whether the user is inactive. |
| `hasAccessKeysNotRotated` | `Boolean` | Whether the user has an access keys that have not been rotated. |
| `hasIAMRiskyPermissions` | `Boolean` | Whether the user has IAM risky permissions. |
| `hasEC2RiskyPermissions` | `Boolean` | Whether the user has EC2 risky permissions. |
| `hasS3RiskyPermissions` | `Boolean` | Whether the user has S3 risky permissions. |
| `hasLambdaRiskyPermissions` | `Boolean` | Whether the user has Lambda risky permissions. |
| `hasRDSRiskyPermissions` | `Boolean` | Whether the user has RDS risky permissions. |

**Relationships:** `regions`, `zones`, `acceptedControls`, `failedControls`, `runtimeEvents`

See [`relationships.md`](relationships.md#clouduser) for edge labels, direction and destination entities.

### IAMInstanceProfile

- **Kind:** Entity
- **Display name:** IAM Instance Profile
- **Provider:** AWS

An IAM Instance Profile represents a container for IAM roles assigned to EC2 instances.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `id` | `String` |  |
| `name` | `String` | The name of the instance profile. |
| `type` | `String` | The type of the instance profile. |
| `accountId` | `String` | The account ID of the instance profile. |
| `arn` | `String` | The ARN of the instance profile. |
| `location` | `String` | The location of the instance profile. |
| `lastModified` | `DateTime` |  |

**Relationships:** `regions`, `iamRoles`

See [`relationships.md`](relationships.md#iaminstanceprofile) for edge labels, direction and destination entities.


## Kubernetes

### GitKubeWorkload

- **Kind:** Entity
- **Display name:** Git Kubernetes Workload
- **Provider:** Git

A Kubernetes Workload represents an application or process running in Kubernetes.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastSeen` | `DateTime` | The last date the resource was scanned. |
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the workload. |
| `namespaceName` | `String` | The name of the namespace. |
| `platform` | `String` | The platform of the workload. |
| `repositoryName` | `String` | The name of the repository. |
| `sourceType` | `String` | The source type of the workload, like Helm, YAML, or Terraform. |
| `category` | `String` | The category of the workload (Like Compute). |
| `sourcePath` | `String` | The source path of the workload configuration, like /path/to/file.yaml. |
| `sourceURL` | `String` | The source URL of the workload. |
| `type` | `String` | The type of the workload. |

**Relationships:** `failedControls`, `acceptedControls`, `zones`

See [`relationships.md`](relationships.md#gitkubeworkload) for edge labels, direction and destination entities.

### KubeCluster

- **Kind:** Entity
- **Display name:** Kubernetes Cluster
- **Provider:** Kubernetes

A Kubernetes Cluster represents a set of nodes running containerized workloads.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the cluster. |
| `platform` | `String` | The platform of the cluster. |
| `type` | `String` | The type of the cluster. |

**Relationships:** `zones`, `vrtKubeNamespaces`, `vrtKubeNodes`, `acceptedControls`, `failedControls`, `regions`, `vrtRuntimeEvents`

See [`relationships.md`](relationships.md#kubecluster) for edge labels, direction and destination entities.

### KubeIdentity

- **Kind:** Entity
- **Display name:** Kubernetes Identity
- **Provider:** Kubernetes

A Kubernetes Identity represents a user or service account within a Kubernetes cluster.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `category` | `String` | The category of the identity. |
| `clusterName` | `String` | The name of the cluster. |
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the identity. |
| `namespaceName` | `String` | The name of the namespace. |
| `platform` | `String` | The platform of the identity. |
| `type` | `String` | The type of the identity. |
| `version` | `String` | The version of the identity. |

**Relationships:** `zones`, `namespaces`, `failedControls`, `acceptedControls`

See [`relationships.md`](relationships.md#kubeidentity) for edge labels, direction and destination entities.

### KubeIngress

- **Kind:** Entity
- **Display name:** Kubernetes Ingress
- **Provider:** Kubernetes

A Kubernetes Ingress represents an API object that manages external access to services.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `clusterName` | `String` | The name of the cluster. |
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the ingress. |
| `namespace` | `String` | The namespace of the ingress. |
| `type` | `String` | The type of the ingress. |

**Relationships:** `kubeNamespaces`, `kubeServices`, `aiPackages`

See [`relationships.md`](relationships.md#kubeingress) for edge labels, direction and destination entities.

### KubeNode

- **Kind:** Entity
- **Display name:** Kubernetes Node
- **Provider:** Kubernetes

A KubeNode represents a worker node in a Kubernetes cluster.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `category` | `String` | The category of the node. |
| `clusterName` | `String` | The name of the cluster. |
| `distribution` | `String` |  |
| `externalDNS` | `String` | The external DNS of the node. |
| `isMaster` | `Boolean` | Whether the node is a master node. |
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the node. |
| `operatingSystem` | `String` | The operating system of the node. |
| `osImage` | `String` | The OS image of the node. |
| `platform` | `String` | The platform of the node. |
| `type` | `String` | The type of the node. |
| `version` | `String` | The version of the node. |

**Relationships:** `packages`, `sbomComponents`, `applications`, `vulnerabilities`, `zones`, `kubeClusters`, `deployedOnCloudResource`, `regions`, `vrtThreats`

See [`relationships.md`](relationships.md#kubenode) for edge labels, direction and destination entities.

### KubeResource

- **Kind:** Entity
- **Display name:** Kubernetes Resource
- **Provider:** Kubernetes

A Kubernetes Resource represents an entity managed within a Kubernetes cluster.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `accountId` | `String` |  |
| `category` | `String` |  |
| `clusterName` | `String` |  |
| `distribution` | `String` |  |
| `isExposed` | `Boolean` | Whether the resource is exposed. |
| `lastModified` | `DateTime` |  |
| `lastSeen` | `DateTime` |  |
| `name` | `String` |  |
| `namespaceName` | `String` |  |
| `platform` | `String` |  |
| `technicalType` | `String` |  |
| `type` | `String` |  |
| `version` | `String` |  |
| `createdAt` | `DateTime` |  |

**Relationships:** `zones`, `kubeNamespaces`, `containers`, `acceptedControls`, `failedControls`, `passedControls`, `vrtRuntimeEvents`, `vulnerabilities`, `packages`, `sbomComponents`, `applications`

See [`relationships.md`](relationships.md#kuberesource) for edge labels, direction and destination entities.

### KubeService

- **Kind:** Entity
- **Display name:** Kubernetes Service
- **Provider:** Kubernetes

A Kubernetes Service represents a logical abstraction of a group of pods.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `clusterName` | `String` | The name of the cluster. |
| `lastModified` | `DateTime` |  |
| `name` | `String` | The name of the service. |
| `namespace` | `String` | The namespace of the service. |
| `type` | `String` | The type of the service. |

**Relationships:** `vrtKubeIngress`, `kubeWorkloads`, `kubeResources`

See [`relationships.md`](relationships.md#kubeservice) for edge labels, direction and destination entities.

### KubeWorkload

- **Kind:** Entity
- **Display name:** Kubernetes Workload
- **Provider:** Kubernetes

A KubeWorkload represents a workload in a Kubernetes cluster.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `category` | `String` | The category of the workload. |
| `clusterName` | `String` | The name of the cluster. |
| `lastModified` | `DateTime` |  |
| `lastSeen` | `DateTime` |  |
| `firstSeen` | `DateTime` |  |
| `name` | `String` | The name of the workload. |
| `platform` | `String` | The platform of the workload. |
| `namespaceName` | `String` | The name of the namespace. |
| `type` | `String` | The type of the workload. |
| `version` | `String` | The version of the workload. |
| `isExposed` | `Boolean` | Whether the workload is exposed. |
| `createdAt` | `DateTime` |  |

**Relationships:** `containers`, `vulnerabilities`, `vrKubeServices`, `namespaces`, `acceptedControls`, `vrtRuntimeEvents`, `vrtThreats`, `kubeClusters`, `failedControls`, `passedControls`, `aiPackages`, `zones`, `regions`

See [`relationships.md`](relationships.md#kubeworkload) for edge labels, direction and destination entities.


## Software

### Application

- **Kind:** Entity

An Application represents a software application installed in some resource.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `info` | `String` | The information of the application. |
| `createdAt` | `DateTime` | The creation date of the application. |
| `type` | `String` | The type of the application. |
| `vendor` | `String` | The vendor of the application. |
| `name` | `String` | The name of the application. |
| `version` | `String` | The version of the application. |
| `path` | `String` | The path where the application is installed. |

**Relationships:** `vrtHosts`, `vrtImages`

See [`relationships.md`](relationships.md#application) for edge labels, direction and destination entities.

### Image

- **Kind:** Entity

An ImageManifest represents the manifest of a container image.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `imageId` | `String` | The ID of the image. |
| `manifestDigest` | `String` | The digest of the manifest. |
| `architecture` | `String` | The architecture of the image. |
| `imageReference` | `String` | The image reference (also known as a "pull string"). |
| `repository` | `String` | The repository of the image. |
| `tag` | `String` | The tag of the image. |
| `registry` | `String` | The registry of the image. |
| `platform` | `String` | The platform of the image. |
| `registryVendor` | `String` | The vendor of the registry. |
| `baseOS` | `String` | The base OS of the image. |
| `operatingSystem` | `String` | The OS of the image. |
| `scanStatus` | `String` | The vulnerability scan status of the container. |
| `endOfLifeDate` | `DateTime` | The date after which the Container Image OS version is no longer supported or receives security updates from its maintainer. |
| `endOfLifeSource` | `String` | The data provider that supplied the end-of-life information for this Container Image OS version. |
| `createdAt` | `DateTime` | The date the image was created. |
| `firstSeen` | `DateTime` |  |
| `lastModified` | `DateTime` |  |

**Relationships:** `vrtContainers`, `vrtVulnerabilities`, `packages`, `applications`, `sbomComponents`, `zones`, `vrtThreats`

See [`relationships.md`](relationships.md#image) for edge labels, direction and destination entities.

### Package

- **Kind:** Entity

A Package represents a software package installed in some resource.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `lastModified` | `DateTime` |  |
| `info` | `String` | The information of the package. |
| `createdAt` | `DateTime` | The creation date of the package. |
| `type` | `String` | The type of the package. |
| `name` | `String` | The name of the package. |
| `path` | `String` | The path where the package is installed. |
| `namespace` | `String` | The namespace of the package. |
| `version` | `String` | The version of the package. |
| `inUse` | `Boolean` | Whether the package is in use. |
| `suggestedFix` | `String` | The suggested fix for the package that fixes most of the vulnerabilities. |
| `isAI` | `Boolean` | Whether the package is an AI package. |
| `endOfLifeDate` | `DateTime` | The date after which the package version is no longer supported or receives security updates from its maintainer. |
| `endOfLifeSource` | `String` | The data provider that supplied the end-of-life information for this package version. |

**Relationships:** `containersInUse`, `hosts`, `vrtImages`, `vrtVulnerabilities`

See [`relationships.md`](relationships.md#package) for edge labels, direction and destination entities.

### SBOMComponent

- **Kind:** Entity

An SBOMComponent represents a component installed in some resource.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `info` | `String` | The information of the SBOMComponent. |
| `name` | `String` | The name of the SBOMComponent. |
| `version` | `String` | The version of the SBOMComponent. |
| `type` | `String` | The type of the SBOMComponent. |
| `path` | `String` | The path where the SBOMComponent is installed. |
| `category` | `String` | The category of the SBOMComponent. |
| `imageId` | `String` | The imageId of the component if it's an image category. |
| `lastModified` | `DateTime` |  |
| `createdAt` | `DateTime` | The creation date of the SBOMComponent. |
| `endOfLifeDate` | `DateTime` | The date after which the SBOMComponent version is no longer supported or receives security updates from its maintainer. |
| `endOfLifeSource` | `String` | The data provider that supplied the end-of-life information for this SBOMComponent version. |

**Relationships:** `vrtHosts`, `vrtImages`

See [`relationships.md`](relationships.md#sbomcomponent) for edge labels, direction and destination entities.

### ScanStatus

- **Kind:** Entity
- **Display name:** Scan Status

An event that convey information regarding the vulnerability analysis status of resource.

**Fields:**

| Name | Type | Description |
|------|------|-------------|
| `status` | `String` | The type of the scan event. |
| `code` | `BigInt` | The code of the scan event. |
| `message` | `String` | The message of the scan event. |
| `sourceComponent` | `String` | The source client of the scan event. |
| `sourceVersion` | `String` | The source client version of the scan event. |
| `sourceFeature` | `String` | The source feature of the scan event. |
| `scanType` | `String` | The type of the scan. |
| `imageReference` | `String` | The pull string of the scanned image. |
| `imageId` | `String` | The image ID of the scanned image. |
| `imageDigest` | `String` | The image digest of the scanned image. |
| `imagePlatform` | `String` | The platform of the scanned image. |
| `imageRegistry` | `String` | The registry of the scanned image. |
| `imageRepository` | `String` | The repository of the scanned image. |
| `imageVendor` | `String` | The vendor of the scanned image. |
| `kubeCluster` | `String` | The cluster of the scanned container. |
| `kubeNamespace` | `String` | The namespace of the scanned container. |
| `kubeWorkload` | `String` | The workload of the scanned container. |
| `kubeNamespaceLabelProject` | `String` | The project of the scanned container. |
| `kubeWorkloadType` | `String` | The type of the scanned container. |
| `kubeNodeName` | `String` | The node name of the scanned container. |
| `containerId` | `String` | The ID of the scanned container. |
| `containerName` | `String` | The name of the scanned container. |
| `containerRuntimeType` | `String` | The container runtime type of the scanned container. |
| `hostId` | `String` | The ID of the scanned host. |
| `hostName` | `String` | The name of the scanned host. |
| `accountId` | `String` | The account ID of the scanned host. |
| `region` | `String` | The region of the scanned host. |
| `hostPlatform` | `String` | The cloud provider of the scanned host. |
| `timestamp` | `DateTime` | The timestamp of the event. |
| `lastModified` | `DateTime` |  |
| `createdAt` | `DateTime` | The creation date of the event. |

_No public relationships._


## Storage

### AWSRDSDatabaseCluster

- **Kind:** Query
- **Display name:** RDS Database Cluster
- **Provider:** AWS
- **Alias of:** [`CloudResource`](#cloudresource)
- **Sub-query:** `MATCH CloudResource AS r WHERE r.type = "RDS Database Cluster" AND r.platform = "AWS";`

An RDS Database Cluster represents a managed relational database cluster in AWS.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `CloudResource`)* | `String` | The account ID of the resource. |
| `account` *(via `CloudResource`)* | `String` | The account of the resource. |
| `category` *(via `CloudResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `CloudResource`)* | `DateTime` |  |
| `name` *(via `CloudResource`)* | `String` | The name of the resource. |
| `organization` *(via `CloudResource`)* | `String` | The organization of the resource. |
| `platform` *(via `CloudResource`)* | `String` | The platform of the resource. |
| `location` *(via `CloudResource`)* | `String` | The location of the resource. |
| `type` *(via `CloudResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `CloudResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `CloudResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `CloudResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `CloudResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `CloudResource`)* | `DateTime` |  |
| `publicIPs` *(via `CloudResource`)* | `List<String>` |  |
| `privateIPs` *(via `CloudResource`)* | `List<String>` |  |
| `arn` *(via `CloudResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `CloudResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `CloudResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `CloudResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `CloudResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `CloudResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `CloudResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `CloudResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `CloudResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `CloudResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `CloudResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `CloudResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `CloudResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `CloudResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `CloudResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `CloudResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `CloudResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `CloudResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `CloudResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `CloudResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `CloudResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `CloudResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `CloudResource`)* | `String` |  |
| `nameLower` *(via `CloudResource`)* | `String` |  |
| `nativeId` *(via `CloudResource`)* | `String` |  |
| `resourceId` *(via `CloudResource`)* | `String` |  |
| `technicalType` *(via `CloudResource`)* | `String` |  |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages`, `azureRegions`, `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `CloudResource`)*

See [`relationships.md`](relationships.md#awsrdsdatabasecluster) for edge labels, direction and destination entities.

### AWSRDSDatabaseInstance

- **Kind:** Query
- **Display name:** RDS Database Instance
- **Provider:** AWS
- **Alias of:** [`CloudResource`](#cloudresource)
- **Sub-query:** `MATCH CloudResource AS r WHERE r.type = "RDS Database Instance" AND r.platform = "AWS";`

An RDS Database Instance represents a single managed relational database instance in AWS.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `CloudResource`)* | `String` | The account ID of the resource. |
| `account` *(via `CloudResource`)* | `String` | The account of the resource. |
| `category` *(via `CloudResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `CloudResource`)* | `DateTime` |  |
| `name` *(via `CloudResource`)* | `String` | The name of the resource. |
| `organization` *(via `CloudResource`)* | `String` | The organization of the resource. |
| `platform` *(via `CloudResource`)* | `String` | The platform of the resource. |
| `location` *(via `CloudResource`)* | `String` | The location of the resource. |
| `type` *(via `CloudResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `CloudResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `CloudResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `CloudResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `CloudResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `CloudResource`)* | `DateTime` |  |
| `publicIPs` *(via `CloudResource`)* | `List<String>` |  |
| `privateIPs` *(via `CloudResource`)* | `List<String>` |  |
| `arn` *(via `CloudResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `CloudResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `CloudResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `CloudResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `CloudResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `CloudResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `CloudResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `CloudResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `CloudResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `CloudResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `CloudResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `CloudResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `CloudResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `CloudResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `CloudResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `CloudResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `CloudResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `CloudResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `CloudResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `CloudResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `CloudResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `CloudResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `CloudResource`)* | `String` |  |
| `nameLower` *(via `CloudResource`)* | `String` |  |
| `nativeId` *(via `CloudResource`)* | `String` |  |
| `resourceId` *(via `CloudResource`)* | `String` |  |
| `technicalType` *(via `CloudResource`)* | `String` |  |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages`, `azureRegions`, `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `CloudResource`)*

See [`relationships.md`](relationships.md#awsrdsdatabaseinstance) for edge labels, direction and destination entities.

### AzureStorageAccountBlobService

- **Kind:** Query
- **Display name:** Azure Storage Account Blob Service
- **Provider:** Azure
- **Alias of:** [`CloudResource`](#cloudresource)
- **Sub-query:** `MATCH CloudResource AS r WHERE r.type = "Storage Account Blob Service" AND r.platform = "Azure";`

An Azure Storage Account Blob Service represents an object storage service in Azure.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `CloudResource`)* | `String` | The account ID of the resource. |
| `account` *(via `CloudResource`)* | `String` | The account of the resource. |
| `category` *(via `CloudResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `CloudResource`)* | `DateTime` |  |
| `name` *(via `CloudResource`)* | `String` | The name of the resource. |
| `organization` *(via `CloudResource`)* | `String` | The organization of the resource. |
| `platform` *(via `CloudResource`)* | `String` | The platform of the resource. |
| `location` *(via `CloudResource`)* | `String` | The location of the resource. |
| `type` *(via `CloudResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `CloudResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `CloudResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `CloudResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `CloudResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `CloudResource`)* | `DateTime` |  |
| `publicIPs` *(via `CloudResource`)* | `List<String>` |  |
| `privateIPs` *(via `CloudResource`)* | `List<String>` |  |
| `arn` *(via `CloudResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `CloudResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `CloudResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `CloudResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `CloudResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `CloudResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `CloudResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `CloudResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `CloudResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `CloudResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `CloudResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `CloudResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `CloudResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `CloudResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `CloudResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `CloudResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `CloudResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `CloudResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `CloudResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `CloudResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `CloudResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `CloudResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `CloudResource`)* | `String` |  |
| `nameLower` *(via `CloudResource`)* | `String` |  |
| `nativeId` *(via `CloudResource`)* | `String` |  |
| `resourceId` *(via `CloudResource`)* | `String` |  |
| `technicalType` *(via `CloudResource`)* | `String` |  |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages`, `azureRegions`, `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `CloudResource`)*

See [`relationships.md`](relationships.md#azurestorageaccountblobservice) for edge labels, direction and destination entities.

### AzureStorageAccountBlobServiceContainer

- **Kind:** Query
- **Display name:** Azure Storage Account Blob Service Container
- **Provider:** Azure
- **Alias of:** [`CloudResource`](#cloudresource)
- **Sub-query:** `MATCH CloudResource AS r WHERE r.type = "Storage Account Blob Service Container" AND r.platform = "Azure";`

An Azure Storage Account Blob Service Container holds blobs within an Azure Storage Account.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `CloudResource`)* | `String` | The account ID of the resource. |
| `account` *(via `CloudResource`)* | `String` | The account of the resource. |
| `category` *(via `CloudResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `CloudResource`)* | `DateTime` |  |
| `name` *(via `CloudResource`)* | `String` | The name of the resource. |
| `organization` *(via `CloudResource`)* | `String` | The organization of the resource. |
| `platform` *(via `CloudResource`)* | `String` | The platform of the resource. |
| `location` *(via `CloudResource`)* | `String` | The location of the resource. |
| `type` *(via `CloudResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `CloudResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `CloudResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `CloudResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `CloudResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `CloudResource`)* | `DateTime` |  |
| `publicIPs` *(via `CloudResource`)* | `List<String>` |  |
| `privateIPs` *(via `CloudResource`)* | `List<String>` |  |
| `arn` *(via `CloudResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `CloudResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `CloudResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `CloudResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `CloudResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `CloudResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `CloudResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `CloudResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `CloudResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `CloudResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `CloudResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `CloudResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `CloudResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `CloudResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `CloudResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `CloudResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `CloudResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `CloudResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `CloudResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `CloudResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `CloudResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `CloudResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `CloudResource`)* | `String` |  |
| `nameLower` *(via `CloudResource`)* | `String` |  |
| `nativeId` *(via `CloudResource`)* | `String` |  |
| `resourceId` *(via `CloudResource`)* | `String` |  |
| `technicalType` *(via `CloudResource`)* | `String` |  |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages`, `azureRegions`, `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `CloudResource`)*

See [`relationships.md`](relationships.md#azurestorageaccountblobservicecontainer) for edge labels, direction and destination entities.

### GCPCloudStorageBucket

- **Kind:** Query
- **Display name:** GCP Cloud Storage Bucket
- **Provider:** GCP
- **Alias of:** [`CloudResource`](#cloudresource)
- **Sub-query:** `MATCH CloudResource AS r WHERE r.type = "Cloud Storage Bucket" AND r.platform = "GCP";`

A GCP Cloud Storage Bucket represents an object storage container in Google Cloud.

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `CloudResource`)* | `String` | The account ID of the resource. |
| `account` *(via `CloudResource`)* | `String` | The account of the resource. |
| `category` *(via `CloudResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `CloudResource`)* | `DateTime` |  |
| `name` *(via `CloudResource`)* | `String` | The name of the resource. |
| `organization` *(via `CloudResource`)* | `String` | The organization of the resource. |
| `platform` *(via `CloudResource`)* | `String` | The platform of the resource. |
| `location` *(via `CloudResource`)* | `String` | The location of the resource. |
| `type` *(via `CloudResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `CloudResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `CloudResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `CloudResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `CloudResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `CloudResource`)* | `DateTime` |  |
| `publicIPs` *(via `CloudResource`)* | `List<String>` |  |
| `privateIPs` *(via `CloudResource`)* | `List<String>` |  |
| `arn` *(via `CloudResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `CloudResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `CloudResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `CloudResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `CloudResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `CloudResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `CloudResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `CloudResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `CloudResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `CloudResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `CloudResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `CloudResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `CloudResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `CloudResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `CloudResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `CloudResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `CloudResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `CloudResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `CloudResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `CloudResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `CloudResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `CloudResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `CloudResource`)* | `String` |  |
| `nameLower` *(via `CloudResource`)* | `String` |  |
| `nativeId` *(via `CloudResource`)* | `String` |  |
| `resourceId` *(via `CloudResource`)* | `String` |  |
| `technicalType` *(via `CloudResource`)* | `String` |  |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages`, `azureRegions`, `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `CloudResource`)*

See [`relationships.md`](relationships.md#gcpcloudstoragebucket) for edge labels, direction and destination entities.

### S3Bucket

- **Kind:** Query
- **Display name:** S3 Bucket
- **Provider:** AWS
- **Alias of:** [`CloudResource`](#cloudresource)
- **Sub-query:** `MATCH CloudResource AS r WHERE r.type = "S3 Bucket" AND r.platform = "AWS";`

An S3 Bucket represents an object storage container in AWS Simple Storage Service (S3).

**Fields:**

> Fields tagged with `via X` are inherited from the backing entity `X`.

| Name | Type | Description |
|------|------|-------------|
| `accountId` *(via `CloudResource`)* | `String` | The account ID of the resource. |
| `account` *(via `CloudResource`)* | `String` | The account of the resource. |
| `category` *(via `CloudResource`)* | `String` | The category of the resource. |
| `lastModified` *(via `CloudResource`)* | `DateTime` |  |
| `name` *(via `CloudResource`)* | `String` | The name of the resource. |
| `organization` *(via `CloudResource`)* | `String` | The organization of the resource. |
| `platform` *(via `CloudResource`)* | `String` | The platform of the resource. |
| `location` *(via `CloudResource`)* | `String` | The location of the resource. |
| `type` *(via `CloudResource`)* | `String` | The type of the resource. |
| `isExposed` *(via `CloudResource`)* | `Boolean` | Whether the resource is exposed. |
| `firstSeen` *(via `CloudResource`)* | `DateTime` | The first date the resource was scanned. |
| `lastSeen` *(via `CloudResource`)* | `DateTime` | The last date the resource was scanned. |
| `hostname` *(via `CloudResource`)* | `String` | The customer hostname of the resource. |
| `createdAt` *(via `CloudResource`)* | `DateTime` |  |
| `publicIPs` *(via `CloudResource`)* | `List<String>` |  |
| `privateIPs` *(via `CloudResource`)* | `List<String>` |  |
| `arn` *(via `CloudResource`)* | `String` | The ARN of the resource. |
| `taskDefinitionArn` *(via `CloudResource`)* | `String` | The task definition ARN of the resource. |
| `taskDefinitionFamily` *(via `CloudResource`)* | `String` | The task definition family of the resource. |
| `subscriptionId` *(via `CloudResource`)* | `String` | The subscription ID of the resource. |
| `status` *(via `CloudResource`)* | `String` | The operational status of the resource (used by Container Apps, Container Instances, and Functions to indicate running state, health, or availability). |
| `provisioningStatus` *(via `CloudResource`)* | `String` | The provisioning status of the resource during deployment or configuration changes (used by Container App Jobs and Container Instances to track deployment progress). |
| `environmentId` *(via `CloudResource`)* | `String` | The unique identifier of the Container Apps environment that hosts the resource (used by Container Apps and Container App Jobs for environment association). |
| `revisionMode` *(via `CloudResource`)* | `String` | The revision management mode for Container Apps, determining how traffic is distributed across application revisions (single or multiple). |
| `revisionName` *(via `CloudResource`)* | `String` | The name of the specific revision of the Container App, used for version tracking and traffic routing. |
| `sku` *(via `CloudResource`)* | `String` | The pricing tier or service level of the resource, defining compute and feature capabilities (used by Container Instances). |
| `hostingType` *(via `CloudResource`)* | `String` | The hosting model or deployment type for Azure Functions, indicating the execution environment and scaling behavior. |
| `publishingModel` *(via `CloudResource`)* | `String` | The deployment and publishing method for Azure Functions, specifying how code is delivered and updated. |
| `runtimeStack` *(via `CloudResource`)* | `String` | The runtime environment and language stack configuration for Azure Functions, defining the execution platform and supported languages. |
| `projectId` *(via `CloudResource`)* | `String` | The project ID of the resource. |
| `createDate` *(via `CloudResource`)* | `DateTime` | The creation date of the resource. |
| `startLineNumber` *(via `CloudResource`)* | `BigInt` | The start line number of the vulnerability in the source code file. |
| `endLineNumber` *(via `CloudResource`)* | `BigInt` | The end line number of the vulnerability in the source code file. |
| `fileUrl` *(via `CloudResource`)* | `String` | The URL of the source code file where the vulnerability is located. |
| `packageName` *(via `CloudResource`)* | `String` | The name of the package that has the vulnerability. |
| `packageVersion` *(via `CloudResource`)* | `String` | The version of the package that has the vulnerability. |
| `packageManager` *(via `CloudResource`)* | `String` | The package manager of the package that has the vulnerability. |
| `reachability` *(via `CloudResource`)* | `String` | The reachability of the vulnerability. |
| `categoryV2` *(via `CloudResource`)* | `String` |  |
| `nameLower` *(via `CloudResource`)* | `String` |  |
| `nativeId` *(via `CloudResource`)* | `String` |  |
| `resourceId` *(via `CloudResource`)* | `String` |  |
| `technicalType` *(via `CloudResource`)* | `String` |  |

**Relationships:** `packages`, `applications`, `vulnerabilities`, `vrtPackages`, `zones`, `vrtHasKubeNode`, `vrtRunsContainer`, `iamInstanceProfiles`, `vrtRuntimeEvents`, `vrtThreats`, `vrtMalwareFindings`, `sensitiveData`, `exposedCloudResources`, `sbomComponents`, `acceptedControls`, `failedControls`, `regions`, `aiPackages`, `azureRegions`, `acceptsControl`, `passesControl`, `violatesControl`, `inZone` *(via `CloudResource`)*

See [`relationships.md`](relationships.md#s3bucket) for edge labels, direction and destination entities.


