# Cómo correr (Cloud Shell, local Windows PowerShell y Bash)

Este documento centraliza cómo ejecutar Terraform por "prueba" (módulo/directorio), aplicar seeds SQL y correr tests.

Resumen rápido:

- En Windows: use los scripts PowerShell bajo `Infraestructura/scripts`.
- En Linux/Cloud Shell: siga las instrucciones Bash que se muestran abajo.

---

## Preparación (común)

1. Clona el repo y sitúate en la carpeta `pruebas-final`.

```bash
git clone <repo>
cd pruebas-final
```

2. (Opcional) Crear entorno Python e instalar dependencias para tests:

```bash
# Linux / Cloud Shell
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Windows PowerShell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install --upgrade pip
pip install -r requirements.txt
```

---

## Ejecutar Terraform por "prueba" (módulo o directorio)

La idea de "prueba" aquí es ejecutar Terraform en un directorio específico del despliegue (por ejemplo, el root `Infraestructura` o un submódulo). Use los scripts proporcionados o los comandos directos de Terraform.

1) Ejecución completa (root `Infraestructura`) — PowerShell (Windows):

```powershell
cd pruebas-final\Infraestructura
..\Infraestructura\scripts\run_terraform_init_apply.ps1 -TfDir . -VarFile terraform.tfvars -AutoApprove
```

Equivalente en Bash (Cloud Shell / Linux):

```bash
cd pruebas-final/Infraestructura
terraform init -input=false
terraform plan -var-file=terraform.tfvars -out=tfplan
terraform apply -input=false tfplan
```

2) Ejecutar un módulo o carpeta específica

- Si tienes módulos en `Infraestructura/modules/<modulo>`, entra en ese directorio y ejecuta los mismos pasos (o pasa `-TfDir` apuntando al módulo):

```powershell
cd pruebas-final\Infraestructura\modules\<modulo>
..\..\scripts\run_terraform_init_apply.ps1 -TfDir . -VarFile ..\terraform.tfvars -AutoApprove
```

o en Bash:

```bash
cd pruebas-final/Infraestructura/modules/<modulo>
terraform init -input=false
terraform plan -var-file=../terraform.tfvars -out=tfplan
terraform apply -input=false tfplan
```

3) Destruir (cleanup)

PowerShell:

```powershell
..\Infraestructura\scripts\run_terraform_destroy.ps1 -TfDir . -VarFile terraform.tfvars -AutoApprove
```

Bash:

```bash
terraform destroy -var-file=terraform.tfvars -auto-approve
```

---

## Obtener outputs para aplicar seeds

Después de `apply`, Terraform imprime `outputs` (o use `terraform output -json`). Necesitas la información de conexión a la base de datos (host/puerto/usuario/contraseña/nombre DB). Ejemplo:

```bash
terraform output db_host
terraform output db_port
terraform output db_user
terraform output db_password
```

Usar esos valores para aplicar el seed con `psql` (Bash) o con el script PowerShell `apply_sql_seed.ps1`.

PowerShell (local):

```powershell
..\Infraestructura\scripts\apply_sql_seed.ps1 -Host <DB_HOST> -Port 5432 -User <DB_USER> -Password <DB_PASSWORD> -Db <DB_NAME> -SqlFile ..\dataTest\bd_app_schema.sql
```

Bash (Cloud Shell):

```bash
PGPASSWORD="<DB_PASSWORD>" psql -h <DB_HOST> -p 5432 -U <DB_USER> -d <DB_NAME> -f dataTest/bd_app_schema.sql
```

---

## Ejecutar pruebas (pytest)

Unitarios (local):

```bash
source .venv/bin/activate  # o Activate.ps1 en Windows
pytest
```

Integración contra infra desplegada (si corresponde):

```bash
export RUN_AWS_INTEGRATION=1
pytest --run-aws
```

---

## Explicación paso a paso (qué hace cada comando)

- `terraform init`: inicializa providers y backend. Siempre antes de plan/apply.
- `terraform plan -var-file=... -out=tfplan`: crea un plan reproducible y lo guarda en `tfplan`.
- `terraform apply tfplan`: aplica el plan guardado (evita cambios inesperados).
- `terraform destroy`: elimina los recursos creados.
- `apply_sql_seed.ps1` / `psql -f`: cargan los archivos SQL en la DB. Necesitas las credenciales y host que Terraform creó/retornó.

---

Si quieres, genero también versiones equivalentes de los scripts en Bash para integrarlo en Cloud Shell automáticamente. ¿Las quieres? 
