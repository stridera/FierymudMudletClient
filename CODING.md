# Coding Guide

This code uses [Muddler](https://github.com/demonnic/muddler) to create the Mudlet package. You can either install that from source and use java, or use the docker container and add a small script as follows:

_Install Docker Container_

```bash
docker pull demonnic/muddler:latest
```

_Add the following script somewhere_

```bash
#!/bin/bash
docker run --pull always --rm -it -u $(id -u):$(id -g) -v $PWD:/$PWD -w /$PWD demonnic/muddler
```

_Build!_

```bash
cd FierymudMudletClient/
/path/to/muddler/script.sh
```

This should create a build directory with the mpackage file inside it.
Follow the steps [here](https://github.com/demonnic/muddler/wiki/CI) to have it auto-reload on build.
