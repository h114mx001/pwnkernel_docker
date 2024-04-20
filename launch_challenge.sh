#!/bin/bash
CHALL_LEVEL=$1
cp "/challenges/kernel$CHALL_LEVEL/challenge.ko" "/challenge/challenge.ko"
vm start
vm connect
