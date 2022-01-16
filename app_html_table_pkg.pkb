CREATE OR REPLACE PACKAGE BODY app_html_table_pkg AS
/*
MIT License

Copyright (c) 2022 Lee Lindley

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

    TYPE t_tab_justify IS TABLE OF VARCHAR2(1) INDEX BY BINARY_INTEGER;
    g_tab_justify   t_tab_justify;

    FUNCTION get_ptf_query_string(
        p_sql                           CLOB
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
        -- these are overrides on specific columns in your query.
        -- p_col_conv_tab applies TO_CHAR to a number, date or interval field in your query
        -- using the format string in the same position in the array. You can put NULLs
        -- in the array. You can stop populating it after the last column in your query.
        ,p_col_conv_tab                 VARCHAR2 := NULL -- this must be munged into '&&d_arr_varchar2_udt.(...)' by caller
        -- Numeric fields in your resultset (before ptf applies conversions) are right justified
        -- in the HTML table. If you are doing a TO_CHAR in your select, the value is a varchar2
        -- and so is not right justified. This array lets you control whether right justify is applied.
        -- 'R' specifies Right, 'L' specifies left and NULL specifies use the logic based on column data type
        ,p_right_justify_tab            VARCHAR2 := NULL -- this must be munged into '&&d_arr_varchar2_udt.(...)' by caller
    ) RETURN CLOB
    IS
        v_clob                  CLOB;
    BEGIN
        IF REGEXP_LIKE(p_sql, 'app_html_table_pkg.ptf', 'i') THEN
            RETURN p_sql;
        END IF;
        IF REGEXP_LIKE(p_sql, '^\s*with\s', 'i') THEN
            v_clob := REGEXP_SUBSTR(p_sql, '(^.+\))(\s*SELECT\s.+$)', 1, 1, 'in', 1);
            v_clob := v_clob||'
, R_app_html_table_pkg_ptf AS (
';
            v_clob := v_clob||REGEXP_SUBSTR(p_sql, '(^.+\))(\s*SELECT\s.+$)', 1, 1, 'in', 2);
            v_clob := v_clob||'
)';
        ELSE
            v_clob := 'WITH R_app_html_table_pkg_ptf AS (
'||p_sql||'
)';
        END IF;
        v_clob := v_clob||q'[
    SELECT * FROM app_html_table_pkg.ptf(
                        p_tab                           => R_app_html_table_pkg_ptf
                        ,p_num_format                   => ]'
                || CASE WHEN p_num_format IS NULL THEN 'NULL' ELSE q'[']'||p_num_format||q'[']' END
                || q'[
                        ,p_date_format                  => ]'
                || CASE WHEN p_date_format IS NULL THEN 'NULL' ELSE q'[']'||p_date_format||q'[']' END
                || q'[
                        ,p_interval_format              => ]'
                || CASE WHEN p_interval_format IS NULL THEN 'NULL' ELSE q'[']'||p_interval_format||q'[']' END
                ||q'[
                        ,p_col_conv_tab                 => ]'
                    || CASE WHEN p_col_conv_tab IS NULL THEN 'NULL' ELSE p_col_conv_tab END
                ||q'[
                        ,p_right_justify_tab            => ]'
                || CASE WHEN p_right_justify_tab IS NULL THEN 'NULL' ELSE p_right_justify_tab END
                ||q'[
                  )]';
        RETURN v_clob;
    END get_ptf_query_string
    ;

    FUNCTION get_clob(
        p_src               SYS_REFCURSOR
    )
    RETURN CLOB
    IS
        v_tab_varchar2  DBMS_TF.tab_varchar2_t;
        v_clob          CLOB;
    BEGIN

        -- We separate out table from the rest of the body with a div and embed a scoped style for it
        v_clob := q'!<div id="plsql-table">
<style type="text/css" scoped>
table {
    border: 1px solid black; 
    border-spacing: 0; 
    border-collapse: collapse;
}
th, td {
    border: 1px solid black; 
    padding:4px 6px;
}
!';

        -- each of the columns that were either asked to be right justified via the p_right_justify_tab            
        -- parameter or were not overriden by it and found to be NUMBER data types, we right justify
        -- by adding an override for that column to the local scope style. 
        -- Weird syntax, but that's the CSS crowd for you.
        FOR i IN 1..g_tab_justify.COUNT
        LOOP
            -- this package global was populated by the describe procedure. 
            IF g_tab_justify(i) = 'R' THEN
                v_clob := v_clob||'tr > td:nth-of-type('||LTRIM(TO_CHAR(i))||') {
    text-align:right;
}
';
            END IF;
        END LOOP;
        v_clob := v_clob||'</style>
<table>
';

        -- now fetch the HTML <tr> rows from the PTF
        LOOP
            FETCH p_src BULK COLLECT INTO v_tab_varchar2 LIMIT 100;
            EXIT WHEN v_tab_varchar2.COUNT = 0;
            FOR i IN 1..v_tab_varchar2.COUNT
            LOOP
                v_clob := v_clob||v_tab_varchar2(i)||CHR(10);
            END LOOP;
        END LOOP;
        v_clob := v_clob||'</table></div>';

        RETURN v_clob;

    END get_clob;

    FUNCTION get_clob(
        p_sql                   CLOB
        ,p_num_format           VARCHAR2 := NULL
        ,p_date_format          VARCHAR2 := NULL
        ,p_interval_format      VARCHAR2 := NULL
        ,p_col_conv_tab         &&d_arr_varchar2_udt. := NULL
        ,p_right_justify_tab    &&d_arr_varchar2_udt. := NULL
    ) 
    RETURN CLOB
    IS
        v_sql               CLOB;
        v_col_conv          CLOB;
        v_right_justify     CLOB;
        v_src               SYS_REFCURSOR;
        v_clob              CLOB;
        ORA62558            EXCEPTION;
        pragma EXCEPTION_INIT(ORA62558, -62558);
    BEGIN
        -- convert these collections into a string that applies the collection constructor
        IF p_col_conv_tab IS NOT NULL AND p_col_conv_tab.COUNT > 0 THEN
            SELECT LISTAGG(DECODE(column_value, NULL, 'NULL', ''''||column_value||''''), ',') 
            INTO v_col_conv 
            FROM TABLE(p_col_conv_tab)
            ;
            v_col_conv := '&&d_arr_varchar2_udt.('||v_col_conv||')';
        END IF;
        IF p_right_justify_tab IS NOT NULL AND p_right_justify_tab.COUNT > 0 THEN
            SELECT LISTAGG(DECODE(column_value, NULL, 'NULL', ''''||column_value||''''), ',') 
            INTO v_right_justify
            FROM TABLE(p_right_justify_tab)
            ;
            v_right_justify := '&&d_arr_varchar2_udt.('||v_right_justify||')';
        END IF;
        v_sql := get_ptf_query_string(
                                p_sql                   => p_sql
                                ,p_num_format           => p_num_format
                                ,p_date_format          => p_date_format
                                ,p_interval_format      => p_interval_format
                                ,p_col_conv_tab         => v_col_conv    
                                ,p_right_justify_tab    => v_right_justify
                            );
        BEGIN
            OPEN v_src FOR v_sql;
        EXCEPTION 
            WHEN ORA62558 THEN
                raise_application_error(-20001, 'sqlcode: '||sqlcode||' One or more columns in the query not supported. If coming from a view that calculates the date, do CAST(val AS DATE) in the view or your sql to fix it.');
            WHEN OTHERS THEN
                DBMS_OUTPUT.put_line(v_sql);
                RAISE;
        END;

        v_clob := get_clob(v_src);
        BEGIN
            CLOSE v_src;
            EXCEPTION WHEN invalid_cursor THEN NULL;
        END;
        RETURN v_clob;
    END;

    --
    -- The rest of this package body is the guts of the Polymorphic Table Function
    -- from the package specification named "ptf". You do not call these directly.
    -- Only the SQL engine calls them.
    -- 
    FUNCTION describe(
        p_tab IN OUT                    DBMS_TF.TABLE_T
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
        ,p_col_conv_tab                 &&d_arr_varchar2_udt. := NULL
        ,p_right_justify_tab            &&d_arr_varchar2_udt. := NULL
    ) RETURN DBMS_TF.DESCRIBE_T
    AS
        v_new_cols              DBMS_TF.columns_new_t;
    BEGIN
        -- communicate with get_clob through the package global variable
        g_tab_justify.DELETE;
        -- stop all input columns from being in the output
        FOR i IN 1..p_tab.column.COUNT()
        LOOP
            p_tab.column(i).pass_through := FALSE;
            p_tab.column(i).for_read := TRUE;
            g_tab_justify(i) := CASE WHEN p_right_justify_tab IS NOT NULL AND p_right_justify_tab.COUNT >= i
                                            AND p_right_justify_tab(i) IN ('R','r','L','l')
                                        THEN UPPER(p_right_justify_tab(i))
                                     WHEN p_tab.column(i).description.type = DBMS_TF.type_number 
                                        THEN 'R' 
                                     ELSE 'L' 
                                END;
        END LOOP;
        -- create a single new output column for the CSV row string
        v_new_cols(1) := DBMS_TF.column_metadata_t(
                                    name    => 'TABLE_ROW'
                                    ,type   => DBMS_TF.type_varchar2
                                );

        -- we will use row replication to put a header out on the first row if desired
        RETURN DBMS_TF.describe_t(new_columns => v_new_cols, row_replication => TRUE);
    END describe
    ;

    PROCEDURE fetch_rows(
        -- you can set these to NULL if you want the default TO_CHAR conversions
         p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
        ,p_col_conv_tab                 &&d_arr_varchar2_udt. := NULL
        ,p_right_justify_tab            &&d_arr_varchar2_udt. := NULL
    ) AS
        v_env               DBMS_TF.env_t := DBMS_TF.get_env();
        v_rowset            DBMS_TF.row_set_t;  -- the input rowset of CSV rows
        v_row_cnt           BINARY_INTEGER;
        v_col_cnt           BINARY_INTEGER;
        --
        v_val_col           DBMS_TF.tab_varchar2_t;
        v_repfac            DBMS_TF.tab_naturaln_t;
        v_fetch_pass        BINARY_INTEGER := 0;
        v_out_row_i         BINARY_INTEGER := 0;
        -- If the user does not want to change the NLS formats for the session
        -- but has custom coversions for this query, then we will apply them using TO_CHAR
        TYPE t_conv_fmt IS RECORD(
            t   BINARY_INTEGER  -- type
            ,f  VARCHAR2(1024)  -- to_char fmt string
        );
        TYPE t_tab_conv_fmt IS TABLE OF t_conv_fmt INDEX BY BINARY_INTEGER;
        v_conv_fmts         t_tab_conv_fmt;
        FUNCTION apply_cust_conv(
            p_col_index     BINARY_INTEGER
            ,p_row_index    BINARY_INTEGER
        ) RETURN VARCHAR2
        IS
            v_s VARCHAR2(4000);
        BEGIN
            v_s := CASE WHEN v_conv_fmts.EXISTS(p_col_index) THEN
                            CASE v_conv_fmts(p_col_index).t
                                WHEN DBMS_TF.type_number THEN 
                                    LTRIM(TO_CHAR(v_rowset(p_col_index).tab_number(p_row_index), v_conv_fmts(p_col_index).f))
                                WHEN DBMS_TF.type_date THEN 
                                    TO_CHAR(v_rowset(p_col_index).tab_date(p_row_index), v_conv_fmts(p_col_index).f)
                                WHEN DBMS_TF.type_interval_ym THEN 
                                    TO_CHAR(v_rowset(p_col_index).tab_interval_ym(p_row_index), v_conv_fmts(p_col_index).f)
                                WHEN DBMS_TF.type_interval_ds THEN 
                                    TO_CHAR(v_rowset(p_col_index).tab_interval_ds(p_row_index), v_conv_fmts(p_col_index).f)
                                ELSE DBMS_TF.col_to_char(v_rowset(p_col_index), p_row_index)
                            END
                    ELSE
                        DBMS_TF.col_to_char(v_rowset(p_col_index), p_row_index)
                    END;
            -- we do not want the double quotes around strings at this point
            IF SUBSTR(v_s,1,1) = '"'  THEN
                v_s := SUBSTR(v_s, 2, LENGTH(v_s) - 2);
            END IF;
            -- protect HTML 
            RETURN '<td>'||DBMS_XMLGEN.CONVERT(v_s)||'</td>';
        END; -- apply_cust_conv

    BEGIN -- start of fetch_rows procedure body

        -- We need to put out a header row, so we have to engage in replication_factor shenanigans.
        -- This is in case FETCH is called more than once. We get and put to the store
        -- the fetch count.
        -- get does not change value if not found in store so starts with our default 0 on first fetch call
        DBMS_TF.xstore_get('v_fetch_pass', v_fetch_pass); 
--dbms_output.put_line('xstore_get: '||v_fetch_pass);

        -- get the data for this fetch 
        DBMS_TF.get_row_set(v_rowset, v_row_cnt, v_col_cnt);

        -- set up for custom TO_CHAR conversions if requested for date and/or interval types
        FOR i IN 1..v_col_cnt
        LOOP
            IF p_col_conv_tab IS NOT NULL AND p_col_conv_tab.COUNT >= i 
                AND p_col_conv_tab(i) IS NOT NULL
            THEN
                v_conv_fmts(i) := t_conv_fmt(v_env.get_columns(i).type, p_col_conv_tab(i));
            ELSIF p_date_format IS NOT NULL AND v_env.get_columns(i).type = DBMS_TF.type_date THEN
                v_conv_fmts(i) := t_conv_fmt(DBMS_TF.type_date, p_date_format);
            ELSIF p_num_format IS NOT NULL AND v_env.get_columns(i).type = DBMS_TF.type_number THEN
                v_conv_fmts(i) := t_conv_fmt(DBMS_TF.type_number, p_num_format);
            ELSIF p_interval_format IS NOT NULL 
                AND v_env.get_columns(i).type IN (DBMS_TF.type_interval_ym, DBMS_TF.type_interval_ds) 
            THEN
                v_conv_fmts(i) := t_conv_fmt(v_env.get_columns(i).type, p_interval_format);
            END IF;

        END LOOP;

--dbms_output.put_line('fetched v_row_cnt='||v_row_cnt||', v_col_cnt='||v_col_cnt);
        IF v_fetch_pass = 0 THEN -- this is first pass and we need header row
            -- the first row of our output will get a header row plus the data row
            v_repfac(1) := 2;
            -- the rest of the rows will be 1 to 1 on the replication factor
            FOR i IN 2..v_row_cnt
            LOOP
                v_repfac(i) := 1;
            END LOOP;
            v_val_col(1) := '<tr>';
            -- we do not want the dquotes
            FOR j IN 1..v_col_cnt
            LOOP
                v_val_col(1) := v_val_col(1)||'<th>'
                                    ||DBMS_XMLGEN.CONVERT(
                                            SUBSTR(v_env.get_columns(j).name
                                                    ,2
                                                    ,LENGTH(v_env.get_columns(j).name) - 2
                                            )
                                      )
                                    ||'</th>';
            END LOOP;
            v_val_col(1) := v_val_col(1)||'</tr>';
            v_out_row_i := 1;
--dbms_output.put_line('header row: '||v_val_col(1));
        END IF;
        -- otherwise v_out_row_i is 0

        FOR i IN 1..v_row_cnt
        LOOP
            v_out_row_i := v_out_row_i + 1;
            v_val_col(v_out_row_i) := '<tr>';
            FOR j IN 1..v_col_cnt
            LOOP
                v_val_col(v_out_row_i) := v_val_col(v_out_row_i)
                                            ||apply_cust_conv(j, i) -- stripped dquotes
                                            ;
            END LOOP;
            v_val_col(v_out_row_i) := v_val_col(v_out_row_i)||'</tr>';
        END LOOP;

        IF v_fetch_pass = 0 THEN
            -- only on the first fetch 
            DBMS_TF.row_replication(replication_factor => v_repfac);
        END IF;
        v_fetch_pass := v_fetch_pass + 1;
        DBMS_TF.xstore_set('v_fetch_pass', v_fetch_pass);

        DBMS_TF.put_col(1, v_val_col);

    END fetch_rows;

END app_html_table_pkg;
/
show errors
