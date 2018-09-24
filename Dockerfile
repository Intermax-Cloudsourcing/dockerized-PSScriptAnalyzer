######################################################
# BUILDING PSScriptAnalyzer
######################################################
FROM mcr.microsoft.com/powershell:6.1.0-rc.1-ubuntu-18.04 as powershell-ubuntu

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
 LC_ALL=en_US.UTF-8 \
 LANG=en_US.UTF-8

# Opt out from .NET Core tools telemetry
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

ARG PSScriptAnalyzer_VERSION=1.17.1
ARG SDK_VERSION=2.1.202

RUN apt-get update \
    && apt-get install -y dotnet-sdk-${SDK_VERSION} libssl1.0.0

ADD https://github.com/PowerShell/PSScriptAnalyzer/archive/${PSScriptAnalyzer_VERSION}.tar.gz /tmp/PSScriptAnalyzer.tar.gz
RUN mkdir /tmp/PSScriptAnalyzer \
    && tar zxf /tmp/PSScriptAnalyzer.tar.gz --strip-components=1 -C /tmp/PSScriptAnalyzer

RUN cd /tmp/PSScriptAnalyzer \
 && /opt/microsoft/powershell/6-preview/pwsh -c "./buildCoreClr.ps1 -Framework netstandard2.0 -Configuration Release -Build"

######################################################
# ADD to powershell base image
######################################################
FROM base-powershell

COPY --from=powershell-ubuntu /tmp/PSScriptAnalyzer/out/PSScriptAnalyzer /opt/microsoft/powershell/6-preview/Modules/
ENTRYPOINT ["/opt/microsoft/powershell/6-preview/pwsh"]
