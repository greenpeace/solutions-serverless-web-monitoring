.EXPORT_ALL_VARIABLES:

TARGET_URL ?= https://www.greenpeace.org/international/

SCHEDULE_NAME ?= traceWithRetryDefault

SCHEDULE_CRON ?= 0 3 * * *

PROJECT ?= planet-4-151612

PROJECT_NUM ?= $(shell gcloud projects list \
		--filter="$(PROJECT)" \
		--format="value(PROJECT_NUMBER)")

REGION ?= us-central1

METRICS_BUCKET ?= page-metrics-$PROJECT_NUM

ALLOWED_HOSTS ?= www\.greenpeace\.org|www\.greenpeace\.ch

METRICS_COLLECTION ?= page-metrics

# =============================================================================

all: clean config bucket functions/env-vars.yaml functions

list:
	gcloud functions list
	gcloud scheduler jobs list

# =============================================================================

clean:
	rm -f functions/env-vars.yaml

config:
	gcloud config set functions/region $(REGION)

bucket:
	-gsutil mb -l $(REGION) gs://$(METRICS_BUCKET)

functions/env-vars.yaml:
	envsubst < functions/env-vars.yaml.in > functions/env-vars.yaml

firestore:
	$(warning This step is not automated!)
	$(warning See: 'https://cloud.google.com/solutions/serverless-web-performance-monitoring-using-cloud-functions#create_a_cloud_firestore_collection')

pubsub:
	gcloud pubsub topics create performance-alerts
	gcloud pubsub subscriptions create performance-alerts-sub \
    --topic performance-alerts

# =============================================================================

.PHONY: functions
functions:
	$(MAKE) -C $@

# =============================================================================

service-account:
	-gcloud iam service-accounts create tracer-job-sa
	gcloud beta functions add-iam-policy-binding trace \
		--role roles/cloudfunctions.invoker \
		--member "serviceAccount:tracer-job-sa@$(PROJECT).iam.gserviceaccount.com"

schedule: service-account
	gcloud scheduler jobs create http $(SCHEDULE_NAME) \
    --uri="https://$(REGION)-$(PROJECT).cloudfunctions.net/trace" \
    --http-method=POST \
    --message-body="{\"url\":\"$(TARGET_URL)\"}" \
    --headers="Content-Type=application/json" \
    --oidc-service-account-email="tracer-job-sa@$(PROJECT).iam.gserviceaccount.com" \
    --schedule="$(SCHEDULE_CRON)" \
    --time-zone="UTC" \
    --max-retry-attempts=3 \
    --min-backoff=30s

# =============================================================================
