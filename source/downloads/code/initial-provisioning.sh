#https://github.com/Masahigo/blog-infra

# Create the actual GCP Project
# NOTE: Replace xxxxxx with your own "DM Creation Project" id
gcloud config set project dm-creation-project-xxxxxx
gcloud builds submit 
--config ./project_creation/cloudbuild.yaml 
./project_creation

# Create managed zone
# NOTE: Replace the project parameter with your own project name
gcloud builds submit 
--config ./dns/cloudbuild.yaml ./dns 
--project=ms-devops-dude

# Had to enable App Engine using my admin account for now
# (CB Service Account would have required elevated permissions)
gcloud config set project ms-devops-dude
gcloud app create --region=europe-west3

# Custom build step for running Hexo commands
gcloud builds submit 
--config=./hexo-build-step/cloudbuild.yaml ./hexo-build-step/ 
--project=ms-devops-dude
