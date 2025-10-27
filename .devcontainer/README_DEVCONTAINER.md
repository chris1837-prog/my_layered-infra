## 🧱 Devcontainer Setup

This project includes a ready-to-use **VS Code Devcontainer** configuration for local development.

### 📂 Location

The configuration is located at:
```
.devcontainer/devcontainer.json
```

It uses the existing Docker Compose setup from:
```
mvp-compose/docker-compose.yml
```

---

### ⚙️ Tools installed automatically inside the Devcontainer

| Tool | Version |
|------|----------|
| Node.js | 20.x |
| Terraform | ~> 1.12.0 (1.12.2) |
| AWS CLI | 2.31.18 |
| Prettier | 3.6.x |
| Terraform VS Code Extension | latest |
| AWS Toolkit VS Code Extension | latest |

---

### 🐧 Base image

The Devcontainer uses Debian Slim as the base image (from node:20-slim) to provide a lightweight yet stable development environment.


### 🚀 How to use the Devcontainer (VS Code)

1. **Install Docker Desktop**  
   Make sure Docker is running before continuing.

2. **Install the Dev Containers extension in VS Code**

→ [VS Code Marketplace: Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

3. **Open the project folder in VS Code:**
```
    File → Open Folder → layered-infra
```

4. **VS Code will prompt you:**
```  
> “Reopen in Container”  or "Rebuild and Reopen in Container"
```
Click **Yes** or **Reopen in Container**.

5. **Wait until the container finishes building.**  
When ready, check the installed tools:
```
node -v
terraform -v
aws --version
```
 **Check Prettier installation**

Prettier is installed as a local development dependency and will be automatically available inside the Dev Container after running `npm ci`.

To verify that Prettier is correctly installed and available, run the following command inside the Dev Container terminal:

```bash
npx prettier --version
```
Expected ouput (exemple): 3.6.2

You now have a complete, reproducible local environment running inside Docker! 🐳


### 🧹 Cleanup (optional)

To stop and remove all containers:
```
docker compose -f mvp-compose/docker-compose.yml down
```


### 🧑‍💻 Development Notes

All commands run inside the container environment.
The working directory inside the container is:
```
/usr/src/app
```
This ensures that every developer works in the exact same Debian Slim environment with consistent tools and configurations.