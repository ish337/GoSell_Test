# Learn about building .NET container images:
# https://github.com/dotnet/dotnet-docker/blob/main/samples/README.md

# ── Stage 1: Restore dependencies (cached unless csproj files change) ────────
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS restore
WORKDIR /source

COPY ["OLX.API/OLX.API.csproj", "OLX.API/"]
COPY ["Olx.BLL/Olx.BLL.csproj", "Olx.BLL/"]
COPY ["Olx.DAL/Olx.DAL.csproj", "Olx.DAL/"]
RUN dotnet restore "OLX.API/OLX.API.csproj"

# ── Stage 2: Build & publish ─────────────────────────────────────────────────
FROM restore AS build
COPY . .
WORKDIR /source/OLX.API
RUN dotnet publish -c Release -o /app --no-restore

# ── Stage 3: Runtime image (cached unless Dockerfile changes) ────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Install postgresql-client in a cached layer
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        wget gnupg lsb-release \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -c | awk '{print $2}')-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client-17 \
    && apt-get purge -y wget gnupg lsb-release \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app .
ENTRYPOINT ["dotnet", "OLX.API.dll"]
