#!/bin/bash

# Start of CommandLaunchScript
set -o nounset -o errexit

DOMINO_HOME_VAL=${DOMINO_HOME:-}; if [ -z "${DOMINO_HOME_VAL}" ]; then CURL="curl"; else CURL="${DOMINO_HOME_VAL}/bin/curl"; fi; echo "Using curl at ${CURL}"


export DOMINO_USER_NAME=petter
export USER=$(whoami)
export HOME=`eval echo "~$USER"`
export LOGNAME=$USER

# Load defaults
if [ -f ~/.domino-defaults ]
then
  source ~/.domino-defaults
fi

# Load environment variables
if [ -f "/var/lib/domino/launch/env.sh" ]
then
  source "/var/lib/domino/launch/env.sh"
fi

TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/metrics/launch.run_container.command_launch_script:start/trace?timestamp=${TIMESTAMP}" || true &

TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/metrics/launch.run_container.command_launch_script.config_spark_defaults:start/trace?timestamp=${TIMESTAMP}" || true &
# Execute /mnt/.domino/configure-spark-defaults.sh if it exists.
if [ -f '/mnt/.domino/configure-spark-defaults.sh' ]
then
  echo '### Executing /mnt/.domino/configure-spark-defaults.sh ###'
  set -o errexit
  source '/mnt/.domino/configure-spark-defaults.sh'
  echo '### Completed /mnt/.domino/configure-spark-defaults.sh ###'
fi

TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/metrics/launch.run_container.command_launch_script.config_spark_defaults:end/trace?timestamp=${TIMESTAMP}" || true &


TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/metrics/launch.run_container.command_launch_script.install_packages:start/trace?timestamp=${TIMESTAMP}" || true &

TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/metrics/launch.run_container.command_launch_script.install_packages:end/trace?timestamp=${TIMESTAMP}" || true &


mkdir -p /mnt/results
echo -n '' > /mnt/results/stdout.txt
echo -n '' > /mnt/results/stderr.txt

function post_run_handler() {
  # Execute postRunScript.sh if it exists.
if [ -f '/domino/launch/postRunScript.sh' ]
then
  TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/runBootSequenceEvent?eventKey=run.boot_sequence.default&timestamp=${TIMESTAMP}" || true &
  echo '### Executing /domino/launch/postRunScript.sh ###'
  set -o errexit
  source '/domino/launch/postRunScript.sh'
  echo '### Completed /domino/launch/postRunScript.sh ###'
  TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/runBootSequenceEvent?eventKey=run.boot_sequence.default&timestamp=${TIMESTAMP}" || true &
fi

  return 0
}

function exit_logging() {
  local -r code_at_exit="$?"

  if [ -n "${CLEANUP_COMMAND:-}" ]; then

    local max_retries=${MAX_RETRIES:-0}
    local retry_delay=${RETRY_DELAY:-0}

    echo "Evaluating cleanup command on EXIT with exit code $code_at_exit: $CLEANUP_COMMAND"

    local n=1
    while true; do
      eval $CLEANUP_COMMAND && break || {
        if [[ $n -lt $max_retries ]]; then
          echo "Cleanup command failed. Attempt $n/$max_retries. Will try again in $retry_delay seconds..."
          ((n++))
          sleep $retry_delay
        else
          echo "Cleanup command failed after $n attempts." >&2
          exit 1
        fi
      }
    done
  fi

  # treat success, kill, term signals as normal exits (since docker sends the latter two)
  if [[ "$code_at_exit" =~ ^(0|137|143)$ ]]; then
    exit $code_at_exit
  fi

  (>&2 echo "Failed with exit code: ${code_at_exit}") 2> >(tee -a /mnt/results/stdout.txt >&2)
  sleep 0.5
  exit 1
}
trap 'post_run_handler' TERM
trap 'exit_logging' EXIT




TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/metrics/launch.run_container.command_launch_script.pre_run_script:start/trace?timestamp=${TIMESTAMP}" || true &
# Execute preRunScript.sh if it exists.
if [ -f '/domino/launch/preRunScript.sh' ]
then
  TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/runBootSequenceEvent?eventKey=run.boot_sequence.pre_run_script.start&timestamp=${TIMESTAMP}" || true &
  echo '### Executing /domino/launch/preRunScript.sh ###'
  set -o errexit
  source '/domino/launch/preRunScript.sh'
  echo '### Completed /domino/launch/preRunScript.sh ###'
  TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/runBootSequenceEvent?eventKey=run.boot_sequence.pre_run_script.end&timestamp=${TIMESTAMP}" || true &
fi

TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/metrics/launch.run_container.command_launch_script.pre_run_script:end/trace?timestamp=${TIMESTAMP}" || true &


cd $DOMINO_WORKING_DIR

# Run command as-is
set +o errexit
TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/metrics/launch.user_init:start/trace?timestamp=${TIMESTAMP}" || true &
TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/metrics/launch.user_init.wait_connectable:start/trace?timestamp=${TIMESTAMP}" || true &
'/opt/domino/workspaces/jupyterlab/start' 1> >(tee -a /mnt/results/stdout.txt) 2> >(tee -a /mnt/results/stderr.txt >&2) &
declare -ri run_command=$!
TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/runBootSequenceEvent?eventKey=run.boot_sequence.final_run_command_issued&timestamp=${TIMESTAMP}" || true &
TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/metrics/launch.run_container.command_launch_script:end/trace?timestamp=${TIMESTAMP}" || true &
TIMESTAMP=$(date +%s%3N);${CURL} -s -X POST "http://127.0.0.1:9000/executor/metrics/launch.run_container:end/trace?timestamp=${TIMESTAMP}" || true &
wait $run_command
exitcode=$?
if [ "$exitcode" -eq 0 ]; then
  post_run_handler &
  wait $!
  exitcode=$?
fi
sleep 2
exit $exitcode

# End of CommandLaunchScript
