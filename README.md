# FIAP Tech Challenge 7SOAT - Tech Challenge #3

## Group #49 - Members

- Felipe José Cardoso de Sousa (Discord: **Felipe Sousa - RM355595**)
- Robson Batista da Silva (Discord: **Robson - RM356014**)
- Vinicius Pereira (Discord: **Vinicius Pereira - RM355809**)
- Henrique Perez Bego (Discord: **Henrique Bego - RM354844**)
- Breno Silva Sobral (Discord: **Breno - RM355234**)

## AWS API Gateway config and TechChallenge Azure AKS deployment

You need to have the Azure CLI installed in your local environment and also valid AWS credentials.

1. Use your credentials to log in to your azure account with `az login`
2. Ensure you're logged in requesting your AKS containers in Azure with: `az aks list`
3. If you receive a successful response, continue, otherwise make sure you're connected to the Azure CLI
4. Include the PostgreSQL database credentials using the commands `export TF_VAR_db_username="the-username"` and `export TF_VAR_db_password="the-password"`
5. Run `terraform apply`
6. Wait patiently
7. After "Apply complete!", look for the value k8s_service_ip in Outputs
8. Application Swagger should be running in `http://<_k8s_service_ip_>:3000/docs`, and the API Gateway should be ingesting inputs and hitting the Azure AKS app as expected
9. Run `terraform destroy` to shut down the infrastructure

