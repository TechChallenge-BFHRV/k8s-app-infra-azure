## AWS API Gateway config and TechChallenge Azure AKS deployment

You need to have the Azure CLI installed in your local environment and also valid AWS credentials.

1. Use your credentials to log in to your azure account with `az login`
2. Ensure you're logged in requesting your AKS containers in Azure with: `az aks list`
3. If you receive a successful response, continue, otherwise make sure you're connected to the Azure CLI
4. Run `terraform apply`
5. Wait patiently
6. Run `echo "$(terraform output kube_config)" > ./azurek8s`
7. Ensure your new `azurek8s` file does not have any "EOT" strings in it. If it does, remove the lines where they appear
8. Run `export KUBECONFIG=./azurek8s`
9. Run `kubectl get nodes` to ensure kubernetes is running properly on AKS. You should see a machine listed in your terminal with Ready STATUS.
10. Run `kubectl apply -f k8s/postgres-deployment.yaml`
11. Run `kubectl apply -f k8s/redis-deployment.yaml`
12. Run `kubectl apply -f k8s/deployment.yaml`
13. Run `kubectl apply -f k8s/service.yaml`
14. Run `kubectl get services` and use the `EXTERNAL-IP` address of the `techchallenge-k8s LoadBalancer` in the following format: `http://external-ip-address:3000/docs` in your browser
15. You are now accessing the cleanarch-techchallenge Swagger
16. Run `terraform destroy` to shut down the infrastructure
