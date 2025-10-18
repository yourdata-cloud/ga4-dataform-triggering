![YourData.Cloud logo](https://img1.wsimg.com/isteam/ip/ad90bb28-f910-4fa3-9922-8f22021ce2f5/YourData%20simple%20logo%20white.png/:/rs=h:175,m)

# GA4 Dataform Triggering

This is a complete **Terraform configuration** to deploy an **event-driven logging pipeline** on Google Cloud, **based on the GA4 raw data export to BigQuery**, and aimed to run your **Dataform worflow** involved with that.
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
5.  **Pub/Sub Subscription**: A push subscription that connects the topic to the Cloud Function, triggering it on every new log message about GA4 data daily updates.
6.  **IAM & Service Accounts**: All necessary service accounts and IAM permissions are created and managed:
    * A runtime SA for the Cloud Function.
    * An invoker SA for the Pub/Sub subscription.
    * Permissions for the Logging Sink to publish to the topic.
    * Permissions for Cloud Build to deploy the function.

## Prerequisites (GCP native)

1.   Before you begin, ensure you have a Google Cloud project with billing enabled.
2.   A Dataform workflow based on Google Analytics (GA4) raw data, that you want to automatically run everytime GA4 updates data in BigQuery.\
     **Don't have any ?** Contact us (**support@your-data.cloud**) for your customized Dataform model (ecommerce, machine learning, multi-attribution and [more](https://www.linkedin.com/posts/riccardomalesani_dataform-googleanalytics-googlecloud-activity-7377315965845360640-x0iy)).

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

Thank you, and don't hesitate to contact us in case of need -> **support@your-data.cloud**
