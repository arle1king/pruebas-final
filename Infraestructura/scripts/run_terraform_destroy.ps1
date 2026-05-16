param(
    [string]$TfDir = ".",
    [string]$VarFile = "terraform.tfvars",
    [switch]$AutoApprove
)

Write-Host "Running Terraform destroy in $TfDir"
Push-Location $TfDir
try {
    terraform init -input=false
    if ($AutoApprove) {
        terraform destroy -var-file=$VarFile -auto-approve
    } else {
        terraform destroy -var-file=$VarFile
    }
} finally {
    Pop-Location
}
