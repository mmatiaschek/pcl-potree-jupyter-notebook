FROM jupyter/base-notebook:27ba57364579

# https://zero-to-jupyterhub.readthedocs.io/en/latest/user-environment.html#use-jupyterlab-by-default

MAINTAINER Markus Matiaschek <mmatiaschek@gmail.com>
WORKDIR /home/joyvan

# install apt packages as root
USER root

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      pcl-tools \
      apache2 \
      libtiff-dev libgeotiff-dev libgdal1-dev \
	    libboost-system-dev libboost-thread-dev libboost-filesystem-dev libboost-program-options-dev libboost-regex-dev libboost-iostreams-dev \
	    git cmake build-essential wget \
      && rm -rf /var/lib/apt/lists/*

RUN mkdir -p  /opt/potree/dev/workspaces/lastools && \
  cd /opt/potree/dev/workspaces/lastools && \
  git clone https://github.com/m-schuetz/LAStools.git master && \
  cd master/LASzip && \
  mkdir build && \
  cd build && \
  cmake -DCMAKE_BUILD_TYPE=Release .. && \
  make && \
  make install && \
  ldconfig

RUN mkdir -p /opt/potree/dev/workspaces/PotreeConverter  && \
  cd /opt/potree/dev/workspaces/PotreeConverter && \
  git clone https://github.com/potree/PotreeConverter.git master && \
  cd master && \
  mkdir build && \
  cd build && \
  cmake -DCMAKE_BUILD_TYPE=Release -DLASZIP_INCLUDE_DIRS=/opt/potree/dev/workspaces/lastools/master/LASzip/dll -DLASZIP_LIBRARY=/opt/potree/dev/workspaces/lastools/master/LASzip/build/src/liblaszip.so .. && \
  make 
  #&& \ install doesn't help because unclear where resources/page_template needs to go
  # instead use binary from build
  # https://github.com/potree/PotreeConverter/issues/249 as well as 204 206
  # also see https://github.com/potree/PotreeConverter/blob/develop/Dockerfile
  # https://github.com/potree/PotreeConverter/blame/develop/README.md#L45 is maybe not specific enough
#  make install

RUN ln -s /opt/potree/dev/workspaces/PotreeConverter/master/build/PotreeConverter/PotreeConverter /usr/local/bin/PotreeConverter

RUN cd /opt/potree/dev/workspaces/PotreeConverter/master/build/PotreeConverter && \
  cp -r /opt/potree/dev/workspaces/PotreeConverter/master/PotreeConverter/resources/ . && \
  rm /var/www/html/index.html

RUN chown -R $NB_USER: /opt/potree

RUN mkdir -p /home/joyvan/work/html
RUN cp -a /opt/potree/dev/workspaces/PotreeConverter/master/build/PotreeConverter/resources/page_template/ /home/joyvan/work/html/demo
RUN ln -s /home/joyvan/work/html/ /var/www/html/potree

#USER $NB_USER

# Set the ENTRYPOINT to use bash
# (this is also where you’d set SHELL,
# if your version of docker supports this)
ENTRYPOINT [ "/bin/bash", "-c" ]

# Use the environment.yml to create the conda environment.
ADD environment.yml /home/joyvan/environment.yml
# potree template, demo, create python (TODO Version) environment
RUN cp -ap /opt/potree/dev/workspaces/PotreeConverter/master/build/PotreeConverter/resources/page_template work/html/demo
ADD pcl_potree_demo.ipynb /home/joyvan/pcl_potree_demo.ipynb
ADD work/demo.vtk /home/joyvan/work/demo.vtk
ADD work/demo.pcd /home/joyvan/work/demo.pcd

RUN [ "conda", "env", "create" ]

# TODO environment.yml?
ARG JUPYTERLAB_VERSION=0.31.12
RUN     pip install jupyterlab==$JUPYTERLAB_VERSION \
    &&  jupyter labextension install @jupyterlab/hub-extension


VOLUME ["/home/jovyan/work/"]
EXPOSE 8888
#EXPOSE 1234 needed for gulp potree
EXPOSE 80

CMD [ "/opt/conda/envs/pcl_env/bin/jupyter-notebook --allow-root"]
