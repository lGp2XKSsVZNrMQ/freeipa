#!/bin/bash
#
# Copyright (C) 2017 FreeIPA Contributors see COPYING for license
#
# NOTE: this script is intended to run in Travis CI only

PYTHON="/usr/bin/python${TRAVIS_PYTHON_VERSION}"
test_set=""
developer_mode_opt="--developer-mode"

function truncate_log_to_test_failures() {
    # chop off everything in the CI_RESULTS_LOG preceding pytest error output
    # if there are pytest errors in the log
    error_fail_regexp='\(=== ERRORS ===\)\|\(=== FAILURES ===\)'

    if grep -e "$error_fail_regexp" $CI_RESULTS_LOG > /dev/null
    then
        sed -i "/$error_fail_regexp/,\$!d" $CI_RESULTS_LOG
    fi
}

if [[ "$TASK_TO_RUN" == "lint" ]]
then
    if [[ "$TRAVIS_EVENT_TYPE" == "pull_request" ]]
    then
        git diff origin/$TRAVIS_BRANCH -U0 | pep8 --diff &> $PEP8_ERROR_LOG ||:
    fi 

    # disable developer mode for lint task, otherwise we get an error
    developer_mode_opt=""
fi

if [[ -n "$TESTS_TO_RUN" ]]
then
    pushd ipatests
    test_set=`ls -d -1 $TESTS_TO_RUN 2> /dev/null | tr '\n' ' '`
    popd
fi

docker pull $TEST_RUNNER_IMAGE

ipa-docker-test-runner -l $CI_RESULTS_LOG \
    -c $TEST_RUNNER_CONFIG \
    $developer_mode_opt \
    --container-environment "PYTHON=$PYTHON" \
    --container-image $TEST_RUNNER_IMAGE \
    --git-repo $TRAVIS_BUILD_DIR \
    $TASK_TO_RUN $test_set

exit_status="$?"

if [[ "$exit_status" -ne 0 ]]
then
    truncate_log_to_test_failures
fi

exit $exit_status
