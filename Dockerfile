# SOURCE https://github.com/PowerShell/PowerShell-Docker/blob/master/release/stable/alpine/docker/Dockerfile

# Docker image file that describes an Alpine3.8 image with PowerShell installed from .tar.gz file(s)
# NOTE: the Alpine tar.gz when this was written doesn't contain the modules.  For that we need a container with modules.
# To accomplish this, we will get the modules from the full linux tar.gz package, then
# overlay the Alpine tar.gz on top of it.
# There are TODO's in the file on updates that should occur one the Alpine .tar.gz contains everything

# # Define arg(s) needed for the From statement
ARG fromTag=3.8

FROM alpine:${fromTag} AS installer-env

# Define Args for the needed to add the package
ARG PS_VERSION=6.1.0
# TODO: once the official build produces a full package for Alpine, update this to the full Alpine package
ARG PS_PACKAGE=powershell-${PS_VERSION}-linux-x64.tar.gz
ARG PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/${PS_PACKAGE}
ARG PS_PACKAGE_MUSL=powershell-${PS_VERSION}-linux-musl-x64.tar.gz
ARG PS_PACKAGE_MUSL_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/${PS_PACKAGE_MUSL}
ARG PS_INSTALL_VERSION=6

# downoad the Linux tar.gz and save it
ADD ${PS_PACKAGE_URL} /tmp/linux.tar.gz

# define the folder we will be installing PowerShell to
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/$PS_INSTALL_VERSION

# Create the install folder
RUN mkdir -p ${PS_INSTALL_FOLDER}

# Unzip the Linux tar.gz
RUN tar zxf /tmp/linux.tar.gz -C ${PS_INSTALL_FOLDER}

# TODO: once the official build produces a full package for Alpine, remove this overlay of the apline files
# Download the apline powershell .tar.gz package
ADD ${PS_PACKAGE_MUSL_URL} /tmp/alpine.tar.gz

# Extract the Alpine tar.gz
RUN tar zxf /tmp/alpine.tar.gz -C ${PS_INSTALL_FOLDER}

# Start a new stage so we loose all the tar.gz layers from the final image
FROM alpine:${fromTag} as powershell-alpine

# Copy only the files we need from the previous stag
COPY --from=installer-env ["/opt/microsoft/powershell", "/opt/microsoft/powershell"]

# Define Args and Env needed to create links
ARG PS_INSTALL_VERSION=6
ENV PS_INSTALL_FOLDER=/opt/microsoft/powershell/$PS_INSTALL_VERSION \
    \
    # Define ENVs for Localization/Globalization
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8

# Install dotnet dependencies and ca-certificates
RUN apk add --no-cache \
        ca-certificates \
        \
        # PSReadline/console dependencies
        ncurses-terminfo-base \
        \
        # .NET Core dependencies (https://github.com/dotnet/dotnet-docker/blob/master/2.2/runtime-deps/alpine3.8/amd64/Dockerfile)
        krb5-libs \
        libunwind \
        libgcc \
        libintl \
        libssl1.0 \
        libcrypto1.0 \
        libstdc++ \
        tzdata \
        userspace-rcu \
            zlib \
            icu-libs \
        && apk -X https://dl-cdn.alpinelinux.org/alpine/edge/main add --no-cache \
            lttng-ust \
            \
        # Create the pwsh symbolic link that points to powershell
        && ln -s ${PS_INSTALL_FOLDER}/pwsh /usr/bin/pwsh

# Edits from standard image + libcrypto1.0 above
RUN mkdir -p /root/.local/share/powershell/PSReadLine/ \
    && touch /root/.local/share/powershell/PSReadLine/ConsoleHost_history.txt
RUN adduser -h /dev/shm -u 10001 -S user

######################################################
# BUILD MINIMAL POWERSHELL IMAGE
######################################################
FROM scratch
LABEL maintainer="Wilmar den Ouden <wilmaro@intermax.nl>"

# Set when debugging
# ENV COREHOST_TRACE=1

# Needed to fix: Failed to initialize CoreCLR, HRESULT: 0x80004005
ENV COMPlus_EnableDiagnostics=0

# Copy binary and files
COPY --from=powershell-alpine --chown=10001:10001 /opt/microsoft/powershell/6/ /opt/microsoft/powershell/6/

# krb5-libs
COPY --from=powershell-alpine /usr/lib/liburcu-bp.so.6 /usr/lib/
COPY --from=powershell-alpine /usr/lib/liburcu-cds.so.6 /usr/lib/
# libgcc
COPY --from=powershell-alpine /usr/lib/libgcc_s.so.1 /usr/lib/
# libintl
COPY --from=powershell-alpine /usr/lib/libintl.so.8 /usr/lib
# libssl1.0
COPY --from=powershell-alpine /lib/libssl.so.1.0.0 /lib/
# libcrypto1.0
COPY --from=powershell-alpine /lib/libcrypto.so.1.0.0 /lib/
# libstdc++
COPY --from=powershell-alpine "/usr/lib/libstdc++.so.6" /usr/lib/
# zlib
COPY --from=powershell-alpine /lib/libz.so.1 /lib/
# musl
COPY --from=powershell-alpine "/lib/ld-musl-x86_64.so.1" /lib/

# Copy ncurses-terminfo-base
COPY --from=powershell-alpine /etc/terminfo/x/xterm /etc/terminfo/x/xterm

# ICU needed for globalization (icu-libs)
COPY --from=powershell-alpine /usr/lib/libicudata.so.60 /usr/lib/
COPY --from=powershell-alpine /usr/lib/libicui18n.so.60 /usr/lib/
COPY --from=powershell-alpine /usr/lib/libicuuc.so.60 /usr/lib/

# Timzone info from tzdata
COPY --from=powershell-alpine /usr/share/zoneinfo/ /usr/share/zoneinfo/

# lttng-ust
COPY --from=powershell-alpine /usr/lib/liblttng-ust.so.0 /usr/lib/
COPY --from=powershell-alpine /usr/lib/liblttng-ust-tracepoint.so.0 /usr/lib/

# openssl
COPY --from=powershell-alpine /etc/ssl/ /etc/ssl/

# Powershell needs this, otherwise returns "No such file or directory"
# Also contains the non root user
COPY --from=powershell-alpine /etc/passwd /etc/passwd

# RUN apk add strace
USER user

# Adds PSReadLine directory and historyfile, otherwise trips
# COPY --from=powershell-alpine /root/.local/share/powershell/PSReadLine/ /dev/shm/.local/share/powershell/PSReadLine/

ENTRYPOINT ["/opt/microsoft/powershell/6/pwsh"]
# CMD ["/opt/microsoft/powershell/6/pwsh"]

######################################################
# BUILDING PSScriptAnalyzer
######################################################
# FROM powershell-alpine as builder

# ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
#     LC_ALL=en_US.UTF-8 \
#     LANG=en_US.UTF-8

# # Opt out from .NET Core tools telemetry
# ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

# ARG PSScriptAnalyzer_VERSION=1.17.1
# ARG SDK_VERSION=2.1.202

# # RUN apt-get update \
# #     && apt-get install -y dotnet-sdk-${SDK_VERSION} libssl1.0.0

# ADD https://github.com/PowerShell/PSScriptAnalyzer/archive/${PSScriptAnalyzer_VERSION}.tar.gz /tmp/PSScriptAnalyzer.tar.gz
# RUN tar zxf /tmp/PSScriptAnalyzer.tar.gz -C /tmp/

# RUN cd /tmp/PSScriptAnalyzer-${PSScriptAnalyzer_VERSION} \
#     && pwsh -c "./buildCoreClr.ps1 -Framework netstandard2.0 -Configuration Release -Build"
