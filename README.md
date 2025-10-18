# GA4 Dataform Triggering

This project provides a complete **Terraform** configuration to deploy an event-driven logging pipeline on Google Cloud, based on the GA4 raw data export to BigQuery, and aimed to run your Dataform worflow involved with that.

It automatically deploys a **Node.js (v22) Cloud Run Function (v2)** that is triggered by a **Pub/Sub** topic. This topic is, in turn, fed by a **Logging Sink** that filters your project's logs based on the GA4 export. You'll need to specify your GA4 property ID as a Terraform variable at the application stage (terrafom apply).

The Cloud Function's source code (from the `src/` directory) is automatically zipped, uploaded to a GCS bucket, and deployed.

## Architecture

Terraform will deploy the following resources:

1.  **Logging Sink**: A project-level sink that captures logs matching the GA4 export to BigQuery.
2.  **Pub/Sub Topic**: The destination for the logging sink.
3.  **GCS Bucket**: A temporary bucket created to store the zipped source code for the function.
4.  **Cloud Function (v2)**: A Node.js function deployed from the source code in the `src/` directory. It is configured with dynamic environment variables to match your Dataform repository, region and workspace.
5.  **Pub/Sub Subscription**: A push subscription that connects the topic to the Cloud Function, triggering it on every new log message.
6.  **IAM & Service Accounts**: All necessary service accounts and IAM permissions are created and managed:
    * A runtime SA for the Cloud Function.
    * An invoker SA for the Pub/Sub subscription.
    * Permissions for the Logging Sink to publish to the topic.
    * Permissions for Cloud Build to deploy the function.

## Prerequisites (GCP environment, no local)

Before you begin, ensure you have a Google Cloud project with billing enabled.

---

## Setup

### Clone this repository

In your GCP CLI, run the following:

```bash
git clone https://github.com/yourdata-cloud/ga4-dataform-triggering
cd <ga4-dataform-triggering
```

### Initialize Terraform

```
terraform init
```

### Apply Terraform with your variables

```
terraform apply \
   -var="project_id=<your-project-id>"
   -var="region=<where-all-the-resources-will-be-created>"
   -var="log_filter_string=<your-GA4-property-id>"
   -var="env_var_2=<your-dataform-repository-region"
   -var="env_var_3=<your-dataform-repository>"
   -var="env_var_4=<your-dataform-workspace>"
```

If you want to destroy all the resources deployed, just run (you need to reset the same variables):

```
terraform destroy \
   -var="project_id=<your-project-id>"
   -var="region=<where-all-the-resources-will-be-created>"
   -var="log_filter_string=<your-GA4-property-id>"
   -var="env_var_2=<your-dataform-repository-region"
   -var="env_var_3=<your-dataform-repository>"
   -var="env_var_4=<your-dataform-workspace>"
```

Alternatively, you can hardcode your variables values into the **terraform.tfvars file**, included in the project (but commented).

The GCS bucket, and the ZIP file included, will stay after the deployment. This is expected to leave a backup of the Cloud Run Function source code.

Enjoy it and don't hesitate to contact us in case of need -> **support@your-data.cloud**
