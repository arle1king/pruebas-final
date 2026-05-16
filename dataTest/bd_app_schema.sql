-- Seed para esquema multi-tenant usado por `App`
-- Crea tenants (public.tenants) y registros ejemplo en schemas por tenant

-- Crear schemas (si aún no existen)
CREATE SCHEMA IF NOT EXISTS empresa_a;
CREATE SCHEMA IF NOT EXISTS empresa_b;
CREATE SCHEMA IF NOT EXISTS empresa_c;

-- Tenants en schema public
INSERT INTO public.tenants (id, key, display_name) VALUES (1, 'empresa_a', 'Empresa A');
INSERT INTO public.tenants (id, key, display_name) VALUES (2, 'empresa_b', 'Empresa B');
INSERT INTO public.tenants (id, key, display_name) VALUES (3, 'empresa_c', 'Empresa C');

-- Ejemplo de proyectos por tenant (tabla 'proyecto' según patrones del repo)
INSERT INTO empresa_a.proyecto (id, nombre, empresa_id) VALUES (1, 'Proyecto AWS', 1);
INSERT INTO empresa_b.proyecto (id, nombre, empresa_id) VALUES (2, 'Proyecto GCP', 2);

-- Ejemplo de consumos (tabla consumo_cloud por esquema)
INSERT INTO empresa_a.consumo_cloud (recurso, cantidadUtilizadas, costoPorUnidad, fechaRegistro, idProyecto, hash_sha256)
VALUES ('ec2-dev-web-02', 126.45, 0.186, '2026-05-01', 1, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');

INSERT INTO empresa_b.consumo_cloud (recurso, cantidadUtilizadas, costoPorUnidad, fechaRegistro, idProyecto, hash_sha256)
VALUES ('gce-dev-web-06', 123.49, 0.123, '2026-05-01', 2, 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');

-- Ejemplo de reportes globales
INSERT INTO public.reportes (id, tenant_key, report_id, generated_at, checksum, payload)
VALUES (1, 'empresa_a', 'RPT-001', now(), 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc', '{}');
