# /packages/xml-rpc/www/admin/index.tcl
ad_page_contract {
     Front page of admin
     @author Vinod Kurup [vinod@kurup.com]
     @creation-date Thu Oct  9 15:22:41 2003
     @cvs-id $Id$
} {
} -properties {
    rpc_url:onevalue
    server_enabled_p:onevalue
    rpc_procs:multirow
}

set rpc_url [ad_url][xmlrpc::url]
set server_enabled_p [xmlrpc::enabled_p]

multirow create rpc_procs name enabled_p

foreach proc_name [xmlrpc::list_methods] {
    if { $server_enabled_p } {
        set enabled_p [ad_decode [nsv_get xmlrpc_procs $proc_name] 0 No Yes]
    } else {
        set enabled_p No
    }

    set proc_name [api_proc_link $proc_name]
    multirow append rpc_procs $proc_name $enabled_p
}
