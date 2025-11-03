terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.3"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "random_id" "sa_suffix" {
  byte_length = 4
}

# Enable required services API:
resource "google_project_service" "apis" {
  for_each = toset([
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudfunctions.googleapis.com",
    "dataform.googleapis.com",
    "artifactregistry.googleapis.com", 
    "eventarc.googleapis.com",
    "run.googleapis.com",
    "pubsub.googleapis.com",
    "logging.googleapis.com",
    "storage.googleapis.com",
    "cloudbuild.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

# Sources preparation:

# Generate bucket id:
resource "random_id" "bucket_prefix" {
  byte_length = 8
}

# Generate bucket:
resource "google_storage_bucket" "source_bucket" {
  name     = "${var.project_id}-run-source-${random_id.bucket_prefix.hex}"
  location = var.region
  depends_on = [google_project_service.apis]
}

# Zip src:
data "archive_file" "source_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "/tmp/source-${random_id.bucket_prefix.hex}.zip"
}

# Upload zip to the bucket:
resource "google_storage_bucket_object" "source_zip_object" {
  name   = "source.zip"
  bucket = google_storage_bucket.source_bucket.name
  source = data.archive_file.source_zip.output_path
}

# TOPIC & SINK LOGGING

# Pub/Sub topic creation:
resource "google_pubsub_topic" "log_topic" {
  name = "ga4-dataform-run"
  depends_on = [google_project_service.apis]
}

# Logging sink creation:
resource "google_logging_project_sink" "log_sink" {
  name        = "ga4-dataform-sink"
  destination = "pubsub.googleapis.com/${google_pubsub_topic.log_topic.id}"
  
  # Dynamic filtering:
  filter      = "protoPayload.methodName=\"jobservice.jobcompleted\" AND protoPayload.authenticationInfo.principalEmail=\"firebase-measurement@system.gserviceaccount.com\" AND protoPayload.serviceData.jobCompletedEvent.job.jobConfiguration.load.destinationTable.datasetId=\"analytics_${var.log_filter_string}\" AND protoPayload.serviceData.jobCompletedEvent.job.jobConfiguration.load.destinationTable.tableId=~\"^events_\\d+\""

  depends_on = [google_project_service.apis]
}

# Time to wait:
resource "time_sleep" "wait_for_sink_identity" {
  triggers = {
    sink_id = google_logging_project_sink.log_sink.id
  }

  create_duration = "30s"
}

# Authorize the sink to publish:
resource "google_pubsub_topic_iam_member" "logging_publisher" {
  topic  = google_pubsub_topic.log_topic.name
  role   = "roles/pubsub.publisher"
  member = google_logging_project_sink.log_sink.writer_identity

  depends_on = [
    time_sleep.wait_for_sink_identity
  ]
}

# CLOUD RUN SERVICE

# Cloud Run service account definition:
resource "google_service_account" "run_runtime_sa" {
  account_id   = "ga4-dataform-run-sa-${random_id.sa_suffix.hex}"
  display_name = "GA4 Dataform Run SA"

  depends_on = [
    google_project_service.apis["iam.googleapis.com"]
  ]
}

# Cloud Run Function (v2):
resource "google_cloudfunctions2_function" "default" {
  name     = "ga4-dataform-run"
  location = var.region

  build_config {
    runtime = "nodejs22"
    entry_point = "runDataform"
    source {
      storage_source {
        bucket = google_storage_bucket.source_bucket.name
        object = google_storage_bucket_object.source_zip_object.name
      }
    }
  }
  
  service_config {
    max_instance_count  = 100
    min_instance_count = 0
    available_memory    = "512M"
    timeout_seconds     = 540
    max_instance_request_concurrency = 1
    available_cpu = "333m"
    environment_variables = {
        PROJECT = var.project_id
        LOCATION = var.env_var_2
        REPO = var.env_var_3
        WORKSPACE = var.env_var_4
    }
    ingress_settings = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email = "${google_service_account.run_runtime_sa.email}"
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"

    pubsub_topic   = google_pubsub_topic.log_topic.id 

    retry_policy   = "RETRY_POLICY_RETRY" 
  }
  
  
  depends_on = [
    google_storage_bucket_object.source_zip_object,
    google_project_service.apis
  ]
}

# Build permissions:
data "google_project" "project" {
  depends_on = [
    google_project_service.apis["cloudresourcemanager.googleapis.com"]
  ]
}

resource "google_project_iam_member" "dataform_editor_permission" {
  project = var.project_id
  role    = "roles/dataform.editor"
  member  = "serviceAccount:${google_service_account.run_runtime_sa.email}"
  
  depends_on = [
    google_project_service.apis["dataform.googleapis.com"],
    google_service_account.run_runtime_sa
  ]
}

resource "google_project_iam_member" "build_sa_permissions" {
  for_each = toset([
    "roles/storage.objectViewer",
    "roles/run.developer",        
    "roles/iam.serviceAccountUser"
  ])
  
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}
