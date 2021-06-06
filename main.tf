provider "google" {

  credentials = file("your-gcp-authenthication.json")
  project     = var.project_name
}


data "google_secret_manager_secret_version" "API_URL" {
  provider = google-beta
  secret   = "API_URL"
}


resource "google_cloud_run_service" "default" {

  for_each = toset(["us-central1", "us-east1"]) 
  // you will create two cloud run service  in the us-central1 and us-east1 regions
  //if you want,  you can add more region  ex: "us-central1", "us-east1", "europe-west1"...


  name     = "${var.service_name}-${each.value}"
  location = each.value

  metadata {
    annotations = {
      "autoscaling.knative.dev/maxScale" = "1000"
      "run.googleapis.com/client-name"   = "terraform"
      "run.googleapis.com/ingress"       = "internal-and-cloud-load-balancing" // you can use "all" if you dont use ssl load-balancer
    }
  }

  template {

    spec {
      container_concurrency = 80
      timeout_seconds       = 300

      containers {
        image = "gcr.io/your-image-name-or-link"

        ports {
          container_port = 80

        }

        env {
          name  = "API_URL"
          value = data.google_secret_manager_secret_version.API_URL
        }


        resources {
          //your container limits 
           limits   = {
                           "cpu"    = "1000m"
                           "memory" = "512Mi"
                        }
        }

      }
    }

  }
  // autogenerate_revision_name = true

  traffic {
    percent = 100
    //revision_name = autogenerate_revision_name. //optional
    latest_revision = true
  }

}

resource "google_cloud_run_service_iam_member" "member" {

  for_each = toset(["us-central1", "us-east1"])
  location = google_cloud_run_service.default[each.value].location
  project  = google_cloud_run_service.default[each.value].project
  service  = google_cloud_run_service.default[each.value].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
