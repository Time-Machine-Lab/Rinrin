# Rinrin production releases

`Rinrin Release to K3s` builds the full source and dashboard from an existing tag,
tests the image, publishes it to Docker Hub, then updates only container `astrbot`
in Deployment `rinrin/astrbot` on `https://k3s.tmlab.top`.
It replaces the node-local OneBot patch image; every release includes committed
backend changes, not just the two hotfix files.

## One-time setup

1. An administrator reviews and applies `deploy/k3s/ci-rbac.yaml` to the existing
   `rinrin` namespace. The account can patch only Deployment `astrbot` and read
   pod status in that namespace. It cannot read Secrets or pod logs, execute commands in
   pods, or modify PVCs, ingress, RBAC or other Deployments. Patching a Deployment
   still permits running replacement application code with that workload's access;
   protect production releases and the repository accordingly.
2. Issue a kubeconfig for `rinrin/rinrin-ci-deployer` with the cluster CA and API
   endpoint `https://k3s.tmlab.top`. Store the raw YAML (not base64) in the repository
   or `production` environment secret `KUBE_CONFIG`. Use the team's credential
   issuance/rotation process; expiring tokens must be renewed before expiry.
   Do not reuse Plane's namespace-scoped kubeconfig or a cluster-admin kubeconfig.
3. Make `DOCKER_USERNAME` and `DOCKER_PASSWORD` available to this repository.
   These organization secrets are already visible to Rinrin as of 2026-11-17.
   Ensure the Docker Hub repository `<DOCKER_USERNAME>/rinrin` is public, or have
   an administrator configure an existing namespace imagePullSecret for it.
   The workflow deliberately does not create registry credentials in Kubernetes.
4. Ensure GitHub-hosted runners can reach the cluster API and the public dashboard.
   Optionally require reviewers and restrict deployment refs in the GitHub
   `production` environment. Keep the `rinrin-data` PVC and current app settings.

The credentials themselves are not stored in this repository. Adding this workflow
does not create the service account or configure `KUBE_CONFIG` automatically.

## Publish

- Merge the intended changes into `master` and create a new tag, for example
  `v4.29.4-rinrin.1`, pointing to that exact commit.
- Publish a **non-prerelease GitHub Release** for the tag. Alternatively run
  `Rinrin Release to K3s` from `master` and supply the existing tag.
- Ordinary pushes, tag pushes, draft releases and prereleases do not deploy.
- The tag must match the accepted version format and belong to `master` history.
  Reusing a tag is discouraged; each run still gets a distinct Docker tag containing
  the commit, run ID and attempt. Kubernetes uses the published image digest.

The build uses the existing root Dockerfile and frozen dashboard lockfile. It runs
OneBot regression tests in the built image before publishing. A failed rollout or
dashboard check restores the exact previous image unless another actor changed it.
Application rollback does not undo data changes made by an application upgrade;
review compatibility and take a data backup before releases involving migrations.

The Deployment uses `Recreate`, so a release has a short service interruption.
After a successful run, verify an @ mention in QQ and a real MCP product query.
HTTP health alone cannot prove the model, QQ account or all plugins work.

## Manual rollback

Use the previous digest printed in the run summary:

```sh
kubectl -n rinrin set image deployment/astrbot astrbot=<previous-image>
kubectl -n rinrin rollout status deployment/astrbot --timeout=600s
```

The initial node-local `rinrin:onebot-fix-c0d6fd4` rollback image exists only on
agent-1. Later successful registry releases remove this node-local dependency.

## Validation without deploying

```sh
bash -n deploy/k3s/release.sh
bash deploy/k3s/test-release.sh
actionlint .github/workflows/rinrin-release-k3s.yml
```
