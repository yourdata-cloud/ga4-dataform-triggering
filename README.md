# GA4 Dataform Triggering

This is a free **Terraform configuration** to deploy an **event-driven logging pipeline** on Google Cloud, **based on the GA4 raw data export to BigQuery**, and aimed to run your **Dataform worflow** involved with that.
This utility creates everything you need to programmatically run your Dataform model on every daily GA4 raw data update.

It automatically deploys a Node.js **Cloud Run Function** triggered by a **Pub/Sub** topic. This topic is fed by a **Logging Sink** that filters your project's logs based on the GA4 export.\
You just need to specify your **GA4 property and Dataform IDs as Terraform variables** at the application stage (when you call terrafom apply).\
The Cloud Function's source code (from the `src/` directory) is automatically zipped, uploaded to a GCS bucket, and deployed.

## Architecture

Terraform will enable all the required GCP APIs and it will deploy the following resources:

1.  **Logging Sink**: A project-level sink that captures logs matching the GA4 export to BigQuery.
2.  **Pub/Sub Topic**: The destination for the logging sink and Cloud Function.
3.  **GCS Bucket**: A bucket created to store the zipped source code for the function.
4.  **Cloud Run Function**: A Node.js (v22) function deployed from the source code in the `src/` directory.
    * It has dynamic environment variables to match your Dataform repository, region and workspace (which you define as variables at terraform apply stage - see below).
    * It runs Dataform API v1
    * It compiles your Dataform workflow incrementally (in case you use incremental tables) with dependencies active. If you need tags, for now you can uncomment the compilation parameter in src/index.js.
    * It dynamically makes the "table_date" raw format of GA4 data (like "events_20251014") available as Dataform variable ("GA4_TABLE"), that you can reference for incremental logic in Dataform.
    * The function is triggered by an EventArc event automatically subscribed to the created Pub/Sub topic (with every new log about the daily GA4 updates).
5.  **IAM & Service Accounts**: All necessary service accounts and IAM permissions are created and managed:
    * A runtime SA for the Cloud Function.
    * Permissions for the Logging Sink to publish to the topic.
    * Permissions for Cloud Build to deploy the function.

## Prerequisites (GCP native)

1.   Before you begin, ensure you have a Google Cloud project with billing enabled.
2.   A Dataform workflow based on Google Analytics (GA4) raw data, that you want to automatically run everytime GA4 updates data in BigQuery.

---

## Setup

### Clone this repository

In your cloud shell, run the following:

```bash
git clone https://github.com/yourdata-cloud/ga4-dataform-triggering
cd ga4-dataform-triggering
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
** Nothing will happen to your Dataform model, 'terraform destroy' just removes the pipeline **

You can also hardcode the same terraform variables into **terraform.tfvars**, which is included in this project (but fully commented and inactive).

The GCS bucket, and the ZIP file included, will stay after the deployment. This is an expected backup of the Cloud Run Function source code.
