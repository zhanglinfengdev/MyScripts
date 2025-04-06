#!/bin/bash

its_protoHome='/Users/didi/AndroidStudioProjects/its-proto'

rm -rf "$its_protoHome/javaOut"
mkdir "$its_protoHome/javaOut"
/usr/bin/git -C $its_protoHome checkout -- .
/usr/bin/git -C $its_protoHome branch --track $1 "origin/$1"
/usr/bin/git -C $its_protoHome checkout $1
# /usr/bin/git -C $its_protoHome checkout -b $1
/usr/bin/git -C $its_protoHome pull

/usr/local/bin/sketchybar --set com.itsproto label="compileing:$1" \
                          --set com.itsproto label.color="0xffed8796"



/Users/didi/scripts/compile_proto.sh

/usr/local/bin/sketchybar --set com.itsproto label=""

open "$its_protoHome/javaOut/order_route_api_proto"






