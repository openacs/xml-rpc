# /packages/xml-rpc/tcl/system-init.tcl
ad_library {
     Register standard system procs
     @author Vinod Kurup [vinod@kurup.com]
     @creation-date Thu Oct  9 22:21:14 2003
     @cvs-id $Id$
}

xmlrpc::register_proc system.listMethods
xmlrpc::register_proc system.methodHelp
xmlrpc::register_proc system.multicall
xmlrpc::register_proc system.add
