#!/bin/sh

PROTO_SRC=$1
for i in "$PROTO_SRC"/*; do
	if ! [ -d $i ]; then
		continue
	fi

	if ls $i/*.proto > /dev/null 2>&1; then
			echo "generating from $i"
			protoc --gogofaster_out=plugins=grpc:$GOPATH/src --proto_path=$GOPATH/src:$GOPATH/src/github.com/m3db/m3/vendor $i/*.proto
	fi
done
