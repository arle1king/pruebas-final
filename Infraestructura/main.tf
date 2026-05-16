# ============================================
# DESPLIEGUE COMPLETO - INFRAESTRUCTURA INTEGRADA
# ============================================
#
# Este módulo integra TODOS los componentes:
# - Kong (broker API) en puertos 8000/8001 (ÚNICO punto de acceso)
# - Servidor Web A (Reportes)
# - Servidor Web B (Autenticación)
# - Servidor Web C (Empresa)
# - Base de Datos de Recursos
# - Base de Datos de Usuarios
# - Base de Datos de Negocio
# - Extractor de datos AWS
# 
# Arquitectura de RED:
# [Usuario] ──HTTPS:8000/8001──> [Kong :8000/:8001]
#                                      │
#                    ┌─────────────────┼─────────────────┐
#                    ▼                 ▼                 ▼
#              [Web A :8080]    [Web B :8080]    [Web C :8080]
#                    │                 │                 │
#                    └─────────┬───────┴─────────┬───────┘
#                              │
#            ┌─────────────────┼─────────────────┐
#            ▼                 ▼                 ▼
#       [BD Recursos]    [BD Usuarios]    [BD Negocio]
#           (5432)          (5432)           (5432)
#
# [Extractor] ─────> [BD Recursos]


# ============================================
# TERRAFORM CONFIGURATION
# ============================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}


# ============================================
# LOCAL VALUES
# ============================================

locals {
  project_name = "${var.project_prefix}-despliegue-completo"

  common_tags = {
    Project     = local.project_name
    Modulo      = "Despliegue Completo"
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}


# ============================================
# DATA SOURCES
# ============================================

# Obtener AMI de Ubuntu 24.04 más reciente
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# ============================================
# VPC Y NETWORKING
# ============================================

resource "aws_vpc" "main" {
  cidr_block           = "10.3.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-vpc"
  })
}







# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-igw"
  })
}

# Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-rt"
  })
}

# Subnets
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.3.1.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-subnet-1"
  })
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.3.2.0/24"
  availability_zone       = "us-east-1d"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-subnet-2"
  })
}

# Asociar Route Table a Subnets
resource "aws_route_table_association" "subnet_1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.main.id
}


# ============================================
# SECURITY GROUPS
# ============================================

# SG: Kong API Gateway (puertos 8000 y 8001 - ÚNICO punto de acceso público)
resource "aws_security_group" "dc_traffic_kong" {
  name_prefix = "${var.project_prefix}-traffic-kong"
  description = "Permite trafico HTTPS en puertos 8000/8001 hacia Kong (unico punto de acceso)"
  vpc_id      = aws_vpc.main.id

  # Kong Admin API
  ingress {
    description = "Kong Admin API"
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  

  # Kong Proxy
  ingress {
    description = "Kong Proxy HTTPS"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH para administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # En dc_traffic_kong security group:


  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-dc-traffic-kong"
  })
}


# SG: Servidores Web (puerto 8080 - SOLO desde Kong, no públicamente)
resource "aws_security_group" "dc_traffic_django" {
  name_prefix = "${var.project_prefix}-traffic-django"
  description = "Permite trafico HTTP puerto 8080 SOLO desde Kong"
  vpc_id      = aws_vpc.main.id

  # Tráfico solo desde Kong
  ingress {
    description     = "HTTP desde Kong"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.dc_traffic_kong.id]
  }

  ingress {
    description = "SSH para administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Trafico hacia kong
egress {
  description     = "Salida hacia Kong API"
  from_port       = 8000
  to_port         = 8001
  protocol        = "tcp"
  security_groups = [aws_security_group.dc_traffic_kong.id]
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-dc-traffic-django"
  })
}

resource "aws_security_group_rule" "kong_from_django" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.dc_traffic_django.id
  security_group_id        = aws_security_group.dc_traffic_kong.id
  description              = "Respuestas desde Django a Kong"
}

# SG: Extractor de datos (puerto 8081 - acceso egress a AWS, conexión a BD)
resource "aws_security_group" "dc_traffic_extractor" {
  name_prefix = "${var.project_prefix}-traffic-extractor"
  description = "Permite trafico para extractor de datos AWS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH para administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-dc-traffic-extractor"
  })
}


# SG: Base de datos de recursos (puerto 5432)
resource "aws_security_group" "dc_traffic_db_recursos" {
  name_prefix = "${var.project_prefix}-traffic-db-recursos"
  description = "PostgreSQL para BD de recursos"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL desde Web A"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.dc_traffic_django.id]
  }

  ingress {
    description     = "PostgreSQL desde Extractor"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.dc_traffic_extractor.id]
  }

  ingress {
    description = "SSH para administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-dc-traffic-db-recursos"
  })
}


# SG: Base de datos de usuarios (puerto 5432)
resource "aws_security_group" "dc_traffic_db_usuarios" {
  name_prefix = "${var.project_prefix}-traffic-db-usuarios"
  description = "PostgreSQL para BD de usuarios"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL desde Web B"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.dc_traffic_django.id]
  }

  ingress {
    description = "SSH para administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-dc-traffic-db-usuarios"
  })
}


# SG: Base de datos de negocio (puerto 5432)
resource "aws_security_group" "dc_traffic_db_negocio" {
  name_prefix = "${var.project_prefix}-traffic-db-negocio"
  description = "PostgreSQL para BD de negocio"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL desde Web C"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.dc_traffic_django.id]
  }

  ingress {
    description = "SSH para administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-dc-traffic-db-negocio"
  })
}


# SG: Acceso SSH (definido para completitud)
resource "aws_security_group" "dc_traffic_ssh" {
  name_prefix = "${var.project_prefix}-traffic-ssh"
  description = "Permite acceso SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH para administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-dc-traffic-ssh"
  })
}


# ============================================
# BASE DE DATOS DE RECURSOS (PostgreSQL)
# ============================================

resource "aws_instance" "dc_database_recursos" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_db
  vpc_security_group_ids = [aws_security_group.dc_traffic_db_recursos.id]
  subnet_id              = aws_subnet.subnet_2.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  user_data = <<-EOT
#!/bin/bash
set -e
set -x
exec > /var/log/user-data.log 2>&1

echo "=========================================="
echo "INSTALANDO BD DE RECURSOS"
echo "=========================================="

              sudo apt-get update -y
              sudo apt-get upgrade -y
              sudo apt-get install -y postgresql postgresql-contrib

              sudo systemctl start postgresql
              sudo systemctl enable postgresql

              # ESPERAR a que PostgreSQL esté listo para aceptar conexiones
              echo "Esperando a que PostgreSQL esté listo..."
              until sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; do
                echo "PostgreSQL no listo... esperando 5s"
                sleep 5
              done
              echo "PostgreSQL está listo."

              sudo -u postgres psql -c "CREATE USER ${var.db_user} WITH PASSWORD '${var.db_password_recursos}' SUPERUSER;" 2>/dev/null || true
              sudo -u postgres createdb -O ${var.db_user} ${var.db_name_recursos} 2>/dev/null || true


              PG_CONF="/etc/postgresql/16/main/postgresql.conf"
              PG_HBA="/etc/postgresql/16/main/pg_hba.conf"

              sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF
              sudo sed -i "s/#shared_buffers = 128MB/shared_buffers = 512MB/" $PG_CONF
              sudo sed -i "s/#work_mem = 4MB/work_mem = 16MB/" $PG_CONF
              sudo sed -i "s/#max_connections = 100/max_connections = 200/" $PG_CONF
              echo "host all all 0.0.0.0/0 md5" | sudo tee -a $PG_HBA


              sudo systemctl restart postgresql

              echo "BD de Recursos instalada"
              EOT

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-database-recursos"
    Role = "database-recursos"
  })

  depends_on = [aws_internet_gateway.main]
}


# ============================================
# BASE DE DATOS DE USUARIOS (PostgreSQL)
# ============================================

resource "aws_instance" "dc_database_usuarios" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_db
  vpc_security_group_ids = [aws_security_group.dc_traffic_db_usuarios.id]
  subnet_id              = aws_subnet.subnet_2.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  user_data = <<EOT
#!/bin/bash
set -e
set -x
exec > /var/log/user-data.log 2>&1

echo "=========================================="
echo "INSTALANDO BD DE USUARIOS"
echo "=========================================="

              sudo apt-get update -y
              sudo apt-get upgrade -y
              sudo apt-get install -y postgresql postgresql-contrib

              sudo systemctl start postgresql
              sudo systemctl enable postgresql

              # ESPERAR a que PostgreSQL esté listo para aceptar conexiones
              echo "Esperando a que PostgreSQL esté listo..."
              until sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; do
                echo "PostgreSQL no listo... esperando 5s"
                sleep 5
              done
              echo "PostgreSQL está listo."



              sudo -u postgres psql -c "CREATE USER ${var.db_user} WITH PASSWORD '${var.db_password_usuarios}' SUPERUSER;" 2>/dev/null || true
              sudo -u postgres createdb -O ${var.db_user} ${var.db_name_usuarios} 2>/dev/null || true


              PG_CONF="/etc/postgresql/16/main/postgresql.conf"
              PG_HBA="/etc/postgresql/16/main/pg_hba.conf"

              sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF
              sudo sed -i "s/#shared_buffers = 128MB/shared_buffers = 512MB/" $PG_CONF
              sudo sed -i "s/#work_mem = 4MB/work_mem = 16MB/" $PG_CONF
              sudo sed -i "s/#max_connections = 100/max_connections = 200/" $PG_CONF
              echo "host all all 0.0.0.0/0 md5" | sudo tee -a $PG_HBA

            

              sudo systemctl restart postgresql

              echo "BD de Usuarios instalada"
              EOT

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-database-usuarios"
    Role = "database-usuarios"
  })

  depends_on = [aws_internet_gateway.main]
}


# ============================================
# BASE DE DATOS DE NEGOCIO (PostgreSQL)
# ============================================

resource "aws_instance" "dc_database_negocio" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_db
  vpc_security_group_ids = [aws_security_group.dc_traffic_db_negocio.id]
  subnet_id              = aws_subnet.subnet_2.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  user_data = <<-EOT
#!/bin/bash
set -e
set -x
exec > /var/log/user-data.log 2>&1

echo "=========================================="
echo "INSTALANDO BD DE NEGOCIO"
echo "=========================================="

              sudo apt-get update -y
              sudo apt-get upgrade -y
              sudo apt-get install -y postgresql postgresql-contrib

              sudo systemctl start postgresql
              sudo systemctl enable postgresql

              # ESPERAR a que PostgreSQL esté listo para aceptar conexiones
              echo "Esperando a que PostgreSQL esté listo..."
              until sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; do
                echo "PostgreSQL no listo... esperando 5s"
                sleep 5
              done
              echo "PostgreSQL está listo."

              sudo -u postgres psql -c "CREATE USER ${var.db_user} WITH PASSWORD '${var.db_password_negocio}' SUPERUSER;" 2>/dev/null || true
              sudo -u postgres createdb -O ${var.db_user} ${var.db_name_negocio} 2>/dev/null || true


              PG_CONF="/etc/postgresql/16/main/postgresql.conf"
              PG_HBA="/etc/postgresql/16/main/pg_hba.conf"

              sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF
              sudo sed -i "s/#shared_buffers = 128MB/shared_buffers = 512MB/" $PG_CONF
              sudo sed -i "s/#work_mem = 4MB/work_mem = 16MB/" $PG_CONF
              sudo sed -i "s/#max_connections = 100/max_connections = 200/" $PG_CONF
              echo "host all all 0.0.0.0/0 md5" | sudo tee -a $PG_HBA


              sudo systemctl restart postgresql

              echo "BD de Negocio instalada"
              EOT

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-database-negocio"
    Role = "database-negocio"
  })

  depends_on = [aws_internet_gateway.main]
}


# ============================================
# SERVIDOR WEB A (Reportes)
# ============================================

resource "aws_instance" "dc_servidor_web_a" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_app
  vpc_security_group_ids = [aws_security_group.dc_traffic_django.id]
  subnet_id              = aws_subnet.subnet_1.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  user_data = <<-EOT
#!/bin/bash
set -e
set -x
exec > /var/log/user-data.log 2>&1

export HOME=/home/ubuntu
mkdir -p $HOME
chown ubuntu:ubuntu $HOME

echo "=========================================="
echo "INSTALANDO SERVIDOR WEB A (Reportes)"
echo "=========================================="

              sudo apt-get update -y
              sudo apt-get install -y python3-pip python3-venv git build-essential libpq-dev python3-dev


              git config --global credential.helper store
              echo "https://${var.azure_devops_pat}:x-oauth-basic@dev.azure.com" > ~/.git-credentials              
              chmod 600 ~/.git-credentials

              mkdir -p /opt/repo
              cd /opt/repo

              echo "Clonando repositorio de Azure DevOps..."

              if [ -z "$(ls -A /opt/repo)" ]; then
                  git clone "${var.repository}" .
              else
                  echo "Repositorio ya existe, actualizando..."
                  git pull origin main # Ajusta 'main' a tu rama por defecto
              fi



                mkdir -p /opt/app
                if [ -d /opt/repo/newCode/manejadorReportes/src ]; then
                  cd /opt/repo/newCode/manejadorReportes/src
                  tar -cf - . | (cd /opt/app && tar -xpf -)
                fi
                # Ensure app files are owned by ubuntu before creating venv
                chown -R ubuntu:ubuntu /opt/app || true
                mkdir -p /opt/app/dataTest
                cp /opt/repo/newCode/dataTest/bd_recursos_data.sql /opt/app/dataTest/ 2>/dev/null || true


              python3 -m venv /opt/app/venv
              source /opt/app/venv/bin/activate
              pip install --upgrade pip
              pip install -r /opt/app/requirements.txt

              export DATABASE_HOST=${aws_instance.dc_database_recursos.private_ip}
              export DATABASE_PORT=5432
              export DATABASE_NAME=${var.db_name_recursos}
              export DATABASE_USER=${var.db_user}
              export DATABASE_PASSWORD=${var.db_password_recursos}

              echo "DATABASE_HOST=$DATABASE_HOST" > /opt/app/.env
              echo "DATABASE_PORT=$DATABASE_PORT" >> /opt/app/.env
              echo "DATABASE_NAME=$DATABASE_NAME" >> /opt/app/.env
              echo "DATABASE_USER=$DATABASE_USER" >> /opt/app/.env
              echo "DATABASE_PASSWORD=$DATABASE_PASSWORD" >> /opt/app/.env
              echo "USERS_MANAGER_URL=http://${aws_instance.dc_servidor_web_b.private_ip}:8080" >> /opt/app/.env


              echo "Servidor Web A preparado"
              echo "TODO: Iniciar aplicación Django"

              cd /opt/app
              until python3 -c "import psycopg2; psycopg2.connect(
        host='$DATABASE_HOST',
        dbname='$DATABASE_NAME',
        user='$DATABASE_USER',
        password='$DATABASE_PASSWORD',
        port=$DATABASE_PORT
    )" 2>/dev/null; do
                echo "Esperando BD Recursos..."; sleep 10
              done

              source /opt/app/venv/bin/activate
              EnvironmentFile=/opt/app/.env
              python manage.py migrate
              python manage.py seed_reports


cat > /etc/systemd/system/gunicorn-reports.service <<SERVICE
[Unit]
Description=BITE.co Reports Manager
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/app
Environment=PYTHONPATH=/opt/app
EnvironmentFile=/opt/app/.env
ExecStart=/opt/app/venv/bin/gunicorn --bind 0.0.0.0:8080 --workers 2 reports_manager.wsgi:application
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

              systemctl daemon-reload
              systemctl enable gunicorn-reports
              systemctl start gunicorn-reports
              echo "Web A lista en :8080"

              EOT

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-servidor-web-a"
    Role = "web-reportes"
  })

  depends_on = [aws_instance.dc_database_recursos]
}


# ============================================
# SERVIDOR WEB B (Autenticación)
# ============================================

resource "aws_instance" "dc_servidor_web_b" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_app
  vpc_security_group_ids = [aws_security_group.dc_traffic_django.id]
  subnet_id              = aws_subnet.subnet_1.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  user_data = <<-EOT
#!/bin/bash
set -e
set -x
exec > /var/log/user-data.log 2>&1
export HOME=/home/ubuntu
mkdir -p $HOME
chown ubuntu:ubuntu $HOME
echo "=========================================="
echo "INSTALANDO SERVIDOR WEB B (Autenticación)"
echo "=========================================="
              sudo apt-get update -y
              sudo apt-get install -y python3-pip python3-venv git build-essential libpq-dev python3-dev
              git config --global credential.helper store
              echo "https://${var.azure_devops_pat}:x-oauth-basic@dev.azure.com" > ~/.git-credentials              
              chmod 600 ~/.git-credentials
              mkdir -p /opt/repo
              cd /opt/repo
              echo "Clonando repositorio de Azure DevOps..."
              if [ -z "$(ls -A /opt/repo)" ]; then
                  git clone "${var.repository}" .
              else
                  echo "Repositorio ya existe, actualizando..."
                  git pull origin main # Ajusta 'main' a tu rama por defecto
              fi
                mkdir -p /opt/app
                if [ -d /opt/repo/newCode/manejadorAutenticacionYAutorizacion/src ]; then
                  cd /opt/repo/newCode/manejadorAutenticacionYAutorizacion/src
                  tar -cf - . | (cd /opt/app && tar -xpf -)
                fi
                # Ensure app files are owned by ubuntu
                chown -R ubuntu:ubuntu /opt/app || true
              python3 -m venv /opt/app/venv
              source /opt/app/venv/bin/activate
              pip install --upgrade pip
              pip install -r /opt/app/requirements.txt
              export DATABASE_HOST=${aws_instance.dc_database_usuarios.private_ip}
              export DATABASE_PORT=5432
              export DATABASE_NAME=${var.db_name_usuarios}
              export DATABASE_USER=${var.db_user}
              export DATABASE_PASSWORD=${var.db_password_usuarios}
              echo "DATABASE_HOST=$DATABASE_HOST" > /opt/app/.env
              echo "DATABASE_PORT=$DATABASE_PORT" >> /opt/app/.env
              echo "DATABASE_NAME=$DATABASE_NAME" >> /opt/app/.env
              echo "DATABASE_USER=$DATABASE_USER" >> /opt/app/.env
              echo "DATABASE_PASSWORD=$DATABASE_PASSWORD" >> /opt/app/.env
              echo "Servidor Web B preparado"
              echo "TODO: Iniciar aplicación Django"
              cd /opt/app
              until python3 -c "import psycopg2; psycopg2.connect(
        host='$DATABASE_HOST',
        dbname='$DATABASE_NAME',
        user='$DATABASE_USER',
        password='$DATABASE_PASSWORD',
        port=$DATABASE_PORT
    )" 2>/dev/null; do
                echo "Esperando BD Usuarios..."; sleep 10
               done
              source /opt/app/venv/bin/activate
              EnvironmentFile=/opt/app/.env
              python manage.py migrate
              python manage.py seed_users

              cat > /etc/systemd/system/gunicorn-users.service <<SERVICE
[Unit]
Description=BITE.co Users Manager
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/app
Environment=PYTHONPATH=/opt/app
EnvironmentFile=/opt/app/.env
ExecStart=/opt/app/venv/bin/gunicorn --bind 0.0.0.0:8080 --workers 2 users_manager.wsgi:application
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
              systemctl daemon-reload
              systemctl enable gunicorn-users
              systemctl start gunicorn-users
              echo "Web B lista en :8080"
              EOT

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-servidor-web-b"
    Role = "web-autenticacion"
  })

  depends_on = [aws_instance.dc_database_usuarios]
}


# ============================================
# SERVIDOR WEB C (Empresa)
# ============================================

resource "aws_instance" "dc_servidor_web_c" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_app
  vpc_security_group_ids = [aws_security_group.dc_traffic_django.id]
  subnet_id              = aws_subnet.subnet_1.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  user_data = <<-EOT
#!/bin/bash
set -e
set -x
exec > /var/log/user-data.log 2>&1

export HOME=/home/ubuntu
mkdir -p $HOME
chown ubuntu:ubuntu $HOME

echo "=========================================="
echo "INSTALANDO SERVIDOR WEB C (Empresa)"
echo "=========================================="

              sudo apt-get update -y
              sudo apt-get install -y python3-pip python3-venv git build-essential libpq-dev python3-dev

              git config --global credential.helper store
              echo "https://${var.azure_devops_pat}:x-oauth-basic@dev.azure.com" > ~/.git-credentials              
              chmod 600 ~/.git-credentials

              mkdir -p /opt/repo
              cd /opt/repo

              echo "Clonando repositorio de Azure DevOps..."

              if [ -z "$(ls -A /opt/repo)" ]; then
                  git clone "${var.repository}" .
              else
                  echo "Repositorio ya existe, actualizando..."
                  git pull origin main # Ajusta 'main' a tu rama por defecto
              fi
              
                mkdir -p /opt/app
                if [ -d /opt/repo/newCode/manejadorEmpresa/src ]; then
                  cd /opt/repo/newCode/manejadorEmpresa/src
                  tar -cf - . | (cd /opt/app && tar -xpf -)
                fi
                # Ensure app files are owned by ubuntu
                chown -R ubuntu:ubuntu /opt/app || true


              python3 -m venv /opt/app/venv
              source /opt/app/venv/bin/activate
              pip install --upgrade pip
              pip install -r /opt/app/requirements.txt

              export DATABASE_HOST=${aws_instance.dc_database_negocio.private_ip}
              export DATABASE_PORT=5432
              export DATABASE_NAME=${var.db_name_negocio}
              export DATABASE_USER=${var.db_user}
              export DATABASE_PASSWORD=${var.db_password_negocio}

              echo "DATABASE_HOST=$DATABASE_HOST" > /opt/app/.env
              echo "DATABASE_PORT=$DATABASE_PORT" >> /opt/app/.env
              echo "DATABASE_NAME=$DATABASE_NAME" >> /opt/app/.env
              echo "DATABASE_USER=$DATABASE_USER" >> /opt/app/.env
              echo "DATABASE_PASSWORD=$DATABASE_PASSWORD" >> /opt/app/.env

              echo "Servidor Web C preparado"
              echo "TODO: Iniciar aplicación Django"

              cd /opt/app
              until python3 -c "import psycopg2; psycopg2.connect(
        host='$DATABASE_HOST',
        dbname='$DATABASE_NAME',
        user='$DATABASE_USER',
        password='$DATABASE_PASSWORD',
        port=$DATABASE_PORT
    )" 2>/dev/null; do
                echo "Esperando BD Negocio..."; sleep 10
              done

              source /opt/app/venv/bin/activate
              EnvironmentFile=/opt/app/.env
              python manage.py migrate
              python manage.py seed_companies

              
            cat > /etc/systemd/system/gunicorn-companies.service <<SERVICE
[Unit]
Description=BITE.co Company Manager
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/app
Environment=PYTHONPATH=/opt/app
EnvironmentFile=/opt/app/.env
ExecStart=/opt/app/venv/bin/gunicorn --bind 0.0.0.0:8080 --workers 2 companies_manager.wsgi:application
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

              systemctl daemon-reload
              systemctl enable gunicorn-companies
              systemctl start gunicorn-companies
              echo "Web C lista en :8080"

              EOT

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-servidor-web-c"
    Role = "web-empresa"
  })

  depends_on = [aws_instance.dc_database_negocio]
}


# ============================================
# SERVIDOR EXTRACTOR DE DATOS AWS
# ============================================

resource "aws_instance" "dc_extractor" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_app
  vpc_security_group_ids = [aws_security_group.dc_traffic_extractor.id]
  subnet_id              = aws_subnet.subnet_1.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  user_data = <<-EOT
#!/bin/bash
set -e
set -x
exec > /var/log/user-data.log 2>&1

echo "=========================================="
echo "INSTALANDO EXTRACTOR DE DATOS"
echo "=========================================="

              sudo apt-get update -y
              sudo apt-get install -y python3-pip python3-venv git build-essential libpq-dev python3-dev


              mkdir -p /opt/repo
              git clone "${var.repository}" /opt/repo


              mkdir -p /opt/extractor
              cp /opt/repo/newCode/cloud_cost_extractor.py /opt/extractor/
              cp /opt/repo/newCode/dataTest/bd_recursos_data.sql /opt/extractor/ 2>/dev/null || true


              python3 -m venv /opt/extractor/venv
              source /opt/extractor/venv/bin/activate
              pip install --upgrade pip
              pip install boto3 psycopg2-binary schedule

              export DATABASE_HOST=${aws_instance.dc_database_recursos.private_ip}
              export DATABASE_PORT=5432

              cat > /opt/extractor/.env <<EOF
              DATABASE_HOST=${aws_instance.dc_database_recursos.private_ip}
              DATABASE_PORT=5432
              DATABASE_NAME=${var.db_name_recursos}
              DATABASE_USER=${var.db_user}
              DATABASE_PASSWORD=${var.db_password_recursos}
              EMPRESA_ID=1
              AREA_LABEL_MAP=bite-sites:1,cross:2,networking:3
              DEFAULT_PROVIDER=AZURE
              AWS_REGION=us-east-1
              EOF

              echo "Extractor preparado"
              echo "TODO: Iniciar aplicación extractor"

              echo "0 */6 * * * ubuntu cd /opt/extractor && source venv/bin/activate && python cloud_cost_extractor.py >> /var/log/bite_extractor.log 2>&1" \
                > /etc/cron.d/bite-extractor
              chmod 644 /etc/cron.d/bite-extractor

              cd /opt/extractor && source venv/bin/activate && python cloud_cost_extractor.py &
              echo "Extractor instalado - cron cada 6 horas"
              EOT

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-extractor"
    Role = "data-extractor"
  })

  depends_on = [aws_instance.dc_database_recursos]
}


# ============================================
# KONG API GATEWAY (Broker Central)
# ============================================
#
# Punto ÚNICO de acceso público
# Distribuye tráfico hacia Servidores Web A, B, C
# TODO: Configurar rutas Kong hacia cada servidor web

resource "aws_instance" "dc_kong" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_kong
  vpc_security_group_ids = [aws_security_group.dc_traffic_kong.id]
  subnet_id              = aws_subnet.subnet_1.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  user_data = <<-EOT
#!/bin/bash
set -euxo pipefail

# Redirigir salida al log
exec > /var/log/user-data-kong-dynamic.log 2>&1

echo "=========================================="
echo "INICIANDO KONG CON IPs DINÁMICAS (Terraform)"
echo "=========================================="

# 1. Instalación de Docker
if ! command -v docker &> /dev/null; then
    apt-get update -y
    apt-get install -y docker.io
    systemctl enable --now docker
    usermod -aG docker ubuntu || true
fi

# 2. Limpieza de contenedores previos
if docker ps -a --format '{{.Names}}' | grep -q '^kong$'; then
    docker stop kong
    docker rm kong
fi

# 3. Generar configuración YAML con IPs DINÁMICAS
# Terraform inyecta los valores de private_ip directamente aquí
CONFIG_FILE="/tmp/kong_dynamic.yml"

cat > "$CONFIG_FILE" <<YAML_EOF
_format_version: "3.0"

services:
  - name: users-manager
    url: http://${aws_instance.dc_servidor_web_b.private_ip}:8080
    routes:
      - name: auth-login
        paths: [/auth/login/]
        strip_path: false
        methods: [POST]
      - name: auth-logout
        paths: [/auth/logout/]
        strip_path: false
        methods: [POST]
      - name: auth-validate
        paths: [/auth/validate/]
        strip_path: false
        methods: [POST]
      - name: auth-health
        paths: [/auth/health-check/]
        strip_path: false
        methods: [GET]
      - name: auth-general
        paths: [/auth/]
        strip_path: false
        methods: [GET, POST]

  - name: reports-manager
    url: http://${aws_instance.dc_servidor_web_a.private_ip}:8080
    routes:
      - name: reports-list
        paths: [/reports/]
        strip_path: false
        methods: [GET]
      - name: reports-by-area
        paths: [/reports/by-area/]
        strip_path: false
        methods: [GET]
      - name: reports-health
        paths: [/reports/health-check/]
        strip_path: false
        methods: [GET]

  - name: companies-manager
    url: http://${aws_instance.dc_servidor_web_c.private_ip}:8080
    routes:
      - name: companies-health
        paths: [/health/]
        strip_path: false
        methods: [GET]
      - name: empresas-list
        paths: [/empresas/]
        strip_path: false
        methods: [GET, POST]
      - name: proyectos-list
        paths: [/proyectos/]
        strip_path: false
        methods: [GET, POST]
      - name: areas-list
        paths: [/areas/]
        strip_path: false
        methods: [GET, POST]

plugins:
  - name: cors
    config:
      origins: ["*"]
      methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
      headers: ["Authorization", "Content-Type"]
      max_age: 3600
YAML_EOF

echo "Configuración generada en $CONFIG_FILE"
echo "IPs detectadas:"
echo "  Web A (Reports): ${aws_instance.dc_servidor_web_a.private_ip}"
echo "  Web B (Users):   ${aws_instance.dc_servidor_web_b.private_ip}"
echo "  Web C (Companies): ${aws_instance.dc_servidor_web_c.private_ip}"

# 4. Ejecutar Docker montando el archivo generado
docker run -d --name kong \
  --restart always \
  --network host \
  -e KONG_DATABASE=off \
  -e KONG_PROXY_LISTEN="0.0.0.0:8000" \
  -e KONG_ADMIN_LISTEN="0.0.0.0:8001" \
  -e KONG_DECLARATIVE_CONFIG=/kong.yml \
  -v "$CONFIG_FILE:/kong.yml:ro" \
  kong:3.6

echo "=========================================="
echo "KONG INICIADO CON CONFIGURACIÓN DINÁMICA"
echo "=========================================="

sleep 5
if docker ps --filter "name=kong" --format "{{.Status}}"; then
    echo "El contenedor está corriendo."
else
    echo "ERROR: El contenedor falló al iniciar. Logs: docker logs kong"
    exit 1
fi
              EOT

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-kong"
    Role = "api-gateway"
  })

  depends_on = [
    aws_instance.dc_servidor_web_a,
    aws_instance.dc_servidor_web_b,
    aws_instance.dc_servidor_web_c,
    aws_instance.dc_extractor
  ]
}


# ============================================
# OUTPUTS
# ============================================

output "kong_public_ip" {
  description = "IP pública de Kong (ÚNICO punto de acceso)"
  value       = aws_instance.dc_kong.public_ip
}

output "servidor_web_a_private_ip" {
  description = "IP privada de Servidor Web A (Reportes)"
  value       = aws_instance.dc_servidor_web_a.private_ip
}

output "servidor_web_b_private_ip" {
  description = "IP privada de Servidor Web B (Autenticación)"
  value       = aws_instance.dc_servidor_web_b.private_ip
}

output "servidor_web_c_private_ip" {
  description = "IP privada de Servidor Web C (Empresa)"
  value       = aws_instance.dc_servidor_web_c.private_ip
}

output "database_recursos_private_ip" {
  description = "IP privada de BD de Recursos"
  value       = aws_instance.dc_database_recursos.private_ip
}

output "database_usuarios_private_ip" {
  description = "IP privada de BD de Usuarios"
  value       = aws_instance.dc_database_usuarios.private_ip
}

output "database_negocio_private_ip" {
  description = "IP privada de BD de Negocio"
  value       = aws_instance.dc_database_negocio.private_ip
}

output "extractor_private_ip" {
  description = "IP privada del Extractor"
  value       = aws_instance.dc_extractor.private_ip
}

output "architecture_summary" {
  description = "Resumen de arquitectura desplegada"
  value       = "Kong es el único punto de acceso público en ${aws_instance.dc_kong.public_ip}. Tráfico interno entre Kong y Web Servers. Todas las BDs accesibles solo desde servidores internos."
}

