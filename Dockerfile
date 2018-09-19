######################################################
# USE POWERSHELL IMAGE FOR BUILDING PSScriptAnalyzer
######################################################
FROM microsoft/powershell:latest as builder

# Opt out from .NET Core tools telemetry
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

ARG PSScriptAnalyzer_VERSION=1.17.1
ARG SDK_VERSION=2.1.202

RUN apt-get update \
    && apt-get install -y dotnet-sdk-${SDK_VERSION} libssl1.0.0

RUN mkdir PSScriptAnalyzer
WORKDIR PSScriptAnalyzer

RUN curl -L https://github.com/PowerShell/PSScriptAnalyzer/archive/${PSScriptAnalyzer_VERSION}.tar.gz | \
    tar -zxC "." --strip-components=1

RUN pwsh -c "./buildCoreClr.ps1 -Framework netstandard2.0 -Configuration Release -Build"

######################################################
# BUILD MINIMAL POWERSHELL LINT IMAGE
######################################################
FROM scratch
LABEL maintainer="Wilmar den Ouden <wilmaro@intermax.nl>"

# Copy binary
COPY --from=builder /opt/microsoft/powershell/6/ /opt/microsoft/powershell/6/

# Copy libraries found with ldd
COPY --from=builder /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/
COPY --from=builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/
COPY --from=builder "/usr/lib/x86_64-linux-gnu/libstdc++.so.6" /usr/lib/x86_64-linux-gnu/
COPY --from=builder /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/
COPY --from=builder /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib/x86_64-linux-gnu/
COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/
COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/

# ICU needed for globalization
COPY --from=builder /usr/lib/x86_64-linux-gnu/libicudata.so.55.1 /usr/lib/x86_64-linux-gnu/libicudata.so.55
COPY --from=builder /usr/lib/x86_64-linux-gnu/libicui18n.so.55.1 /usr/lib/x86_64-linux-gnu/libicui18n.so.55
COPY --from=builder /usr/lib/x86_64-linux-gnu/libicuuc.so.55.1 /usr/lib/x86_64-linux-gnu/libicuuc.so.55

# SSL libs
COPY --from=builder /lib/x86_64-linux-gnu/libcrypto.so.1.0.0 /lib/x86_64-linux-gnu/
COPY --from=builder /lib/x86_64-linux-gnu/libssl.so.1.0.0 /lib/x86_64-linux-gnu/

# PSScriptAnalyzer
COPY --from=builder PSScriptAnalyzer/out/ /opt/microsoft/powershell/6/Modules/

ENTRYPOINT ["/opt/microsoft/powershell/6/pwsh", "-C"]
CMD ["Get-ScriptAnalyzerRule"]