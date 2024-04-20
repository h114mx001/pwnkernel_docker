docker run \
    --mount type=bind,source="$(pwd)"/challenges,target=/challenges \
    --mount type=bind,source="$(pwd)"/pwnscripts,target=/home/hacker \
    --rm -it pwncollege_kernel /bin/bash
