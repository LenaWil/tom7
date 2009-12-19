<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="/rss">
<html>
    <head>
        <title><xsl:value-of select="channel/title"/></title>
    </head>
    <body style="margin: 20px;font-family:Arial,Helvetica,Verdana,sans-serif;font-size:12px;">
        <div style="margin-bottom:25px;width:500px; line-height: 1.45em; font-size: 12px; padding: 12px 125px 12px 25px;color: #666;border: 1px solid #CCC;">
        <p>This RSS feed is meant for newsreaders, not web browsers. Please visit the <a href="http://escape.spacebar.org/">escape home page</a> to browse content.</p>
        </div>

        <p>Items in this feed:</p>
        <ul>
        <xsl:for-each select="channel/item">
            <li>
                <p><strong><a><xsl:attribute name="href"><xsl:value-of select="guid"/></xsl:attribute><xsl:value-of select="title"/></a></strong>
		</p>
            </li>
        </xsl:for-each>
        </ul>
    </body>
</html>
</xsl:template>
</xsl:stylesheet>
