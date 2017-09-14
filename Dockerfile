FROM behance/docker-base:2.0.1

ENV AGENT_VERSION=1:5.17.0-1 \
    CA_CERTIFICATES_VERSION=20160104ubuntu1 \
    DOCKER_DD_AGENT=yes \
    SYSSTAT_VERSION=11.2.0-1ubuntu0.1 \
    NOT_ROOT_USER=asruser \
    UID=1001

WORKDIR /

# Install the Datadog Agent
RUN echo "deb http://apt.datadoghq.com/ stable main" > /etc/apt/sources.list.d/datadog.list && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C7A7DA52 && \
    /bin/bash -e /security_updates.sh && \
    apt-get update -yqq && \
    apt-get install -yqq sysstat="${SYSSTAT_VERSION}" && \
    apt-get install --no-install-recommends -yqq  \
         datadog-agent="${AGENT_VERSION}" \
         ca-certificates="${CA_CERTIFICATES_VERSION}" && \

    # Copy sample datadog config file
    mv /etc/dd-agent/datadog.conf.example /etc/dd-agent/datadog.conf && \

    adduser --system --disabled-password --uid ${UID} --home /home/${NOT_ROOT_USER} --shell /bin/bash ${NOT_ROOT_USER} && \

    # Set proper permissions to allow running as asruser
    chown ${NOT_ROOT_USER}: /etc/dd-agent/datadog.conf /var/log/datadog /etc/dd-agent /opt/datadog-agent/run/ && \
    chmod g+w /etc/dd-agent/datadog.conf && \
    chmod -R g+w /var/log/datadog && \
    chmod g+w /etc/dd-agent && \
    chmod g+w /opt/datadog-agent/run/ && \

    # Clean up
    apt-get clean && \
    /bin/bash /clean.sh

# Overlay the root filesystem from this repo
COPY container/root /
COPY main /
