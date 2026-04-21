# demo-infra — Terraform + Helm

Loaded by the claude-toolkit when Claude Code runs inside the `infra` project.

## Stack

- **Infrastructure-as-code:** Terraform (>=1.7)
- **Kubernetes manifests:** Helm charts
- **Deployment model:** GitOps (Argo CD syncs from `main`)
- **Base branch:** `main`
- **Jira prefix:** `INF-`

## Commands

| Task              | Command                                         |
|-------------------|-------------------------------------------------|
| Init              | `terraform -chdir=envs/{env} init`              |
| Plan              | `terraform -chdir=envs/{env} plan`              |
| Apply             | `terraform -chdir=envs/{env} apply`             |
| Format            | `terraform fmt -recursive`                      |
| Validate          | `terraform -chdir=envs/{env} validate`          |
| Lint Helm         | `helm lint charts/*`                            |
| Render Helm       | `helm template charts/{chart} -f values.yaml`   |
| All checks        | `terraform fmt -check -recursive && helm lint charts/*` |

**Run `terraform fmt -check -recursive && helm lint charts/*` before
committing.** CI also runs `terraform validate` per environment.

## Conventions

- Environments live in `envs/{dev,staging,prod}/` — one state file per env
- Reusable modules in `modules/{name}/`
- Helm charts in `charts/{name}/` — values per-env in `values-{env}.yaml`
- GitOps: merging to `main` triggers Argo CD sync automatically
- Secrets never touch this repo — use external-secrets-operator pointed at
  the secret store

## Safety rules

- **Never** apply Terraform changes from your laptop in `prod` — only via CI
- **Never** commit `.tfvars` containing secrets
- **Always** review `plan` output before approving a PR — even for "trivial"
  tagging changes
- The `bash-safety` hook in this toolkit blocks `kubectl`/`helm`/`docker`
  commands targeting production contexts — don't override it
