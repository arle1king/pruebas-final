from pathlib import Path

import pytest


ROOT_DIR = Path(__file__).resolve().parents[1]
INFRA_DIR = ROOT_DIR / "Infraestructura"
DATA_DIR = ROOT_DIR / "dataTest"


@pytest.mark.unit
def test_terraform_files_exist_and_reference_aws_resources():
    main_tf = INFRA_DIR / "main.tf"
    variables_tf = INFRA_DIR / "variables.tf"

    assert main_tf.exists(), "Falta Infraestructura/main.tf"
    assert variables_tf.exists(), "Falta Infraestructura/variables.tf"

    main_content = main_tf.read_text(encoding="utf-8")
    variables_content = variables_tf.read_text(encoding="utf-8")

    assert 'terraform {' in main_content
    assert 'provider "aws"' in main_content
    assert 'resource "aws_vpc" "main"' in main_content
    assert 'variable "project_prefix"' in variables_content
    assert 'variable "db_user"' in variables_content


@pytest.mark.unit
@pytest.mark.parametrize(
    ("file_name", "expected_tables"),
    [
            ("bd_usuarios_data.sql", ["usuario", "usuario_permiso", "usuario_area"]),
            ("bd_recursos_data.sql", ["recurso_cloud"]),
            ("bd_negocio_data.sql", ["empresa_contratante", "proyecto"]),
            ("bd_app_schema.sql", ["public.tenants", "empresa_a.consumo_cloud", "public.reportes"]),
    ],
)
def test_sql_seed_files_are_present_and_populated(file_name, expected_tables):
    sql_path = DATA_DIR / file_name

    assert sql_path.exists(), f"Falta {file_name}"

    content = sql_path.read_text(encoding="utf-8")
    assert "INSERT INTO" in content

    for table_name in expected_tables:
        assert f"INSERT INTO {table_name} " in content
