# Pruebas Final - Estructura Simple

Proyecto simplificado de pruebas basado en App y organizado con estilo newCode + interfaces.

## Modulos

- manejadorDisponibilidad
- manejadorConfidencialidad
- manejadorIntegridad
- interfaces (utilidades compartidas)

## Infraestructura Terraform

La carpeta [Infraestructura](Infraestructura) contiene el despliegue completo copiado desde `newCode/despliegeCompleto/Infraestructura`.
Las semillas SQL están en [dataTest](dataTest) y se usan para cargar datos de usuarios, recursos y negocio.

### Ejecucion

```powershell
cd .\Infraestructura
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Si no tienes un `terraform.tfvars`, crea uno a partir de [terraform.tfvars.example](Infraestructura/terraform.tfvars.example) y completa los valores sensibles antes de ejecutar `apply`.

### Carga de datos

- [dataTest/bd_usuarios_data.sql](dataTest/bd_usuarios_data.sql)
- [dataTest/bd_recursos_data.sql](dataTest/bd_recursos_data.sql)
- [dataTest/bd_negocio_data.sql](dataTest/bd_negocio_data.sql)
 - [dataTest/bd_app_schema.sql](dataTest/bd_app_schema.sql)  # seed compatible con App (multi-tenant)

Ver instrucciones de ejecución (Terraform, seeds y Cloud Shell) en [COMO_CORRER_EN_CLOUDSHELL.md](COMO_CORRER_EN_CLOUDSHELL.md#L1).

### Pruebas

```bash
pytest
```

## Ejecucion rapida

```bash
python -m venv .venv
# Windows PowerShell
.\\.venv\\Scripts\\Activate.ps1
pip install -r requirements.txt
pytest
```

Ver Cloud Shell en COMO_CORRER_EN_CLOUDSHELL.md.
