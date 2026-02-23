---
name: workbench-deployment
description: Deploy and test the workbench backend (Azure Container Apps + Neon PostgreSQL). Use when deploying or validating the workbench backend.
---

# Workbench Deployment

Deploy and test the workbench backend (Azure Container Apps + Neon PostgreSQL).

## Infrastructure

- **Compute:** Azure Container Apps (UK South)
- **Database:** Neon PostgreSQL (London)
- **Registry:** Azure Container Registry (`acrworkbenchprod`)

## CI/CD (automatic)

Merges to `main` trigger automatic deployment via `.github/workflows/deploy-workbench.yml`:
- Path triggers: `apps/workbench/backend/**`, `packages/workbench/**`, `packages/datasources/**`
- Authentication: GitHub OIDC federation (no stored secrets)
- Build: `az acr build` to Azure Container Registry
- Deploy: `az containerapp update` to Azure Container Apps
- Health gate: Waits for `/health/ready` before declaring success

## Local Docker testing

Before pushing changes that affect the backend, test locally:

```bash
# Build (from repo root)
sudo docker build -f apps/workbench/backend/Dockerfile -t workbench-api:test .

# Verify imports work
sudo docker run --rm workbench-api:test python -c "from workbench_backend.app import create_app; print('OK')"
```

## Docker pattern: uv workspaces

The backend uses `uv sync --no-editable --package workbench-backend`:
- `--no-editable` installs packages into site-packages (not .pth files with local paths)
- `--package` installs only the target package and its dependencies
- No PYTHONPATH needed — packages are properly installed

This is the production pattern for uv workspaces in Docker.

## Manual deployment

```bash
az acr build --registry acrworkbenchprod --image workbench-api:v1 --file apps/workbench/backend/Dockerfile .
az containerapp update --name workbench-api --resource-group rg-workbench-prod --image acrworkbenchprod.azurecr.io/workbench-api:v1
```
