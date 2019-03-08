from rever.logger import current_logger
from rever.main import env_main

GCLOUD_REVER_XSH = """
$ACTIVITIES = ['deploy_to_gcloud']
$PROJECT = 'rever'
$GCLOUD_PROJECT_ID = 'hello-world'
$GCLOUD_ZONE = 'us-central1-a'
$GCLOUD_CLUSTER = 'hello-world-cluster01'
$GCLOUD_DOCKER_ORG = 'hello-world-org'
$GCLOUD_DOCKER_REPO = 'hello-world-repo'
"""


GCLOUD_APP_REVER_XSH = """
$ACTIVITIES = ['deploy_to_gcloud']
$PROJECT = 'rever'
$GCLOUD_PROJECT_ID = 'hello-world'
$GCLOUD_ZONE = 'us-central1-a'
"""


def test_deploy_to_gcloud(gcloudecho, kubectlecho):
    files = [('rever.xsh', GCLOUD_REVER_XSH),
             ]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    env_main(['0.1.0'])


def test_deploy_to_gcloud_app(gcloudecho):
    files = [('rever.xsh', GCLOUD_APP_REVER_XSH),
             ]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    env_main(['0.1.0'])
