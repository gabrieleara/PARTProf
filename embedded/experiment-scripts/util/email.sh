#!/bin/bash

function send_update_email() {
    local to="$1"
    local from="$2"
    local testtype="$3"
    local thedate

    thedate=$(date)

    ssmtp "$to" <<EOF || true
To: $to
From: $from
Subject: $testtype Test Finished $thedate!

This email was sent to you because the test you requested is finished and you wanted to be notified!

Test finished at $thedate.

Sincerely,
$HOSTNAME
EOF
}

function send_error_email() {
    local to="$1"
    local from="$2"
    local testtype="$3"
    local thedate

    thedate=$(date)

    ssmtp "$to" <<EOF || true
To: $to
From: $from
Subject: $testtype Test WENT TERRIBLY WRONG ON $thedate!

This email was sent to you because the test you requested WENT TERRIBLY WRONG and finished with an error state!

Test finished at $thedate.

Sincerely,
$HOSTNAME
EOF
}
