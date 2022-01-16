CREATE OR REPLACE PACKAGE app_html_table_pkg 
AS
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

/*

NOTE:

There is a substantial limitation of Polymorphic Table Functions.
Only SCALAR
values are allowed for columns, which sounds innocuous enough, until you understand that
SYSDATE and TO_DATE('20210101','YYYYMMDD') do not fit that definition. If you have those
in your cursor/query/view, you must cast them to DATE for it to work.

*/
    FUNCTION ptf(
        p_tab                           TABLE
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
        -- these are overrides on specific columns in your query.
        -- p_col_conv_tab applies TO_CHAR to a number, date or interval field in your query
        -- using the format string in the same position in the array. You can put NULLs
        -- in the array. You can stop populating it after the last column in your query
        -- that requires a conversion.
        ,p_col_conv_tab                 &&d_arr_varchar2_udt. := NULL
        -- Numeric fields in your resultset (before ptf applies conversions) are right justified
        -- in the HTML table. If you are doing a TO_CHAR in your select, the value is a varchar2
        -- and so is not right justified. This array lets you control whether right justify is applied.
        -- 'R' specifies Right, 'L' specifies left and NULL specifies use the logic based on column data type.
        -- Collection cannot be sparse (use NULL placeholders), but it can have less entries than 
        -- the query has columns.
        ,p_right_justify_tab            &&d_arr_varchar2_udt. := NULL
    ) RETURN TABLE PIPELINED 
        ROW 
        POLYMORPHIC USING app_html_table_pkg
    ;

    --
    -- a) If it contains the string app_html_table_pkg.ptf (case insensitive match), then it is returned as is. and your 
    --      other arguments are ignored because you should have used them directly in the PTF call.
    -- b) If it does not start with the case insensitive pattern '\s*WITH\s', then we wrap it with a 'WITH R AS (' and
    --      a ') SELECT * FROM app_html_table_pkg.ptf(R, __your_parameter_vals__)' before calling it.
    -- c) If it starts with 'WITH', then we search for the final sql clause as '(^.+\))(\s*SELECT\s.+$)' breaking it
    --      into two parts. Between them we add ', R_app_html_table_pkg_ptf AS (' and at the end we put
    --      ') SELECT * FROM app_html_table_pkg.ptf(R_app_html_table_pkg_ptf, __your_parameter_vals__)'
    -- Best thing to do is run your query through the function and see what you get. It has worked in my test cases.
    --
    FUNCTION get_ptf_query_string(
        p_sql                           CLOB
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
        ,p_col_conv_tab                 VARCHAR2 := NULL -- character version of collection constructor passed here
        ,p_right_justify_tab            VARCHAR2 := NULL -- character version of collection constructor passed here
    ) RETURN CLOB
    ;

    FUNCTION get_clob(
        p_src                           SYS_REFCURSOR
    ) RETURN CLOB
    ;
    FUNCTION get_clob(
        p_sql                           CLOB
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
        ,p_col_conv_tab                 &&d_arr_varchar2_udt. := NULL
        ,p_right_justify_tab            &&d_arr_varchar2_udt. := NULL
    ) RETURN CLOB
    ;
    -- the describe and fetch procedures are used exclusively by the PTF mechanism. You cannot
    -- call them directly.
    FUNCTION describe(
        p_tab IN OUT                    DBMS_TF.TABLE_T
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
        ,p_col_conv_tab                 &&d_arr_varchar2_udt. := NULL
        ,p_right_justify_tab            &&d_arr_varchar2_udt. := NULL
    ) RETURN DBMS_TF.DESCRIBE_T
    ;
    PROCEDURE fetch_rows(
         p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
        ,p_col_conv_tab                 &&d_arr_varchar2_udt. := NULL
        ,p_right_justify_tab            &&d_arr_varchar2_udt. := NULL
    )
    ;


END app_html_table_pkg;
/
show errors
