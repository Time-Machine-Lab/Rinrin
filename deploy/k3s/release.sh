#!/usr/bin/env bash
set -euo pipefail

# Update only the existing application image. Keep PVCs, ingress and credentials.
: "${IMAGE:?A digest-pinned published image is required}"
[[ "$IMAGE" =~ @sha256:[a-f0-9]{64}$ ]]
previous=$(kubectl --request-timeout=20s -n rinrin get deployment astrbot \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="astrbot")].image}')
test -n "$previous"
printf 'Previous image: %s\nNew image: %s\n' "$previous" "$IMAGE"

rollback() {
  code=$?
  trap - ERR
  echo '::error::Deployment verification failed; restoring previous image.'
  kubectl --request-timeout=20s -n rinrin get pods -l app=astrbot -o wide || true
  # This repository is public: never copy private QQ conversations into CI logs.
  # Do not overwrite a deployment changed concurrently outside this workflow.
  current=$(kubectl --request-timeout=20s -n rinrin get deployment astrbot \
    -o jsonpath='{.spec.template.spec.containers[?(@.name=="astrbot")].image}') || exit "$code"
  if [[ "$current" == "$IMAGE" ]]; then
    kubectl --request-timeout=20s -n rinrin set image deployment/astrbot "astrbot=$previous" || exit "$code"
    kubectl --request-timeout=30s -n rinrin rollout status deployment/astrbot --timeout=600s || true
  else
    echo '::warning::Image changed externally; automatic rollback skipped.'
  fi
  exit "$code"
}
trap rollback ERR
kubectl --request-timeout=20s -n rinrin set image deployment/astrbot "astrbot=$IMAGE"
kubectl --request-timeout=30s -n rinrin rollout status deployment/astrbot --timeout=600s
curl --fail --silent --show-error --max-time 15 --retry 6 --retry-delay 5 \
  --retry-all-errors https://rinrin.tmlab.top/ > /dev/null
trap - ERR
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf '### Rinrin deployed\n\nImage: `%s`\n\nPrevious: `%s`\n\nPod readiness and public dashboard verified. QQ reply and MCP checks remain manual.\n' \
    "$IMAGE" "$previous" >> "$GITHUB_STEP_SUMMARY"
fi
