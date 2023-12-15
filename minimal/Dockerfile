ARG BASE_IMAGE
FROM ${BASE_IMAGE}

USER root

ARG SETUP
COPY install/${SETUP}.sh /install.sh
RUN bash /install.sh && rm -f /install.sh

USER user
