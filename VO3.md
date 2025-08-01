Vertex AI itself is offered as a managed Google API/console service; the Terraform only provisions resources (Workbench VM, Index, etc.) inside a private-only VPC. Access patterns therefore fall into two buckets:

1. Vertex AI control plane (datasets, models, endpoints, Index)
- Google hosts the REST/GRPC APIs at aiplatform.googleapis.com and other Google-owned domains.
- Because your subnet sets private_ip_google_access = true, any VM or Workbench notebook inside the VPC can reach those APIs over Google’s private backbone without a public IP.
- Users outside the VPC reach Vertex AI via the normal public HTTPS endpoints; access is gated purely by IAM (roles like roles/aiplatform.user). No special networking is required—only IAM.

2. Vertex AI Workbench instance (JupyterLab)
- The instance was created with no_public_ip = true; Google automatically sets up an IAP-proxied HTTPS URL (https://DOMAIN/notebooks/…).
- To open it:
Give the user the IAM role roles/notebooks.admin or roles/notebooks.viewer plus roles/iap.tunnelResourceAccessor.
  - In the Cloud Console → Vertex AI → Workbench → Instances, click “Open JupyterLab”.
  - Google Identity-Aware Proxy handles the tunnel, so the user’s browser connects through Google’s front end; no inbound firewall rule is needed.

- CLI alternative:
```bash
gcloud compute ssh --tunnel-through-iap \
      --project=PROJECT_ID --zone=ZONE \
      INSTANCE_NAME -- -L 8080:localhost:8080
```
then browse to http://localhost:8080.

3. Calling deployed Vertex AI endpoints from on-prem or the internet
- Endpoints are managed, Google-hosted HTTPS URLs (e.g., https://REGION-aiplatform.googleapis.com/v1/projects/...).
- Clients just need outbound internet or Private Service Connect and must possess an OAuth token with the right IAM role (roles/aiplatform.invoker).

In short:

- Workbench UI – via Google-managed IAP tunnel; user needs the right IAM roles.
- Vertex AI APIs/Endpoints – standard Google APIs; control is IAM, not network.
- No ports are exposed directly from the VPC to the internet.