# Como correr en Cloud Shell

## 1) Entrar al proyecto

```bash
cd ~/pruebas/puebas-final
```

## 2) Crear entorno e instalar dependencias

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## 3) Ejecutar pruebas unitarias

```bash
pytest
```

## 4) Ejecutar integration (AWS/endpoints reales)

```bash
export AWS_DEFAULT_REGION=us-east-1
export RUN_AWS_INTEGRATION=1
export HEALTH_ENDPOINT_URL="https://tu-endpoint/health/"  # opcional
pytest --run-aws
```

## 5) Script rapido

```bash
chmod +x run_tests.sh
./run_tests.sh
```
