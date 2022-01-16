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


    FUNCTION cursor2html(
        p_src                           SYS_REFCURSOR
        ,p_right_align_col_list         VARCHAR2 := NULL -- comma separated integers in string
        ,p_caption                      VARCHAR2 := NULL
        ,p_css_scoped_style             VARCHAR2 := NULL
    ) RETURN CLOB
    ;

/* default p_css_scoped_style is

table {
    border: 1px solid black; 
    border-spacing: 0; 
    border-collapse: collapse;
}
caption {
    font-weight: bold;
    font-size: larger;
    margin-bottom: 0.5em;
}
th {
    text-align:left;
}
th, td {
    border: 1px solid black; 
    padding:4px 6px;
}

----------------------
but the package adds 
tr > td:nth-of-type(_col_) { text-align:right; }
as needed per p_right_align_col_list
*/
    FUNCTION query2html(
        p_sql                           CLOB
        ,p_right_align_col_list         VARCHAR2 := NULL -- comma separated integers in string
        ,p_caption                      VARCHAR2 := NULL
        ,p_css_scoped_style             VARCHAR2 := NULL
    ) RETURN CLOB
    ;

END app_html_table_pkg;
/
show errors
