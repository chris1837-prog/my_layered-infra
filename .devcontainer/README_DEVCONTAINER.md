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
| Terraform | 1.6.3 |
| AWS CLI | 2.27.25 |
| Python | 3.12 |
| Prettier | latest |
| Terraform VS Code Extension | latest |
| AWS Toolkit VS Code Extension | latest |

---

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
> “Reopen in Container”  
```
Click **Yes** or **Reopen in Container**.

5. **Wait until the container finishes building.**  
When ready, check the installed tools:
```
node -v
terraform -v
aws --version
```
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
This ensures the same setup works for all developers without manual installation.