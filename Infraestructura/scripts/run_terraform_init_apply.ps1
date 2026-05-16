param(
    [string]$TfDir = ".",
    [string]$VarFile = "terraform.tfvars",
    [switch]$AutoApprove
)

Write-Host "Running Terraform init in $TfDir"
Push-Location $TfDir
try {
    terraform init -input=false
    $planCmd = "terraform plan -var-file=$VarFile -out=tfplan"
    Write-Host "-> $planCmd"
    terraform plan -var-file=$VarFile -out=tfplan
    if ($AutoApprove) {
        terraform apply -input=false -auto-approve tfplan
    } else {
        terraform apply -input=false tfplan
    }
} finally {
    Pop-Location
}
