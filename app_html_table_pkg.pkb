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

    FUNCTION cursor2html(
        p_src                       SYS_REFCURSOR
        ,p_right_align_col_list     VARCHAR2 := NULL -- comma separated integers in string
        ,p_caption                  VARCHAR2 := NULL
        ,p_css_scoped_style         VARCHAR2 := NULL
        ,p_older_css_support        VARCHAR2 := NULL 
        -- 'G' means nuclear option for gmail, 'Y' means your css cannot be too modern and we need to work harder
        -- like for Outlook clients.
        ,p_odd_line_bg_color        VARCHAR2 := NULL -- header row is 1
        ,p_even_line_bg_color       VARCHAR2 := NULL
    )
    RETURN CLOB
    IS
        c_valid_re CONSTANT VARCHAR2(32) := '^(\s*\d+\s*(,|$))+$';
        c_split_re CONSTANT VARCHAR2(32) := '\s*(\d+)\s*(,|$)';
        v_context           DBMS_XMLGEN.CTXHANDLE;
        v_col               VARCHAR2(4);
        v_clob              CLOB;
        v_css_style         CLOB := NVL(p_css_scoped_style, 
q'!table {
    border: 1px solid black; 
    border-spacing: 0; 
    border-collapse: collapse;
}
caption {
    font-style: italic;
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
!')
|| CASE WHEN p_older_css_support IN ('Y','y') THEN '
td.right { text-align:right; }
td.left { text-align:left; }
'
        ||'tr.odd {'
        ||CASE WHEN p_odd_line_bg_color IS NOT NULL 
            THEN ' background-color: '||p_odd_line_bg_color
          END
        ||' }
tr.even {'
        ||CASE WHEN p_even_line_bg_color IS NOT NULL 
            THEN ' background-color: '||p_even_line_bg_color
          END
        ||' }
'
    END
;
        v_xsl                       CLOB ;
        c_xsl_default      CONSTANT VARCHAR2(1024) := q'!<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="html"/>
 <xsl:template match="/">
    <tr>    
     <xsl:for-each select="/ROWSET/ROW[1]/*">
      <th><xsl:value-of select="name()"/></th>
     </xsl:for-each>
    </tr>
    <xsl:for-each select="/ROWSET/*">
     <tr>
      <xsl:for-each select="./*">
       <td><xsl:value-of select="text()"/> </td>
      </xsl:for-each>
     </tr>
    </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>!';

        invalid_arguments       EXCEPTION;
        PRAGMA exception_init(invalid_arguments, -20881);
        e_null_object_ref       EXCEPTION;
        PRAGMA exception_init(e_null_object_ref, -30625);
    BEGIN

        -- case of good CSS support and we have alternating row color requirement
        IF NVL(p_older_css_support,'x') NOT IN ('Y','y', 'G','g') THEN
            IF p_even_line_bg_color IS NOT NULL THEN
                v_css_style := v_css_style||'tr:nth-child(even) { background-color: '||p_even_line_bg_color||' }
';
            END IF;
            IF p_odd_line_bg_color IS NOT NULL THEN
                v_css_style := v_css_style||'tr:nth-child(odd) { background-color: '||p_odd_line_bg_color||' }
';
            END IF;
        END IF;

        -- We separate out table from the rest of the body with a div and embed a scoped style for it
        v_clob := q'!<div id="plsql-table">
<style type="text/css" scoped>
!'
            ||v_css_style
            ;

        -- case of needing to put code into the XSLT transformation
        IF p_right_align_col_list IS NOT NULL 
                OR (p_older_css_support IN ('G','g') 
                    AND (p_even_line_bg_color IS NOT NULL OR p_odd_line_bg_color IS NOT NULL)
                )
            THEN

            IF p_right_align_col_list IS NOT NULL AND NOT REGEXP_LIKE(p_right_align_col_list, c_valid_re) THEN
                raise_application_error(-20881, 'p_right_align_col_list invalid. Does not match '||c_valid_re);
            END IF;
            IF p_older_css_support IN ('Y','y') THEN -- the midlevel case. Some CSS style support
                -- the mod 2 = 0 goes odd thing is because it does not count the header row.
                -- we want to match what the other code branch does
                v_xsl := q'!<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="html"/>
 <xsl:template match="/">
   <tr>
     <xsl:for-each select="/ROWSET/ROW[1]/*">
      <th><xsl:value-of select="name()"/></th>
     </xsl:for-each>
   </tr>
   <xsl:for-each select="/ROWSET/*">!';
                IF p_right_align_col_list IS NOT NULL THEN
                    v_xsl := v_xsl||q'!
     <xsl:variable name="eoclass">
      <xsl:choose>
       <xsl:when test="position() mod 2 = 0">odd</xsl:when>
       <xsl:otherwise>even</xsl:otherwise>
      </xsl:choose>
     </xsl:variable>
     <tr class="{$eoclass}">
      <xsl:for-each select="./*">
       <xsl:variable name="rightleft">
        <xsl:choose>!';    
                    FOR i IN 1..LENGTH(p_right_align_col_list) -- will be less than this
                    LOOP
                        v_col := REGEXP_SUBSTR(p_right_align_col_list, c_split_re, 1, i, '', 1);
                        EXIT WHEN v_col IS NULL;
                        v_xsl := v_xsl||'
         <xsl:when test="position() = '||LTRIM(v_col,'0')||'">right</xsl:when>';

                    END LOOP;
                    v_xsl := v_xsl||q'!
         <xsl:otherwise>left</xsl:otherwise>
        </xsl:choose>
       </xsl:variable>
       <td class="{$rightleft}"><xsl:value-of select="text()"/></td>!';
                ELSE
                    v_xsl := v_xsl||q'!
       <td><xsl:value-of select="text()"/></td>!';
                END IF;
                v_xsl := v_xsl||q'!
      </xsl:for-each>
     </tr>
   </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>!';
--DBMS_OUTPUT.put_line(v_xsl);
            ELSIF p_older_css_support IN ('G','g') THEN -- nuclear option. everything in the HTML

                -- the mod 2 = 0 goes odd thing is because it does not count the header row.
                -- we want to match what the other code branch does
                v_xsl := q'!<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="html"/>
 <xsl:template match="/">
   <tr>
     <xsl:for-each select="/ROWSET/ROW[1]/*">
      <th><xsl:value-of select="name()"/></th>
     </xsl:for-each>
   </tr>
   <xsl:for-each select="/ROWSET/*">!'
                ;
                IF p_even_line_bg_color IS NOT NULL OR p_odd_line_bg_color IS NOT NULL THEN
                    v_xsl := v_xsl||q'!
     <xsl:variable name="backgroundcolor">
      <xsl:choose>!';
                    IF p_odd_line_bg_color IS NOT NULL THEN
                        v_xsl := v_xsl||q'!
       <xsl:when test="position() mod 2 = 0">!'||p_odd_line_bg_color||q'!</xsl:when>!'
                        ;
                    END IF;
                    IF p_even_line_bg_color IS NOT NULL THEN
                        v_xsl := v_xsl||q'!
       <xsl:when test="position() mod 2 = 1">!'||p_even_line_bg_color||q'!</xsl:when>!'
                        ;
                    END IF;
                    v_xsl := v_xsl||q'!
      </xsl:choose>
     </xsl:variable>
     <tr style="background-color: {$backgroundcolor};">!'
                    ;
                ELSE
                    v_xsl := v_xsl||q'!
     <tr>!';
                END IF;
                v_xsl := v_xsl||q'!
      <xsl:for-each select="./*">!';
                
                IF p_right_align_col_list IS NOT NULL THEN
                    v_xsl := v_xsl||q'!
       <xsl:variable name="rightleft">
        <xsl:choose>!';    
                    FOR i IN 1..LENGTH(p_right_align_col_list) -- will be less than this
                    LOOP
                        v_col := REGEXP_SUBSTR(p_right_align_col_list, c_split_re, 1, i, '', 1);
                        EXIT WHEN v_col IS NULL;
                        v_xsl := v_xsl||'
         <xsl:when test="position() = '||LTRIM(v_col,'0')||'">right</xsl:when>';
                    END LOOP;
                    v_xsl := v_xsl||q'!
         <xsl:otherwise>left</xsl:otherwise>
        </xsl:choose>
       </xsl:variable>
       <td style="text-align: {$rightleft};"><xsl:value-of select="text()"/></td>!';
                ELSE
                    v_xsl := v_xsl||q'!
       <td><xsl:value-of select="text()"/></td>!';
                END IF;
                v_xsl := v_xsl||q'!
      </xsl:for-each>
     </tr>
   </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>!';
--DBMS_OUTPUT.put_line(v_xsl);

            ELSE -- modern CSS

                -- we can put the logic in the css style for the browser
                v_xsl := c_xsl_default;
                    FOR i IN 1..LENGTH(p_right_align_col_list) -- will be less than this
                    LOOP
                        v_col := REGEXP_SUBSTR(p_right_align_col_list, c_split_re, 1, i, '', 1);
                        EXIT WHEN v_col IS NULL;
                        -- just in case, we trim leading zeros
                        v_clob := v_clob||'tr > td:nth-of-type('||LTRIM(v_col, '0')||') {
    text-align:right;
}
';
                    END LOOP;
            END IF;
        ELSE
                v_xsl := c_xsl_default;
        END IF;

        -- end our local style and start the html table section
        v_clob := v_clob||'</style>
<table>
';
        IF p_caption IS NOT NULL THEN
            v_clob := v_clob||'<caption>'||DBMS_XMLGEN.CONVERT(p_caption)||'</caption>
'; 
        END IF;
--DBMS_OUTPUT.put_line('v_xsl:'||v_xsl);
--DBMS_OUTPUT.put_line('v_clob:'||v_clob);

        v_context := DBMS_XMLGEN.newcontext(p_src);
        DBMS_XMLGEN.setNullHandling(v_context,1);
        BEGIN
            v_clob := v_clob||REPLACE( -- replace munged spaces in column headers
                DBMS_XMLGEN.GETXMLType(v_context, DBMS_XMLGEN.NONE).transform(XMLType(v_xsl)).getClobVal()
                ,'_x0020_', ' '
            );
            -- end the table and our div that included the local style
            v_clob := v_clob||'</table></div>';
        EXCEPTION WHEN e_null_object_ref THEN 
            v_clob := NULL;
            DBMS_OUTPUT.put_line('cursor2html executed cursor that returned no rows. Returning NULL');
        END;

        RETURN v_clob;

    END cursor2html;

    FUNCTION query2html(
        p_sql                       CLOB
        ,p_right_align_col_list     VARCHAR2 := NULL -- comma separated integers in string
        ,p_caption                  VARCHAR2 := NULL
        ,p_css_scoped_style         VARCHAR2 := NULL
        ,p_older_css_support        VARCHAR2 := NULL -- 'Y' 'G' or null/'N'
        ,p_odd_line_bg_color        VARCHAR2 := NULL
        ,p_even_line_bg_color       VARCHAR2 := NULL
    ) 
    RETURN CLOB
    IS
        v_src       SYS_REFCURSOR;
        v_clob      CLOB;
    BEGIN
        OPEN v_src FOR p_sql;
        v_clob := cursor2html(
                p_src                   => v_src
                ,p_right_align_col_list => p_right_align_col_list
                ,p_caption              => p_caption
                ,p_css_scoped_style     => p_css_scoped_style
                ,p_older_css_support    => p_older_css_support
                ,p_odd_line_bg_color    => p_odd_line_bg_color
                ,p_even_line_bg_color   => p_even_line_bg_color
            );
        BEGIN
            CLOSE v_src;
            EXCEPTION WHEN invalid_cursor THEN NULL;
        END;
        RETURN v_clob;
    END query2html;

END app_html_table_pkg;
/
show errors
