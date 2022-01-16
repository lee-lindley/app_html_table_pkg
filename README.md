# app_html_table_pkg

Create HTML Table markup from an Oracle query.

> NOTE: Requires Oracle version 18c or higher as it depends on a Polymorphic Table Function. 

> ADDENDUM: There is a substantial limitation of Polymorphic Table Functions at least as of 19.6 and 20.3 (may
have been addressed in later releases).  Only SCALAR
values are allowed for columns, which sounds innocuous enough, until you understand that
SYSDATE and TO_DATE('20210101','YYYYMMDD') do not fit that definition for reasons I cannot fathom.
If you have those in your cursor/query/view, you must cast them to DATE for it to work. More detail follows
at the bottom of this document.

The package has two overloaded versions of a Function named *get_clob*, plus
a Polymorphic Table Function named *ptf*; however, you are unlikely to call *ptf* separately
as the rows it produces need to be wrapped in more HTML. The *get_clob* functions perform
that wrapping and accumulate the rows. You will need to craft the *ptf* call as part of your
query if you use the SYS_REFCURSOR
overload version of *get_clob*.

# Content

- [Installation](#installation)
- [Use Case](#use-case)
- [Manual Page](#manual-page)
    - [get_clob](#get_clob)
    - [get_clob SYS_REFCURSOR overload](#get_clob-sys_refcursor-overload)
    - [ptf](#ptf)
- [Examples](#examples)
- [Issue with PTF and DATE Functions](#issue-with-ptf-and-date-functions)


# Installation

Clone this repository or download it as a [zip](https://github.com/lee-lindley/app_html_table_pkg/archive/refs/heads/main.zip) archive.

Note: [plsql_utilties](https://github.com/lee-lindley/plsql_utilities) is provided as a submodule,
so use the clone command with recursive-submodules option:

`git clone --recursive-submodules https://github.com/lee-lindley/app_html_table_pkg.git`

or download it separately as a zip 
archive ([plsql_utilities.zip](https://github.com/lee-lindley/plsql_utilities/archive/refs/heads/main.zip)),
and extract the content of root folder into *plsql_utilities* folder.

## install.sql

If you already have a suitable TABLE type, you can update the sqlplus define variable *d_arr_varchar2_udt*
and set the define *compile_arr_varchar2_udt* to FALSE in the install file. You can change the name
of the type with *d_arr_varchar2_udt* and keep *compile_arr_varchar2_udt* as TRUE in which case
it will compile the appropriate type with your name.

Once you complete any changes to *install.sql*, run it with sqlplus:

`sqlplus YourLoginConnectionString @install.sql`

# Use Case

Our use case is to present HTML Table markup from an Oracle query while right aligning numeric data in the cells.
This is not a full HTML document, but a section that you can include in a larger HTML body. For example:

    SELECT app_html_table_pkg.get_clob(q'!SELECT * FROM hr.departments!')
    FROM dual;

The resulting text is enclosed with a \<div\> tag and can be added to an HTML email or otherwise included
in an HTML document.

While here, it turned out to be not so difficult to provide a way for you to insert your own
style choices for the table via CSS. You do not need to be a CSS guru to do it. The pattern
from the examples will be enough for most.

The common method for generating HTML markup tables from SQL queries in Oracle
is to use DBMS_XMLGEN and XSLT conversions via XMLType. A search of the web will
turn up multiple demonstrations of the technique. It works reasonably well, but there are
some gotchas like column headers with spaces get munged to \_x0020\_ and all data is left justified
in the cells.

A big drawback is that we often want to right justify numeric data. In plain text output we can use LPAD(TO_CHAR... 
to simulate right justification, but HTML does not respect spaces unless we use **pre**, and even then I'm not sure
we can count on the font to not mess up our alignment. I'm not an HTML or XSLT expert, but I do not think
preserving white space helps.

We need to use a right alignment style modifier on the table data tag when we want numbers right aligned.

Unfortunately, DBMS_XMLGEN does not maintain the datatype in the XML it outputs. Maybe there is another way
to generate the XML so that the datatype is encoded, but that still leaves us doing logic in the XSLT that is
beyond my ken, and I found zilch on the internet when looking for a solution.
Furthermore, even if we had the datatype, the query likely used TO_CHAR on it and what we really need to do
is either

- have the query author tell us which columns are right aligned or
- do the TO_CHAR conversion for the query author so that we know the underlying datatype

I had an existing package that generates CSV data to use as a template and started hacking it.
So, here we are. 

# Manual Page

## get_clob

```sql
    FUNCTION get_clob(
        p_sql                           CLOB
        ,p_caption                      VARCHAR2 := NULL
        ,p_css_scoped_style             VARCHAR2 := NULL
        ,p_num_format                   VARCHAR2 := NULL
        ,p_date_format                  VARCHAR2 := NULL
        ,p_interval_format              VARCHAR2 := NULL
        ,p_col_conv_tab                 arr_varchar2_udt := NULL
        ,p_right_justify_tab            arr_varchar2_udt := NULL
    ) RETURN CLOB
    ;
```

This version of *get_clob* with the *p_sql* parameter is the one you will most likely use. The alternative version
takes a SYS_REFCURSOR parameter which would allow you to use bind variables, but to use it
you must select from the *ptf* function directly in your cursor query. The returned CLOB using the default
scoped style and no caption looks as follows,
however the two style elements below with "**text-align:right;**" are customized specificly for a particular
query and parameters.


	<div id="plsql-table">
	<style type="text/css" scoped>
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
	th, td {
	    border: 1px solid black;
	    padding:4px 6px;
	}
	tr > td:nth-of-type(1) {
	    text-align:right;
	}
	tr > td:nth-of-type(4) {
	    text-align:right;
	}
	</style>
	<table>
	<tr><th>Emp ID</th><th>Fname</th><th>Date,Hire,YYYYMMDD</th><th>Salary</th></tr>
	<tr><td>102</td><td>De Haan, Lex</td><td>20010113</td><td>$17,000.00</td></tr>
    ...
	</table></div>

### p_sql

A string containing the SQL statement to execute.

### p_caption

If provided, will be wrapped with \<caption\> \</caption\> and inserted following the \<table\> tag.

### p_num_format

The default Number format to be applied via *TO_CHAR* to any NUMBER datatype columns in your resultset. See *p_col_conv_tab* for a way to apply different format conversions to different columns. Note that you can use TO_CHAR directly in your query, but the results will not be right justified in the cell unless you also populate *p_right_justify_tab*.

### p_date_format

The default Date format to be applied via *TO_CHAR* to any DATE datatype columns in your resultset. See *p_col_conv_tab* for a way to apply different format conversions to different columns. Note that you can use TO_CHAR directly in your query.

### p_interval_format

The default interval format to be applied via *TO_CHAR* to any INTERVAL datatype columns in your resultset. See *p_col_conv_tab* for a way to apply different format conversions to different columns. Note that you can use TO_CHAR directly in your query.

### p_col_conv_tab

A nested table collection of *TO_CHAR* conversion formats. This lets you override the default conversion for a particular column of type NUMBER, DATE or INTERVAL. 
The collection cannot be sparse, but may contain less entries than the query has columns.
See the examples for ways to initiate this collection as part of the function call.

### p_right_justify_tab
The default HTML table data cell is left justified. *app_html_table_pkg* will automatically apply **style="text-align:right;"** to cells where the original column type in your resultset is NUMBER. Note that if you run TO_CHAR in your query, the type of that column is VARCHAR2, which is a reason you might want to let *app_html_table_pkg* apply the conversions. *p_right_justify_tab* allows you to override the default behavior for any given column. A value of 'R' will right justify, 'L' will left justify (even if it is a number) and NULL will let the program decide based on the datatype. 
The collection cannot be sparse, but may contain less entries than the query has columns.
See the examples for ways to initiate this collection as part of the function call.

## get_clob SYS_REFCURSOR overload

```sql
    FUNCTION get_clob(
        p_src                           SYS_REFCURSOR
        ,p_caption                      VARCHAR2 := NULL
        ,p_css_scoped_style             VARCHAR2 := NULL
    ) RETURN CLOB
    ;
```

You open a SYS_RFCURSOR to pass it, but you call *ptf* in the last part of your SQL statement. The same arguments
that were discussed for the SQL string version of *get* are passed to *ptf*. Examples follow.

## ptf

```sql
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
```
Except for the first argument, the others are the same as the first *get* Function shown above. *ptf* parameters
may not be bind variables. The reason is that PTFs are evaluated at hard parse time so bind values
are not available and will present as all NULL. You can use bind variables in the rest of your query
assuming you are passing a CTE (WITH clause name) as *p_tab*.

### p_tab

Name of a schema level Table, View or Materialized View, or more likey, a Common Table Expression (CTE) (aka WITH clause).

## get_ptf_query_string

```sql
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
```

*get_ptf_query_string* is called internally by *get_clob*. It is exposed as a public function to assist in debugging
issues. Note that *p_col_conv_tab* and *p_right_justify_tab* are NOT collections. The caller is expected
to pass in a string containing an initializing constructor for type *arr_varchar2_udt*. Example:

    q'[arr_varchar2_udt(NULL, NULL, '$999,999,999.99', NULL, '099999999', 'MM/DD/YYYY HH24:MI')]'

*get_clob* constructs those strings from the input nested table parameters.

# Examples

## Example 1

All kinds of shenanigans going on here. 

We do a TO_CHAR on the first column so that the default
treatment would be left justify, but we put an 'R' into *p_right_justify_tab* at that position
so that it overrides the default and right justifies it. Round about way to do nothin' but prove
the override works.

We populate the 2nd element of *p_right_justify_tab* (with a useless NULL placeholder), 
but not the third or fourth. All three of those
are left to the default program behavior which looks at the data type of the incoming column value.

The forth column is a number so gets right justified by the default behavior.

```sql
SELECT app_html_table_pkg.get_clob(p_sql => q'[
        SELECT TO_CHAR(employee_id) AS "Emp ID", last_name||', '||first_name AS "Fname", hire_date AS "Date,Hire,YYYYMMDD", salary AS "Salary"
        from hr.employees
        UNION ALL
        SELECT '999' AS "Emp ID", '  Baggins, Bilbo "badboy" ' AS "Fname", TO_DATE('19991231','YYYYMMDD') AS "Date,Hire,YYYYMMDD", 123.45 AS "Salary"
        FROM dual]'
                                    ,p_date_format => 'YYYYMMDD'
                                    ,p_num_format   => '$999,999,999.99'
                                    ,p_right_justify_tab => arr_varchar2_udt('R',NULL)
    )
FROM dual;
```

For this example we include all of the HTML code but trim out most of the data rows from the resultset. You
can see how the table data is wrapped with a **div** and an embedded scoped CSS style 
that has two special overrides for TD tags in columns 1 and 4. We can add more options for the style,
such as perhaps colors and fonts, but I'm not an HTML/CSS guy, so it is slow going. If you would like
to take a wack at it, please fork and send me a Pull request on github when you get something workable.

	<div id="plsql-table">
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
	tr > td:nth-of-type(1) {
	    text-align:right;
	}
	tr > td:nth-of-type(4) {
	    text-align:right;
	}
	</style>
	<table>
	<tr><th>Emp ID</th><th>Fname</th><th>Date,Hire,YYYYMMDD</th><th>Salary</th></tr>
	<tr><td>100</td><td>King, Steven</td><td>20030617</td><td>$24,000.00</td></tr>
	<tr><td>101</td><td>Kochhar, Neena</td><td>20050921</td><td>$17,000.00</td></tr>
	<tr><td>102</td><td>De Haan, Lex</td><td>20010113</td><td>$17,000.00</td></tr>
	<tr><td>999</td><td>  Baggins, Bilbo &quot;badboy&quot; </td><td>19991231</td><td>$123.45</td></tr>
	</table></div>


# Issue with PTF and DATE Functions

Beware if your query produces a calculated date value like TO_DATE('01/01/2021','MM/DD/YYYY') or SYSDATE,
or is from a view that does something similar. This datatype is an "in memory" DATE (as opposed to a schema
object type DATE) and is
not a supported type. It throws the PTF engine into a tizzy. 
You must cast the value to DATE if you want to use it in a PTF:

    SELECT CAST( TO_DATE('01/01/2021','MM/DD/YYYY') AS DATE ) AS mycol
    -- or --
    SELECT CAST(SYSDATE AS DATE) AS mycol

You can't even trap it in the PTF function itself because you don't get
to put any code there; it is generated by the SQL engine before it ever calls the PTF DESCRIBE method.
The *app_html_table_pkg.get_clob* procedure that takes a SQL string as input will trap that error and 
report it in a little more helpful way, but if you are opening your own sys_refcursor, you will get ORA62558,
and the explanation is less than helpful. This [post](https://blog.sqlora.com/en/using-subqueries-with-ptf-or-sql-macros/)
is where I found out about the cause.

I have seen an article that suggests it has been addressed in some releases at least in terms of SQL macros.
The list of supported types in DBMS_TF in 20.3 has
TYPE_EDATE listed as 184, but the query is giving type 13 and calling the PTF with that CTE
is returning ORA-62558 exception. Maybe something about SQL macros works around it, but I haven't
gone there yet and I may not have understood the article.

