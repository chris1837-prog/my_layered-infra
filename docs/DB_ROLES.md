# Database Roles & Grants

This document defines the per-service database roles and their privileges.  
Principle: **least privilege** — each service only has the permissions it needs to perform its function, nothing more.

---

## Roles

- **svc_app_ro** → Read-only role for the application service.  
- **svc_migration** → Role for schema migrations (requires CREATE privileges).  
- [Add others as needed: e.g. svc_reporting_ro, svc_admin_migration]

---

## Grants Table

| Role           | Database   | Schema   | Privileges                                    |
|----------------|------------|----------|-----------------------------------------------|
| svc_app_ro     | `${DB_NAME}` | `public` | CONNECT, USAGE, SELECT                        |
| svc_migration  | `${DB_NAME}` | `public` | CONNECT, USAGE, CREATE, SELECT, INSERT, ALTER |

---

## Example SQL Snippets

### Application Read-Only Role
```sql
CREATE ROLE svc_app_ro LOGIN PASSWORD 'REDACTED'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;

GRANT CONNECT ON DATABASE ${DB_NAME} TO svc_app_ro;
GRANT USAGE ON SCHEMA public TO svc_app_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO svc_app_ro;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO svc_app_ro;


Migration Role
CREATE ROLE svc_migration LOGIN PASSWORD 'REDACTED'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;

GRANT CONNECT ON DATABASE ${DB_NAME} TO svc_migration;
GRANT USAGE, CREATE ON SCHEMA public TO svc_migration;
