#==== Build Stage ====
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Install Playwright system dependencies
RUN apt-get update -q && \
    apt-get install -y -qq --no-install-recommends \
        xvfb \
        libxcomposite1 \
        libxdamage1 \
        libatk1.0-0 \
        libasound2 \
        libdbus-1-3 \
        libnspr4 \
        libgbm1 \
        libatk-bridge2.0-0 \
        libcups2 \
        libxkbcommon0 \
        libatspi2.0-0 \
        libnss3 \
        libpango-1.0-0 \
        libcairo2 \
        libxrandr2 \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the backend project file
COPY backend.csproj .

# Restore dependencies
RUN dotnet restore

# Copy the entire backend source directory
COPY . .

# Install Playwright CLI tool (SDK available here)
RUN dotnet tool install --global Microsoft.Playwright.CLI

# Add Playwright tools to PATH
ENV PATH="${PATH}:/root/.dotnet/tools"

# Install Playwright browsers
RUN playwright install chromium

# Build and publish
RUN dotnet publish backend.csproj -c Release -o /app/publish

#==== Runtime Stage ====
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

# Install Playwright system dependencies (needed to RUN browsers)
RUN apt-get update -q && \
    apt-get install -y -qq --no-install-recommends \
        xvfb \
        libxcomposite1 \
        libxdamage1 \
        libatk1.0-0 \
        libasound2 \
        libdbus-1-3 \
        libnspr4 \
        libgbm1 \
        libatk-bridge2.0-0 \
        libcups2 \
        libxkbcommon0 \
        libatspi2.0-0 \
        libnss3 \
        libpango-1.0-0 \
        libcairo2 \
        libxrandr2 \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Playwright browsers from build stage
COPY --from=build /root/.cache/ms-playwright /root/.cache/ms-playwright

# Copy Playwright CLI tool from build stage
COPY --from=build /root/.dotnet/tools /root/.dotnet/tools

# Add Playwright tools to PATH
ENV PATH="${PATH}:/root/.dotnet/tools"

# Copy published app
COPY --from=build /app/publish .

# Expose port
EXPOSE 5000
ENV ASPNETCORE_URLS=http://+:5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run the application
ENTRYPOINT ["dotnet", "backend.dll"]
