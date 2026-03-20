FROM mcr.microsoft.com/dotnet/sdk:10.0
WORKDIR /app
COPY . .
RUN dotnet build -c Release
ENTRYPOINT ["dotnet", "run", "--no-build", "-c", "Release", "--"]
