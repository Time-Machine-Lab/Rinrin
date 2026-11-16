#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/bin"
export STATE="$test_dir/state" CALLS="$test_dir/calls"
export IMAGE="example/rinrin@sha256:$(printf '%064d' 1)"
export PATH="$test_dir/bin:$PATH"
cat > "$test_dir/bin/kubectl" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$CALLS"
case "$*" in
  *'get deployment'*) cat "$STATE" ;;
  *'set image'*) printf '%s' "${!#}" | sed 's/^astrbot=//' > "$STATE" ;;
  *'rollout status'*)
    if [[ "${SCENARIO:-}" == rollout-failure && "$(cat "$STATE")" == "$IMAGE" ]]; then exit 1; fi
    ;;
esac
MOCK
cat > "$test_dir/bin/curl" <<'MOCK'
#!/usr/bin/env bash
case "${SCENARIO:-}" in
  health-failure) exit 22 ;;
  concurrent-change) echo external-image > "$STATE"; exit 22 ;;
esac
MOCK
chmod +x "$test_dir/bin/"*
for scenario in success rollout-failure health-failure concurrent-change; do
  export SCENARIO="$scenario"
  echo old-image > "$STATE"
  : > "$CALLS"
  if bash "$script_dir/release.sh" > "$test_dir/output" 2>&1; then
    [[ "$scenario" == success && "$(cat "$STATE")" == "$IMAGE" ]]
  else
    [[ "$scenario" != success ]]
    if [[ "$scenario" == concurrent-change ]]; then
      [[ "$(cat "$STATE")" == external-image ]]
    else
      [[ "$(cat "$STATE")" == old-image ]]
    fi
  fi
  echo "PASS: $scenario"
done
if IMAGE=unversioned bash "$script_dir/release.sh" > "$test_dir/output" 2>&1; then
  echo 'FAIL: mutable image accepted' >&2
  exit 1
fi
echo 'PASS: mutable image rejected'
