# GCP Sandbox

The configuration builds a “private‐by‐default” sandbox:

VPC/Subnet
– secure_vpc has auto_create_subnetworks = false, so only the explicitly defined private_subnet (10.10.0.0/16) exists.
– private_subnet sets private_ip_google_access = true but gives no public IPs to resources.
– Outbound internet is through a Cloud NAT resource; inbound traffic is not exposed.

Firewall
– Only one rule (allow-iap-ssh) allows inbound traffic: TCP 22 only from Google’s IAP proxy range (35.235.240.0/20) and only to instances tagged allow-iap-ssh. This still requires IAP authentication, so no open SSH to the public internet.

Compute / Workbench
– Vertex AI Workbench instance uses no_public_ip = true, so it is reachable only via the private network (plus IAP if you attach the firewall tag).

Cloud SQL
– ipv4_enabled = false and private_network points to the VPC – the instance gets a private address only.

Buckets
– public_access_prevention = "enforced" and uniform bucket-level access enabled; nothing can be made public.

Other services (Vertex AI Index, log sink, etc.) use Google managed endpoints and are reachable via authenticated APIs, not open ports.

The project’s resources are not publicly reachable. The only ingress path is IAP-proxied SSH, which still requires Google-managed authentication and originates from a fixed IP range. Everything else (SQL, Workbench, buckets) is private or API-based, so the environment is effectively isolated from the public internet.

### Security

For a sandbox (ephemeral, low-risk experimentation) the configuration is deliberately on the “secure-by-default” end of the spectrum. It is not “too much,” but some controls are stricter than what many teams use in a throw-away environment.

- No public IPs on VMs / Workbench (no_public_ip, NAT only).
- IAP-only SSH ingress rule.
- Org policies blocking service-account keys, enforcing OS Login.
- CMEK on SQL and buckets (good habit, negligible cost).
- Centralized log sink (helps incident triage).

What can be relaxed:

- CMEK-required resources – remove CMEK blocks; default Google-managed encryption is usually fine for sandboxes and removes key-management overhead.
- Deletion protection on Cloud SQL – turn off if you rebuild frequently.
- Detailed PostgreSQL logging flags – trim to essentials; they generate lots of logs.
- Strict bucket lifecycle rule (delete after 30 days) – extend or drop if data retention isn’t a concern.
- Org-level policies – if you lack org-level rights, apply project-level policies instead or omit them.

Bottom line: the current setup mirrors production-grade security and is perfectly valid—even for a sandbox—because it adds minimal runtime cost. 

## Prerequisites

- GCP Account
- Terraform
- Service Account with permissions to create projects

## Setup

1. Create a service account with permissions to create projects
2. Create a service account with permissions to create service accounts

## Usage

1. Initialize Terraform
```bash
terraform init
```

2. Plan the terraform script
```bash
terraform plan
```

3. Apply the terraform script
```bash
terraform apply
```

4. Destroy the terraform script
```bash
terraform destroy
```

## Variables

- project_id
- project_name
- project_number
- service_account_email
- service_account_key
- service_account_key_id
- service_account_key_type
- service_account_key_file
- service_account_key_file_path
- service_account_key_file_format
- billing_account_id
- billing_account_name
- billing_account_number
- billing_account_email
- billing_account_key
- billing_account_key_id
- billing_account_key_type

## Destroy VPC Connection

VPC can’t be deleted while the reserved PSC range and the VPC-peering connection exist.

Order of removal (Terraform will handle once the resources are in state):

google_sql_database_instance.private_postgres (needs fix above)
google_service_networking_connection.services_vpc_connection
google_compute_global_address.services_psc
google_compute_subnetwork.private_subnet
google_compute_network.secure_vpc

If these resources are in state, a normal terraform destroy will remove them in that order. If you removed some by hand and they’re not in state, import them or use terraform state rm to drop them from state.

### Quick path if you only want to tear everything down 

Flip deletion_protection = false and run terraform apply.

Run:

```bash
terraform destroy -target=google_service_networking_connection.services_vpc_connection
terraform destroy -target=google_sql_database_instance.private_postgres \
                  -target=google_sql_user.iam_user
```

```
gcloud compute addresses delete services-psc \
  --global \
  --project=keen-vision-467717-r4 --quiet

gcloud services vpc-peerings delete \
  --service=servicenetworking.googleapis.com \
  --network=secure-vpc \
  --project=keen-vision-467717-r4 --quiet

terraform state rm google_compute_global_address.services_psc
terraform state rm google_service_networking_connection.services_vpc_connection
```

OR

```
terraform destroy -target=google_compute_global_address.services_psc
terraform destroy -target=google_service_networking_connection.services_vpc_connection

terraform destroy -target=google_compute_subnetwork.private_subnet
terraform destroy -target=google_compute_network.secure_vpc
terraform destroy -target=google_compute_router.nat_router
terraform destroy -target=google_compute_firewall.iap_ssh
terraform destroy -target=google_compute_firewall.allow_iap_ssh
```

### To verify that the environment is completely torn down:

1. Terraform state is empty

```bash
terraform state list          # should print nothing
```

2. A full plan shows no changes

```bash
terraform plan                # should say “No changes. Your infrastructure matches the configuration.”
```

3. Double-check in GCP for stragglers (quick CLI checks):

```bash
gcloud compute networks list --filter="name=secure-vpc"
gcloud compute addresses list --filter="name=services-psc"
gcloud services vpc-peerings list --network=secure-vpc
gcloud sql instances list --filter="name~^private-postgres$"
```

All commands should return no rows.

4. Remove local cache if you like

```bash
rm -rf .terraform terraform.tfstate*   # optional, cleans local workspace
```

If those checks are clear, everything managed by Terraform (and the PSC pieces) is gone.

## Authors

Written by [sealmindset](https://github.com/sealmindset)

## License

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

