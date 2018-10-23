FROM microsoft/dotnet:2.1.403-sdk-alpine3.7 as dotnet-alpine
FROM mcr.microsoft.com/powershell:6.1.0-rc.1-alpine-3.8 as builder

ARG PSSCRIPTANALYZER_VERSION=development

# Add dotnet to builder
COPY --from=dotnet-alpine /usr/share/dotnet /usr/share/dotnet
RUN ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

ADD https://github.com/PowerShell/PSScriptAnalyzer/archive/${PSSCRIPTANALYZER_VERSION}.tar.gz /tmp/PSScriptAnalyzer.tar.gz
RUN mkdir /tmp/PSScriptAnalyzer \
    && tar zxf /tmp/PSScriptAnalyzer.tar.gz --strip-components=1 -C /tmp/PSScriptAnalyzer

WORKDIR /tmp/PSScriptAnalyzer
RUN /opt/microsoft/powershell/6-preview/pwsh -c "./buildCoreClr.ps1 -Framework netstandard2.0 -Configuration Release -Build"

######################################################
# FINAL IMAGE
######################################################
FROM base-powershell

COPY --from=builder /tmp/PSScriptAnalyzer/out/ /opt/microsoft/powershell/6-preview/Modules/
USER ${USER}
ENTRYPOINT ["/opt/microsoft/powershell/6-preview/pwsh", "-C", "Invoke-ScriptAnalyzer"]