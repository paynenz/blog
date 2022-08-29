#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

ARG Version
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
ARG Version
WORKDIR /src
COPY ["BlogBackend/BlogBackend.csproj", "BlogBackend/"]
RUN dotnet restore "BlogBackend/BlogBackend.csproj"
COPY ["Tests/BlogBackendUnitTests/BlogBackendUnitTests.csproj", "Tests/BlogBackendUnitTests/"]
RUN dotnet restore "Tests/BlogBackendUnitTests/BlogBackendUnitTests.csproj"
COPY . .
WORKDIR "/src"
RUN dotnet build "BlogBackend/BlogBackend.csproj" -c Release /property:Version=$Version
RUN dotnet build "Tests/BlogBackendUnitTests/BlogBackendUnitTests.csproj" -c Release

FROM build AS test
RUN dotnet test "Tests/BlogBackendUnitTests/BlogBackendUnitTests.csproj" -c Release --logger:trx --no-build

FROM build AS publish
ARG Version
RUN dotnet publish "BlogBackend/BlogBackend.csproj" -c Release /property:Version=$Version -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "BlogBackend.dll"]
