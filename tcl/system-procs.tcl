# /packages/xml-rpc/tcl/system-procs.tcl
ad_library {
    Standard reserved nmethods
    http://xmlrpc.usefulinc.com/doc/reserved.html

    @author Vinod Kurup [vinod@kurup.com]
    @creation-date Thu Oct  9 22:14:04 2003
    @cvs-id $Id$
}

ad_proc -public system.listMethods {} {
    Enumerate the methods implemented by the XML-RPC server.

    The system.listMethods method requires no parameters. 

    @return an array of strings, each of which is the name of a method 
    implemented by the server.
    @author Vinod Kurup
} {
    set result [list]
    foreach proc_name [xmlrpc::list_methods] {
        lappend result [list -string $proc_name]
    }

    return [list -array $result]
}

# system.methodSignature not implemented because we don't keep track of 
# parameter types or return types

ad_proc -public system.methodHelp {
    methodName
} {    
    This method takes one parameter, the name of a method implemented by 
    the XML-RPC server.

    @param methodName method implemented in XML-RPC
    @return a documentation string describing the use of that method. 
    If no such string is available, an empty string is returned. The 
    documentation string may contain HTML markup.
    @author Vinod Kurup
} {
    return [list -string [api_proc_documentation $methodName]]
}

ad_proc -public system.multicall {
    array
} {
    <p>
    Perform multiple requests in one call - see 
    http://www.xmlrpc.com/discuss/msgReader$1208
    </p>

    <p>
    Takes an array of XML-RPC calls encoded as structs of the form (in a 
    Pythonish notation here):
    <pre>
    {'methodName': string, 'params': array}
    </pre>
    </p>
    @param array  array of structs containing XML-RPC calls
    @return an array of responses. There will be one response for each call 
    in the original array. The result will either be a one-item array 
    containing the result value - this mirrors the use of &lt;params> in 
    &lt;methodResponse> - or a struct of the form found inside the 
    standard &lt;fault> element.
    @author Vinod Kurup
} {
    set responses [list]

    foreach call $array {
        # parse the call for methodName and params
        if { [catch {
            array unset c
            array set c $call
            set method $c(methodName)
            set params $c(params) 
        } errmsg ] } {
            # if we can't get a methodName and params, then fault
            lappend responses [list -struct \
                                   [list faultCode [list -int 5] \
                                        faultString "Invalid request. $errmsg"
                                   ]]
        } else {
            # call the method
            set errno [catch {xmlrpc::invoke_method $method $params} result]
            if { $errno } {
                # fault
                lappend responses [list -struct \
                                       [list faultCode [list -int $errno] \
                                            faultString $result]]
            } else {
                lappend responses $result
            }
        }
    }
    return [list -array $responses]
}

ad_proc -public system.add {
    args
} {
    Simple test function.
    Add a variable number of integers.

    @param args variable number of integers
    @return integer sum
} {
    set sum 0
    foreach value $args {
        incr sum $value
    }
    return [list -int $sum]
}
