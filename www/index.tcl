# /packages/xml-rpc/www/index.tcl
ad_page_contract {
    Accept XML-RPC POST requests and processes them. GET requests are shown
    links to the admin pages or docs.

    @author Vinod Kurup [vinod@kurup.com]
    @creation-date Mon Sep 29 23:35:14 2003
    @cvs-id $Id$
} {
}

if {[string equal [ns_conn method] POST]} {
    set content [xmlrpc::get_content]
    ns_return 200 text/xml [xmlrpc::invoke $content]
    return
}

# GET requests fall through to index.adp
