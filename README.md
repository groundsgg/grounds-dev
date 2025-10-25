# Grounds Development Infrastructure (grounds-dev) 🚀

A local development infrastructure that provisions a k3d Kubernetes cluster with PostgreSQL and Agones (game server hosting).

## 🎯 Quick Start

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
- **Dummy HTTP server** for testing in `infra` namespace
- **API namespace** for API services and microservices

## 🔐 Docker Hub Authentication

To avoid image pull failures and rate limiting, set your Docker Hub credentials before creating the cluster:

```bash
# Set Docker Hub credentials
export DOCKER_USERNAME="your-dockerhub-username"
export DOCKER_PASSWORD="your-dockerhub-token"
```

**Security Note**: Use a Docker Hub access token instead of your password:
1. Go to Docker Hub → Account Settings → Security
2. Create a new access token
3. Use the token as `DOCKER_PASSWORD`

## 🛠️ Essential Commands

| Command | Description |
|---------|-------------|
| `make up` | Start complete development environment |
| `make down` | Stop and delete the cluster |
| `make status` | Show cluster and deployment status |
| `make logs` | Show logs for all services |
| `make test` | Test the deployment |
| `make export-kubeconfig` | Export cluster kubeconfig to ./kubeconfig |
| `make help` | Show all available commands |

### Development Helpers

| Command | Description |
|---------|-------------|
| `make port-forward` | Port forward services to localhost |
| `make db-connect` | Connect to PostgreSQL database |
| `make shell` | Open shell in PostgreSQL pod |

### Kubeconfig Access

The cluster kubeconfig is automatically exported to `./kubeconfig` during setup.

```bash
# Use the local kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes

# Or manually re-export
make export-kubeconfig
```

## 🌐 Service Access

### PostgreSQL Database
- **Namespace**: `databases`
- **Credentials**: `app/app`
- **Database**: `app`
- **Port**: `5432`

```bash
# Connect to database
make db-connect

# Port forward to access locally
kubectl port-forward -n databases svc/postgresql 5432:5432
```

### Agones Game Server Platform
- **Namespace**: `games`
- **CRDs**: `fleets.agones.dev`, `gameservers.agones.dev`

```bash
# Check Agones status
kubectl get fleets -n games
kubectl get gameservers -n games
```


### API Services
- **Namespace**: `api`
- **Purpose**: Host API services and microservices

```bash
# Deploy API services to the api namespace
kubectl apply -f manifests/ -n api

# Check API services
kubectl get pods -n api
kubectl get services -n api
```

### Dummy HTTP Server (Testing)
- **URL**: http://localhost/demo
- **Namespace**: `infra`

```bash
# Test the server
curl http://localhost/demo
```

## 🐛 Quick Troubleshooting

```bash
# Check cluster status
kubectl get pods -A

# Check logs
make logs

# Restart everything
make down && make up
```

## 🔒 Security Note

⚠️ **Development only!** Default credentials (app/app) are used. Not for production.