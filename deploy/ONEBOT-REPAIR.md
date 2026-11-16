# OneBot reconnect repair

This patch image keeps the pinned production AstrBot base and replaces only the
OneBot adapter and its connection-safe client. It does not update the dashboard,
plugins, persistent data, or other upstream features.

Build from the committed revision:

```sh
docker build -f deploy/Dockerfile.onebot-fix -t rinrin:onebot-fix-<commit> .
```

Before deploying, run `tests/unit/test_aiocqhttp_reconnect.py` against the image.
Deploy by updating only the `astrbot` container image in the `rinrin/astrbot`
Deployment. Preserve volumes, environment, probes, service and node placement.
Record the old image before updating, wait for rollout readiness, then verify
OneBot connection, MCP tools, and a QQ mention/reply round trip.

The upstream Docker workflow is restricted to AstrBotDevs/AstrBot. The Rinrin
release workflow is documented in [k3s/README.md](k3s/README.md); once its deployment
credentials are configured, use it for full application releases. A locally imported patch image
must remain on its target node and use `imagePullPolicy: IfNotPresent`. For rollout
to another node, publish/import that exact image there first. Roll back by restoring
the previous digest-pinned image; no database migration is involved.
