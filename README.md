# Grounds Development Infrastructure (grounds-dev) 🚀

A local development infrastructure that provisions a k3d Kubernetes cluster with PostgreSQL, Agones (game server hosting), and Open Match (matchmaking).

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
- **Open Match** for matchmaking in `games` namespace
- **Dummy HTTP server** for testing in `infra` namespace

## 🛠️ Essential Commands

| Command | Description |
|---------|-------------|
| `make up` | Start complete development environment |
| `make down` | Stop and delete the cluster |
| `make status` | Show cluster and deployment status |
| `make logs` | Show logs for all services |
| `make test` | Test the deployment |
| `make help` | Show all available commands |

### Development Helpers

| Command | Description |
|---------|-------------|
| `make port-forward` | Port forward services to localhost |
| `make db-connect` | Connect to PostgreSQL database |
| `make shell` | Open shell in PostgreSQL pod |

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

### Open Match Matchmaking
- **Namespace**: `games`
- **Services**: `open-match-frontend`, `open-match-backend`

```bash
# Check Open Match status
kubectl get pods -n games -l app.kubernetes.io/name=open-match
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