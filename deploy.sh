#!/usr/bin/env sh
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
aws s3 cp --recursive --acl public-read $DIR/build/ s3://may.hazelfire.net
