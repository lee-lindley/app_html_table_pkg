-- for conditional compilation based on sqlplus define settings.
-- When we select a column alias named "file_choice", we get a sqlplus define value for "file_choice"
COLUMN file_choice NEW_VALUE do_file NOPRINT
--
-- name this type any way you like. If you already have a type that matches, give that name
-- and change the "compile" define value to FALSE
--
define d_arr_varchar2_udt="arr_varchar2_udt"
define compile_arr_varchar2_udt="TRUE"
--
define subdir=plsql_utilities/app_types
SELECT DECODE('&&compile_arr_varchar2_udt','TRUE','&&subdir./arr_varchar2_udt.tps', 'do_nothing.sql arr_varchar2_udt') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file

define subdir=.
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
GRANT EXECUTE ON app_html_table_pkg TO PUBLIC;
