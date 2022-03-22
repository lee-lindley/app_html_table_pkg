--ALTER SESSION SET plsql_code_type = NATIVE;
--ALTER SESSION SET plsql_optimize_level=3;
whenever sqlerror exit failure
prompt calling app_html_table_pkg.pks
@@app_html_table_pkg.pks
prompt calling app_html_table_pkg.pkb
@@app_html_table_pkg.pkb
--
--ALTER SESSION SET plsql_code_type = INTERPRETED;
--ALTER SESSION SET plsql_optimize_level=2;
--GRANT EXECUTE ON app_html_table_pkg TO PUBLIC;
