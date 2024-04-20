# pwn.college - Kernel local build

Yet another pwn.college [dojo](https://github.com/pwncollege/dojo) fork, but just barely minimal for the shake of building stuff locally!

## Why this exists?

I am a big fan of [pwn.college](https://pwn.college)! I love the learning styles of Professors here, love the supportive community and also their easy-but-not-so-easy challenges! So so great! However, the remote connection to pwn.college's dojo (personaly, to me) was really bad. Laggy, typos, etc. are all arounds. So, the solutions for them are local-first! 

However, modules like ROP, bof, etc. can easily be set up locally with somethings like [pwninit](https://github.com/io12/pwninit) (And I still work with them day by day). However, kernel security modules are the whole different. The default [pwnkernel](https://github.com/pwncollege/pwnkernel) works inside [busybox](https://www.busybox.net/), which (agin, to me) lacks lots of customizing stuffs! Especially I missed `pwntools` and python so much 😭. 

Therefore, I decided to dive in the pwn.college's dojo code, and try to make it work locally. And here it is!

## How is this different from `pwnkernel`, or `dojo`? 

To `pwnkernel`, it is different because I took advantage of the brilliant setup of `dojo`, which allows me to maintain my whole workflows of debugging, exploit developments around tools like `pwntools` the same. Else, nothing differs. 

To `dojo`, I have removed (not very optimally, but next commits I will try to) the unused libraries related to the desktop environments, or other modules like `IDA, Ghidra, r2` (I have them in my local machine, don't need to put here). So, basically it is the `dojo` environment, but focusing only to kernel security modules (or some other like ROP, Bof, etc.)

## How to use? 

1. First, clone this. 

```bash
git clone https://github.com/h114mx001/pwnkernel_docker
```
2. About the challenges

You must `scp`, or build the challenges' binaries first. You will put it in this layout:

```
.
└── challenges/
    ├── kernel1.0/
    │   └── challenge.ko
    ├── kernel1.1/
    │   └── challenge.ko
    └── ...
```

To me, I automated it with:

```bash
scp -i ~/.ssh/pwncollege hacker@pwn.college:/challenge/babykernel_level5.1.ko . 
./move_to_target.sh 5.1
```

3. About the `$HOME` directory

Remember pwn.college let's you sync the directory? In here, I used `docker` to mount the folders. You can edit your favorite folder mounting in [launch.sh](./launch.sh)

```bash
#!/bin/bash
docker run \
    # challenges path goes here
    --mount type=bind,source="$(pwd)"/challenges,target=/challenges \   
    # home directory goes here, change your favorite with `pwnscripts`
    --mount type=bind,source="$(pwd)"/pwnscripts,target=/root \  
    --rm -it pwncollege_kernel /bin/bash
```

4. Finally, enjoy the build~~~

```bash
docker build -t pwncollege_kernel .
```

5. Launch the container

```bash
./launch.sh
```
6. Opening some challenges

If you need some custom modules, you can move the `.ko` kernel module into `/challenge` folder and run 

```bash 
vm connect
```
as you often do in pwn.college's dojo.

If you want to call the challenge by its level number, do this

```bash 
launch_challenge $LEVEL_NUMBER
```

## What's next?

I am not sure :) Let me learn something new and then I will try to make something better haha


## Acknowledgement

- [pwn.college](https://pwn.college) for the great challenges, great professors, and great community! 
- [pwncollege/dojo](https://github.com/pwncollege/dojo), and all the maintainers. Actually, most of the code in here was copied from the repo xD. 


