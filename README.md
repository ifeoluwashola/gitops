# fastapi-gitops-demo

Tiny FastAPI app used to demo GitOps (ArgoCD / Flux) at DevFest.

## Repo layout

- `app/` - FastAPI source
- `Dockerfile` - builds the image
- `deploy/` - Kubernetes manifests (point ArgoCD/Flux here)
- `main` branch - source + Dockerfile
- `gitops` branch - manifests (ArgoCD points here)

## Quick local run


## Demo flow (summary)

1. Build image, push to registry (e.g. GHCR) as `ghcr.io/<USER>/gitops-demo:v1`.
2. On `gitops` branch, update `deploy/base/deployment.yaml` image tag to match pushed image.
3. ArgoCD/Flux (pointed at this repo/branch/path) will sync cluster to Git changes.
4. Make a commit bumping `"version": "v2"` in `app/main.py` and/or update manifest to show GitOps-driven rollout and rollback.


