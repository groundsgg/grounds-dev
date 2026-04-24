# Grounds Development Infrastructure (grounds-dev)

A local development infrastructure that provisions a k3d Kubernetes cluster with all necessary components to run the Grounds network.

## Platform Support

| Platform | Architecture | Status |
|----------|-------------|--------|
| Linux | x86_64 (amd64) | Supported |
| Linux | aarch64 (arm64) | Supported |
| macOS | Apple Silicon (arm64) | Supported |
| macOS | Intel (amd64) | Supported |
| WSL2 | x86_64 (amd64) | Supported |

All scripts auto-detect the OS and CPU architecture. Prerequisites are downloaded for the correct platform automatically.

**macOS requirements**: [Docker Desktop](https://www.docker.com/products/docker-desktop/) with Kubernetes resources allocated (recommended: 6 CPU, 8 GB RAM).

## Quick Start

```bash
# Clone and start everything
git clone <repository-url>
cd grounds-dev
make up
```

The `make up` command will automatically install missing prerequisites and deploy:
- **k3d Kubernetes cluster** (1 server + 2 agents)
- **PostgreSQL database** in `databases` namespace
- **Agones** for game server hosting in `games` namespace
- **Valkey** in `databases` namespace
- **NATS** in `infra` namespace
- **Keycloak** in `keycloak` namespace
- **Dummy HTTP server** for testing in `infra` namespace
- **API namespace** for API services and microservices

## Platform profile

The default `make up` brings up the core game-server dev env (PostgreSQL,
Agones, plugin deps). For platform-side work — building against
grounds-forge, the internal portal, or the CLI — layer the platform
profile on top:

```
make up-platform
```

This installs Zot, the vCluster operator, and `grounds-forge` (private
chart from `ghcr.io/groundsgg/charts/grounds-forge`).

**Prerequisites:**

- Base `make up` has succeeded (k3d cluster + postgres + plugin deps).
- Helm is logged into GHCR (the chart and image are private):
  ```
  echo $GHCR_PAT | helm registry login ghcr.io -u <github-user> --password-stdin
  ```
- The `grounds_forge` database exists in PostgreSQL (not created automatically):
  ```
  kubectl exec -n databases svc/postgresql -- \
    psql -U app -d app -c "CREATE DATABASE grounds_forge;"
  ```

**Deferred:** Keycloak realm import (`manifests/platform/keycloak-platform-realm.json`).
Add when you need to exercise `/v1/whoami`.

Once up, reach grounds-forge at `http://platform.localhost`.

## Authentication

### Docker Hub Authentication

To avoid image pull failures and rate limiting, set your Docker Hub credentials before creating the cluster:

```bash
# Set Docker Hub credentials
export DOCKER_USERNAME="your-dockerhub-username"
export DOCKER_PASSWORD="your-dockerhub-token"
```

**Security Note**: Use a Docker Hub access token instead of your password:
1. Go to Docker Hub -> Account Settings -> Security
2. Create a new access token
3. Use the token as `DOCKER_PASSWORD`

### GitHub Container Registry (GHCR) Authentication

To pull private images from GitHub Container Registry, configure your GHCR credentials in the `.env` file:

```bash
# Copy the example file and edit it
cp .env.example .env
# Edit .env and add your credentials
```

Add the following to your `.env` file:
```bash
GHCR_USERNAME=your-github-username
GHCR_TOKEN=your-github-personal-access-token
```

**Creating a GitHub Personal Access Token (PAT)**:
1. Go to GitHub -> Settings -> Developer settings -> Personal access tokens -> Tokens (classic)
2. Click "Generate new token (classic)"
3. Select the `read:packages` permission
4. Generate and copy the token
5. Add it to your `.env` file as `GHCR_TOKEN`

The bootstrap script automatically:
- Loads credentials from `.env` file
- Creates a global pull secret (`ghcr-pull-secret`) in all namespaces
- Configures all default service accounts to use the GHCR pull secret

This enables pulling private GHCR images without specifying `imagePullSecrets` in your Pod specs.

### GitHub Packages (Maven) Authentication

The GitHub token is also required for the self hosted Maven artifacts. Set these properties in `~/.gradle/gradle.properties`:

```properties
github.user=your-github-username
github.token=your-github-personal-access-token
```

The Maven repository configuration expects those properties:

```gradle
maven {
    url = uri("https://maven.pkg.github.com/groundsgg/<repository-name>")
    credentials {
        username = providers.gradleProperty("github.user").get()
        password = providers.gradleProperty("github.token").get()
    }
}
```

## Essential Commands

| Command | Description |
|---------|-------------|
| `make up` | Start complete development environment |
| `make down` | Stop and delete the cluster |
| `make reset` | Reset the cluster (down + up) |
| `make status` | Show cluster and deployment status |
| `make logs` | Show logs for all services |
| `make test` | Test the deployment |
| `make help` | Show all available commands |

### Development Helpers

| Command | Description |
|---------|-------------|
| `make port-forward` | Port forward services to localhost |
| `make certs` | Generate local TLS certificates with mkcert |
| `make trust-ca` | Install mkcert CA in Windows certificate store (WSL2 only) |
| `make deploy-keycloak` | Deploy Keycloak operator and instance |

## Quick Troubleshooting

```bash
# Check cluster status
kubectl get pods -A

# Check logs
make logs

# Restart everything
make reset
```

## Security Note

**Development only!** Default credentials (app/app) are used. Not for production.

## License

Licensed under the Apache License, Version 2.0.
