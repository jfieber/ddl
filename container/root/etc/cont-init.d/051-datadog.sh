#!/bin/bash -e

# Added bigcontenv script to load env variables with size more than 4096 (Refer: https://github.com/behance/docker-base/pull/19)
source /scripts/with-bigcontenv

##### Core config #####

# ================================================= #
# Determine OS and export to the environment        #
# Set DD_CONFIG_PATH according to the OS platform   #
# ================================================= #
OS="`grep DISTRIB_ID /etc/*-release | awk -F '=' '{print $2}'`"

# ubuntu:
if [ "$OS" = "Ubuntu" ]; then
   DD_CONFIG_FILE="/etc/dd-agent/datadog.conf"
   export LINUX_VARIANT="Ubuntu"
   export DD_LOG_FILE_DIRECTORY="/var/log/datadog/"
# alpine:
else
   DD_CONFIG_FILE="/opt/datadog-agent/agent/datadog.conf"
   export LINUX_VARIANT="Alpine"
   export DD_LOG_FILE_DIRECTORY="/opt/datadog-agent/logs"
fi

# ================================= #
# Datadog Agent configuration       #
#   1. Turn off non-local traffic   #
#   2. Turn syslog off              #
# ================================= #
sed -i -e"s/^.*non_local_traffic:.*$/non_local_traffic: no/" $DD_CONFIG_FILE
sed -i -e"s/^.*log_to_syslog:.*$/log_to_syslog: no/" $DD_CONFIG_FILE
sed -i -e"s/^user=.*$/user=asruser/" /etc/dd-agent/supervisor.conf
sed -i -e"s/^AGENTUSER=.*$/AGENTUSER=asruser/" /etc/init.d/datadog-agent

# Setting proper permissions for runtime log files to allow running as asruser
chown -R asruser: $DD_LOG_FILE_DIRECTORY

# =========================================================== #
# If DD_API_KEY is passed, write it to the datadog.conf file  #
# Start the Datadog Agent only if this variable is passed     #
# =========================================================== #
if [[ $DD_API_KEY ]]; then
    sed -i -e "s/^.*api_key:.*$/api_key: ${DD_API_KEY}/" $DD_CONFIG_FILE

    #
    # cat /opt/datadog-agent/bin/supervisord
    # ======================================================================================= #
    # [REQUIRED]: If DD_INSTANCE_PREFIX is passed, write it to the datadog.conf file          #
    # ======================================================================================= #
    if [[ $DD_INSTANCE_PREFIX ]]; then
        HOST_NAME=$DD_INSTANCE_PREFIX"-"$HOSTNAME
        sed -i -r -e "s/^# ?hostname.*$/hostname: $HOST_NAME/" $DD_CONFIG_FILE
        echo "[datadog] Using HOSTNAME : $HOST_NAME"
    fi

    # ======================================================================================= #
    # [OPTIONAL]: Add host tags if any of:                                                    #
    #   DD_TAG_*                                                                              #
    #   DD_TAGENV_*                                                                           #
    # are set                                                                                 #
    # ======================================================================================= #
    if [ -n "${!DD_TAG_*}${!DD_TAGENV_*}" ]; then

        #
        # Function to turn environment variables:
        #
        #   DD_TAG_foo=value
        #   DD_TAGENV_foo_env=FOO
        #
        # into:
        #
        #   tags: foo:value,foo_env:value_of_FOO
        #
        # Reference: https://docs.datadoghq.com/guides/tagging/#assigning-tags-using-the-configuration-files
        #
        function host_tags {
            local tags
            local tagidx=0
            for tag in "${!DD_TAGENV_@}"; do
                local target_env=${!tag}
                if [[ -n "${!target_env}" ]]; then
                    tags[$((tagidx++))]="${tag/DD_TAGENV_/}:${!target_env}"
                fi
            done
            for tag in "${!DD_TAG_@}"; do
                if [[ -n "${!tag}" ]]; then
                    tags[$((tagidx++))]="${tag/DD_TAG_/}:${!tag}"
                fi
            done
            function join_by { local IFS="$1"; shift; echo "$*"; }
            join_by , ${tags[@]}
        }

        # Set the tags in the datadog config
        computed_tags="$(host_tags)"
        if [[ -n "$computed_tags" ]]; then
            # Comment any tags that that happen to be in the file
            sed -i -r -e "s/^tags:/# tags:/" $DD_CONFIG_FILE
            # Append computed tags
            echo "# Computed tags" >> $DD_CONFIG_FILE
            echo "tags: $computed_tags" >> $DD_CONFIG_FILE
            echo "[datadog] Using host tags : $computed_tags"
        fi
    fi

    # ============================================================================= #
    # [OPTIONAL]: If DD_PORT is passed, write to and activate it in datadog.conf    #
    # If the DD_PORT is not provided, the datadog agent would start at port 8125    #
    # ============================================================================= #
    if [[ $DD_PORT ]]; then
        sed -i -r -e "s/^# ?dogstatsd_port.*$/dogstatsd_port: ${DD_PORT}/" -e "s/# dogstatsd_port/dogstatsd_port/" $DD_CONFIG_FILE
        echo "[datadog] Using DD_PORT : ${DD_PORT}"
    else
        DD_PORT=8125
        sed -i -r -e "s/^# ?dogstatsd_port.*$/dogstatsd_port: $DD_PORT/" -e "s/# dogstatsd_port/dogstatsd_port/" $DD_CONFIG_FILE
        echo "[datadog] Using default Datadog port : $DD_PORT"
        echo "[datadog] Pass -e DD_PORT=<custom_port_number> to the docker run command to run the Datadog agent at a custom port"
    fi
    echo "[datadog] Starting the Datadog Agent on port: ${DD_PORT} ..."

    echo "*******"
    cat /etc/dd-agent/datadog.conf | egrep -v '^(#|$)'
    echo "*******"
    /etc/init.d/datadog-agent configtest
    /etc/init.d/datadog-agent start

else
    echo "[datadog] The Datadog Agent will not start as the API key is not provided..."
    echo "[datadog] Pass -e DD_API_KEY=<your_datadog_api_key> to the docker run command to start the Datadog agent"
fi

# =================================================================================================================================================== #
# Set Environment Variable so that it can be used later in the scripts                                                                                #
# https://github.com/just-containers/s6-overlay/blob/8ede6c6a02c9297ce78e46943468129fff5bcb6d/builder/overlay-rootfs/etc/s6/init/init-stage1#L13-L14  #
# https://github.com/just-containers/s6-overlay/issues/46#issuecomment-97708601                                                                       #
# =================================================================================================================================================== #
s6-dumpenv -- /var/run/s6/container_environment

