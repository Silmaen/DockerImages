ARG BASE_IMAGE="ubuntu"
FROM ${BASE_IMAGE}

USER root

ARG SETUP
COPY install/ /tmp/install/
RUN bash /tmp/install/${SETUP}.sh && rm -rf /tmp/install
ENV LANG=C.UTF-8
ENV LANGUAGE=C.UTF-8
# No LC_ALL: it would override LC_CTYPE.
ENV LC_CTYPE=en_US.UTF-8
ENV PATH=/usr/poetry/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER user
