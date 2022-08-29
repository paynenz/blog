#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

ARG VERSION
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
ARG VERSION
WORKDIR /src
COPY ["BlogBackend/BlogBackend.csproj", "BlogBackend/"]
RUN dotnet restore "BlogBackend/BlogBackend.csproj"
COPY ["Tests/BlogBackendUnitTests/BlogBackendUnitTests.csproj", "Tests/BlogBackendUnitTests/"]
RUN dotnet restore "Tests/BlogBackendUnitTests/BlogBackendUnitTests.csproj"
COPY . .
WORKDIR "/src"
RUN dotnet build "BlogBackend/BlogBackend.csproj" -c Release /property:Version=$VERSION
RUN dotnet build "Tests/BlogBackendUnitTests/BlogBackendUnitTests.csproj" -c Release

FROM build AS test
RUN dotnet test "Tests/BlogBackendUnitTests/BlogBackendUnitTests.csproj" -c Release --logger:trx --no-build

FROM build AS publish
ARG VERSION
RUN dotnet publish "BlogBackend/BlogBackend.csproj" -c Release /property:Version=$VERSION -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "BlogBackend.dll"]
