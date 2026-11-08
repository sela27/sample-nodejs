# **DevOps/DevSecOps Challenge: Show Us Your Skills!** 

Hey there! We’re excited to see what you can do. For this task, we want you to showcase your DevOps skills by creating (or forking) a sample app and setting up a solid CI/CD pipeline. 

### **Helm Chart:** 

- Write or modify a **Helm chart** for your app, so we can easily deploy it to Kubernetes. 

- Choose between **Deployment** or **StatefulSet** —based on the nature of your app. Let us know why you made your choice. 

- **Maximize the use of Kubernetes manifest features** : 

   - **readiness and liveness probes** to ensure your app’s health. 

   - Service and Ingress. 

   - Consider adding **resource limits or/and requests** for CPU and memory. 

   - Add any other configurations you fit (secrets, config maps, etc.). 

### **CI/CD Pipeline:** 

- Build a **CI/CD pipeline** using your favorite tool ( **Jenkins** , **GitHub Actions** , etc.), and make sure it demonstrates key DevOps and DevSecOps best practices. Here’s what we want to see: 

**1. Version Bumping:** 

   - Choose your git workflow. 

**2. DevSecOps (Security Checks):** 

The pipeline should conduct security checks to ensure your app and its dependencies are safe. Here’s what we want: 

- **SAST (Static Application Security Testing):** 

   - Use a tool from this list Link (https://community.owasp.org/Source_Code_Analysis_Tools) or others you prefer. 

   - The pipeline should fail if any critical vulnerabilities are found in the code. 

- **Vulnerability Scanning (Docker Image):** 

   - Scan the Docker image for vulnerabilities using tools like **Trivy** , 

   - Block deployment if any high-severity vulnerabilities are discovered. 

- **Bonus (Optional):** 

   - You can integrate any tool you see necessary. 

### **3. Build and Dockerization:** 

- The pipeline should **build the app** and ensure It’s properly dockerized using your **Dockerfile** . 

- You can choose a tool like **Kaniko BuildKit** or plain **Docker** for image building. Ensure the pipeline builds and pushes the Docker image to a **private registry** of your choice (e.g., **Docker Hub** , **AWS ECR** , **GCP** , etc.). 

### **4. Deployment Stage:** 

- Deploy your app to Kubernetes as part of the pipeline. 

- **ArgoCD & GitOps Practices:** 

   - Use **ArgoCD** to deploy your app using **declarative Kubernetes manifests** . 

   - Follow **GitOps practices** by integrating ArgoCD into the pipeline. Choose between: 

      1. A separate GitOps repository monitored by ArgoCD for changes. 

      2. ArgoCD pulls manifests directly from your app’s repository. 

   - Let us know why you chose your preferred method. 

- Ensure the app is deployed successfully to your Kubernetes cluster (you can use **Helm** to manage this). 

## 5. **Completion:** 

Upon finishing your assignment, we expect to receive: 

- Links to your Git repository/repositories. 

- The repositories should include the Helm chart, pipelines, and any other relevant manifests you find necessary. 

- Access to your Kubernetes cluster or screenshots that validate the application is running (e.g., browser access to the main path using Ingress, etc.). 

# **We Can’t Wait to See What You Built!** 

This is your chance to show off your DevOps and DevSecOps skills. We are looking forward to seeing how you tackle this challenge and welcome any suggestions or alterations you see fit. We are excited to see your approach ! 

