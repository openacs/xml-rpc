# /packages/xml-rpc/www/admin/toggle.tcl
ad_page_contract {
     Toggle the server status
     @author Vinod Kurup [vinod@kurup.com]
     @creation-date Sat Oct 11 01:10:06 2003
     @cvs-id $Id$
} {
}

parameter::set_from_package_key \
    -package_key xml-rpc \
    -parameter EnableXMLRPCServer \
    -value [string is false [xmlrpc::enabled_p]]

ad_returnredirect ./