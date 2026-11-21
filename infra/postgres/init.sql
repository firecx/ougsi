\set ON_ERROR_STOP on
\getenv orchestrator_user ORCHESTRATOR_DB_USER
\getenv orchestrator_password ORCHESTRATOR_DB_PASSWORD
\getenv vm_user VM_DB_USER
\getenv vm_password VM_DB_PASSWORD

BEGIN;
CREATE ROLE :"orchestrator_user" LOGIN PASSWORD :'orchestrator_password';
CREATE ROLE :"vm_user" LOGIN PASSWORD :'vm_password';
CREATE SCHEMA orchestrator AUTHORIZATION :"orchestrator_user";
CREATE SCHEMA vm_service AUTHORIZATION :"vm_user";
COMMIT;
