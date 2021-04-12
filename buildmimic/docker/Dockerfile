FROM postgres:latest

# in the docker initialization, we do not build the data
ENV BUILD_MIMIC 0
RUN user=$USER 
# copy the build scripts into a different folder and remove the temp folder

RUN mkdir -p /home/${user}/workspace/mimic-code /home/${user}/workspace/mimic_data \
 && cd /mimic-code \
 # copy the build scripts into a different folder and remove the temp folder
 && cp -r buildmimic /docker-entrypoint-initdb.d/ \
 && cp buildmimic/docker/setup.sh /docker-entrypoint-initdb.d/ \
 && rm -rf /mimic-code
 
# RUN echo "starting Dockerfile"
# RUN user=$USER 

# WORKDIR /home/${user}/workspace/mimic-iv-script

# RUN mkdir -p /home/${user}/workspace/mimic-iv-script /home/${user}/workspace/mimic-data-iv \
# && cd /home/${user}/workspace/mimic-iv-script \
#  # copy the build scripts into a different folder and remove the temp folder
#  && cp -r mimic-iv-script /docker-entrypoint-initdb.d/ \
#  && cp mimic-iv-script/docker/setup.sh /docker-entrypoint-initdb.d/

# RUN cp -r mimic-iv-script /docker-entrypoint-initdb.d/ \
#  && cp mimic-iv-script/docker/setup.sh /docker-entrypoint-initdb.d/