#!/bin/bash

challenge_name=$1

level=$(echo $challenge_name | grep -Eo "[0-9]+\.[0-9]+")

mkdir "./challenges/kernel$level"
mv "./$challenge_name" "./challenges/kernel$level/challenge.ko"
