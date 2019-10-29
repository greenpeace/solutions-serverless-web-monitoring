.PHONY: alerter analyzer tests tracer

all:
	$(MAKE) -j tracer analyze alerter

tracer:
	gcloud functions deploy trace \
		--trigger-http \
		--runtime nodejs8 \
		--memory 1GB \
		--source tracer \
		--env-vars-file env-vars.yaml \
		--quiet
	gcloud beta functions remove-iam-policy-binding trace \
		--member allUsers \
		--role roles/cloudfunctions.invoker

analyze:
	gcloud functions deploy analyze \
		--trigger-resource gs://$(METRICS_BUCKET) \
		--trigger-event google.storage.object.finalize \
		--runtime python37 \
		--source analyzer \
		--env-vars-file env-vars.yaml

alerter:
	gcloud functions deploy alert \
		--trigger-event providers/cloud.firestore/eventTypes/document.create \
		--trigger-resource "projects/$(PROJECT)/databases/(default)/documents/page-metrics/{any}" \
		--runtime python37 \
		--source alerter \
		--env-vars-file env-vars.yaml \
		--entry-point generate_alert
