plan:
	terraform validate
	terraform plan -out=terraform.tfplan

lintfix:
	terraform validate
	terraform fmt -recursive

lint:
	terraform validate
	terraform fmt -recursive -check
	tflint --deep --module

apply:
	terraform validate
	terraform apply "terraform.tfplan"