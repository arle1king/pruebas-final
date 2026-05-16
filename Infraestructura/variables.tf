# ============================================
# VARIABLES - DESPLIEGUE COMPLETO
# ============================================

# --- Configuración General ---

variable "region" {
  description = "Región de AWS para despliegue"
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Prefijo para nombrar recursos AWS (usar nombre único)"
  type        = string
  default     = "dc"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "dev"
}


# --- Tipos de Instancia ---

variable "instance_type_app" {
  description = "Tipo de instancia para servidores web y extractor"
  type        = string
  default     = "t2.small"
}

variable "instance_type_db" {
  description = "Tipo de instancia para servidores PostgreSQL"
  type        = string
  default     = "t3.small"
}

variable "instance_type_kong" {
  description = "Tipo de instancia para Kong API Gateway"
  type        = string
  default     = "t3.small"
}


# --- Almacenamiento ---

variable "volume_size" {
  description = "Tamaño del volumen EBS en GB"
  type        = number
  default     = 30
}

variable "volume_type" {
  description = "Tipo de volumen EBS"
  type        = string
  default     = "gp3"
}


# --- Base de Datos - Usuario Común ---

variable "db_user" {
  description = "Usuario maestro para todas las bases de datos"
  type        = string
  sensitive   = true
}


# --- Base de Datos de Recursos ---

variable "db_password_recursos" {
  description = "Contraseña para BD de Recursos"
  type        = string
  sensitive   = true
}

variable "db_name_recursos" {
  description = "Nombre de BD de Recursos"
  type        = string
  default     = "recursos_db"
}


# --- Base de Datos de Usuarios ---

variable "db_password_usuarios" {
  description = "Contraseña para BD de Usuarios"
  type        = string
  sensitive   = true
}

variable "db_name_usuarios" {
  description = "Nombre de BD de Usuarios"
  type        = string
  default     = "usuarios_db"
}


# --- Base de Datos de Negocio ---

variable "db_password_negocio" {
  description = "Contraseña para BD de Negocio"
  type        = string
  sensitive   = true
}

variable "db_name_negocio" {
  description = "Nombre de BD de Negocio"
  type        = string
  default     = "negocio_db"
}


# --- Repositorio y Código ---

variable "repository" {
  description = "URL del repositorio Git a clonar"
  type        = string
  default     = "https://dev.azure.com/ISIS2503-202610-S4-G6-Dipachos/ProyectoBite/_git/ProyectoBite"

}

variable "branch" {
  description = "Rama de Git a desplegar"
  type        = string
  default     = "main"
}


# --- Credenciales Genéricas (para compatibilidad) ---

variable "db_username" {
  description = "Usuario de base de datos genérico"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Contraseña de base de datos genérica"
  type        = string
  sensitive   = true
}

variable "azure_devops_pat" {
  description = "Personal Access Token (PAT) de Azure DevOps para autenticación Git"
  type        = string
  sensitive   = true
}