#!/usr/bin/env bash
# myscript.sh - QEMU Guest Agent helper

show_help() {
  cat <<EOF
Usage: $0 -d <domain> -c <command> [-- args for exec]

Options:
  -d, --domain   VM domain name
  -c, --command  Command to run
  -h, --help     Show this help

Commands:
  ping        - Check if agent is alive
  shutdown    - Shutdown guest cleanly
  reboot      - Reboot guest cleanly
  hostname    - Get guest hostname
  info        - Get guest OS/kernel info
  time        - Get guest time
  set-time    - Sync guest time with host
  ip          - Get guest IP addresses
  fsinfo      - Get filesystem info
  fsfreeze    - Freeze filesystems
  fsthaw      - Thaw filesystems
  exec -- <cmd...>  - Run command inside guest
EOF
}

DOMAIN=""
COMMAND=""
shift_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--domain)
      DOMAIN="$2"
      shift 2
      ;;
    -c|--command)
      COMMAND="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    --)
      shift
      shift_args=("$@")
      break
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

if [[ -z "$DOMAIN" || -z "$COMMAND" ]]; then
  show_help
  exit 1
fi

run_cmd() {
  virsh qemu-agent-command "$DOMAIN" "$1" --pretty
}

case "$COMMAND" in
  ping)
    run_cmd '{"execute":"guest-ping"}'
    ;;
  shutdown)
    run_cmd '{"execute":"guest-shutdown"}'
    ;;
  reboot)
    run_cmd '{"execute":"guest-shutdown","arguments":{"mode":"reboot"}}'
    ;;
  hostname)
    run_cmd '{"execute":"guest-get-host-name"}'
    ;;
  info)
    run_cmd '{"execute":"guest-info"}'
    ;;
  time)
    run_cmd '{"execute":"guest-get-time"}'
    ;;
  set-time)
    run_cmd '{"execute":"guest-set-time"}'
    ;;
  ip)
    run_cmd '{"execute":"guest-network-get-interfaces"}'
    ;;
  fsinfo)
    run_cmd '{"execute":"guest-get-fsinfo"}'
    ;;
  fsfreeze)
    run_cmd '{"execute":"guest-fsfreeze-freeze"}'
    ;;
  fsthaw)
    run_cmd '{"execute":"guest-fsfreeze-thaw"}'
    ;;
  exec)
    if [[ ${#shift_args[@]} -eq 0 ]]; then
      echo "Usage: $0 -d $DOMAIN -c exec -- <command> [args...]"
      exit 1
    fi
    CMD_PATH="${shift_args[0]}"
    CMD_ARGS=("${shift_args[@]:1}")
    JSON="{\"execute\":\"guest-exec\",\"arguments\":{\"path\":\"$CMD_PATH\",\"arg\":["
    for arg in "${CMD_ARGS[@]}"; do
      JSON="$JSON\"$arg\","
    done
    JSON="${JSON%,}],\"capture-output\":true}}"
    PID=$(run_cmd "$JSON" | jq -r '.return.pid')
    while true; do
      STATUS=$(run_cmd "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$PID}}")
      EXITED=$(echo "$STATUS" | jq -r '.return.exited')
      if [[ "$EXITED" == "true" ]]; then
        EXITCODE=$(echo "$STATUS" | jq -r '.return.exitcode')
        OUT=$(echo "$STATUS" | jq -r '.return."out-data"' | base64 -d 2>/dev/null)
        ERR=$(echo "$STATUS" | jq -r '.return."err-data"' | base64 -d 2>/dev/null)
        echo "Exit code: $EXITCODE"
        [[ -n "$OUT" ]] && echo "STDOUT:" && echo "$OUT"
        [[ -n "$ERR" ]] && echo "STDERR:" && echo "$ERR" >&2
        break
      fi
      sleep 1
    done
    ;;
  *)
    echo "Unknown command: $COMMAND"
    show_help
    exit 1
    ;;
esac