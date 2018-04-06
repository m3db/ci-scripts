#!/bin/sh

PROTO_SRC=$1
for i in "$PROTO_SRC"/*; do
	if ! [ -d $i ]; then
		continue
	fi

	if ls $i/*.proto > /dev/null 2>&1; then
			echo "generating from $i"
			protoc -I$GOPATH/src/github.com/gogo/protobuf/gogoproto -I$PROTO_SRC --gogofaster_out=$PROTO_SRC $i/*.proto
	fi
done
