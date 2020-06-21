# FierymudMudletClient
Official [Mudlet](https://www.mudlet.org/) Client for Fierymud (fierymud.org)

This code uses [Muddler](https://github.com/demonnic/muddler) to create the Mudlet package.  You can either install that from source and use java, or use the docker container and add a small script as follows:

*Install Docker Container*

```bash
docker pull demonnic/muddler:latest
```

*Add the following script somewhere*

```bash
#!/bin/bash
docker run --rm -it -v $PWD:/$PWD -w /$PWD demonnic/muddler
sudo chown -R $USER:$USER build
```

*Build!*
```bash
cd FierymudMudletClient/
/path/to/muddler/script.sh
```

This should create a build directory with the mpackage file inside it.
