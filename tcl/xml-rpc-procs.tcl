# /packages/xml-rpc/tcl/xml-rpc-procs.tcl
ad_library {
    <p>
    Initially created by Dave Bauer 2001-03-30 with inspiration from
    Steve Ball and help from Aaron Swartz and Jerry Asher.
    </p>
    <p>
    Modified by Vinod Kurup to 
    <ol>
    <li>Use the xml abstraction procs in 
    packages/acs-tcl/tcl/30-xml-utils-procs.tcl (which use tDom now) </li>
    <li>Fit in OpenACS 5 framework </li>
    </ol>
    </p>

    @author Vinod Kurup [vinod@kurup.com]
    @creation-date 2003-09-30
    @cvs-id $Id$
}

# setup nsv array to hold procs that are registered for xml-rpc access
nsv_array set xmlrpc_procs [list]

namespace eval xmlrpc {}

ad_proc -public xmlrpc::url {} {
    @return the URL that is listening for RPC requests

    @author Vinod Kurup
} {
    # ok to use this since this is a singleton package.
    return [apm_package_url_from_key xml-rpc]
}
    
ad_proc -public xmlrpc::enabled_p {} {
    @return whether the server is enabled
} {
    return [parameter::get_from_package_key \
                -package_key xml-rpc \
                -parameter EnableXMLRPCServer]
}

ad_proc -public xmlrpc::list_methods {} {
    @return alphabetical list of XML-RPC procs on this server
} {
    return [lsort [nsv_array names xmlrpc_procs]]
}

ad_proc -private xmlrpc::get_content {} {
    There's no [ns_conn content] so this is a hack to get the content of the 
    XML-RPC request. Taken from ns_xmlrpc.

    @return string - the XML request
    @author Dave Bauer
} {
    # (taken from aol30/modules/tcl/form.tcl)
    # Spool content into a temporary read/write file.
    # ns_openexcl can fail, since tmpnam is known not to
    # be thread/process safe.  Hence spin till success
    set fp ""
    while {$fp == ""} {
        set filename "[ns_tmpnam][clock clicks -milliseconds].xmlrpc2"
        set fp [ns_openexcl $filename]
    }

    fconfigure $fp -translation binary
    ns_conncptofp $fp
    close $fp

    set fp [open $filename r]
    while {![eof $fp]} {
        append text [read $fp]
    }
    close $fp
    ns_unlink $filename
    return $text
}

ad_proc -private xmlrpc::fault {
    code
    msg
} {
    Format a fault response to a XML-RPC request

    @param code  error code (integer)
    @param msg   error message

    @return XML-RPC fault message
} {
    # we could build this with the tDom commands, but it's quite a pain
    # and I don't see the benefit for our simple needs - vinodk
    set result "<?xml version=\"1.0\"?>
<methodResponse>
  <fault>
    <value>
      <struct>
        <member>
          <name>faultCode</name>
          <value><i4>$code</i4></value>
        </member>
        <member>
          <name>faultString</name>
          <value><string>[ad_quotehtml $msg]</string></value>
        </member>
      </struct>
    </value>
  </fault>
</methodResponse>
"
                        
    # now re-parse and then re-extract to make sure it's well formed
    set doc [xml_parse -persist $result]
    if { [catch {xml_doc_render $doc} result] } {
        return -code error \
            "xmlrpc::fault XML is not well formed. error = $result"
    }
    xml_doc_free $doc
    return $result
}

ad_proc -public xmlrpc::register_proc {
    proc_name
} {
    <p>
    Register a proc to be available via XML-RPC. <code>proc_name</code> is
    the name of a proc that is defined in the usual OpenACS way (i.e. ad_proc).
    The <code>proc_name</code> is added to the xmlrpc_procs nsv array with a 
    value of 1. When an XML-RPC call comes in, this array is searched to see 
    if the proc_name has been registered. Currently, the presence of 
    <code>proc_name</code> in the nsv is enough to indicate
    that the proc can be called via XML-RPC. At some point we may allow
    administrators to disable procs, so we could set the value associated
    with <code>proc_name</code> from 1 to 0.
    </p>

    @param proc_name Name of proc to be registered.
    @return nothing
} {
    nsv_set xmlrpc_procs $proc_name 1
}


ad_proc -private xmlrpc::decode_value {
    node
} {
    Unpack the data in a value element. Most value elements will have a 
    subnode describing the datatype (e.g &lt;string> or &lt;int>). If no 
    subnode is present, then we should assume the value is a string.

    @param node &lt;value> node that we're decoding
    @return Returns the contents of the &lt;value> node. If the value is 
    a &lt;struct> then returns the data in a TCL array. If the value is an 
    &lt;array> then returns the data in a TCL list.
} {
    set result ""
    if {[llength [xml_node_get_children $node]]} {  
        # subnode is specified
        set subnode [xml_node_get_first_child $node]
        set datatype [xml_node_get_name $subnode]

        switch -- $datatype {
            string -
            i4 -
            int -
            double -
            base64 {
                set result [xml_node_get_content $subnode]
            }
            
            boolean {
                set result [string is true [xml_node_get_content $subnode]]
            }

            dateTime.iso8601 {
                set result [clock scan [xml_node_get_content $subnode]]
            }
            
            struct {
                foreach member \
                    [xml_node_get_children_by_name $subnode member] {
                        lappend result \
                            [xml_node_get_content \
                                 [xml_node_get_children_by_name \
                                      $member name]]
                        lappend result \
                            [xmlrpc::decode_value \
                                 [xml_node_get_children_by_name \
                                      $member value]]
                    }
            }

            array {
                foreach entry [xml_node_get_children \
                                   [xml_node_get_children_by_name \
                                        $subnode data]] {
                    lappend result [xmlrpc::decode_value $entry]
                }
            }
            
            default {
                # we received a tag which is not a recognized datatype.
                ns_log notice xmlrpc::decode_value ignored type: $datatype
            }
        }
    } else {
        # no datatype subnode, therefore it's a string
        set result [xml_node_get_content $node]
    }
    return $result
}

ad_proc -private xmlrpc::respond {
    data
} {
    Format a success response to an XML-RPC request

    @param data data to be returned to the client
    @return data encoded in a properly formed XML-RPC response
} {
    set result "<?xml version=\"1.0\"?><methodResponse><params><param><value>"
    append result [xmlrpc::construct {} $data]
    append result "</value></param></params></methodResponse>"

    # now re-parse and then re-extract to make sure it's well formed
    set doc [xml_parse -persist $result]
    if { [catch {xml_doc_render $doc} result] } {
        return -code error \
            "xmlrpc::respond XML is not well formed. err = $result"
    }
    xml_doc_free $doc
    return $result
}

ad_proc -private xmlrpc::construct {
    context
    arglist
} {
    <p>
    Construct an XML-RPC element. <code>arglist</code> is a 2-element list 
    which is converted to XML. The first element of <code>arglist</code> is 
    the datatype and the second element is the value.
    </p>
    Example: 
    <pre>
    set arglist {-int 33} 
    set result [xmlrpc::construct {} $arglist]
    set result ==> &lt;i4>33&lt;/i4>
    </pre>
    <p>
    This proc works recursively, so if your top level list has a list within
    it, then that list will be processed first. The two examples of this are
    arrays and structs. In addition, structs and arrays can contain each
    other.
    </p>
    Array example: 
    <pre>
    set arglist {-array {
        {-int 6682} 
        {-boolean 0} 
        {-text Iowa} 
        {-double 8931.33333333} 
        {-date {Fri Jan 01 05:41:30 EST 1904}}}}
 
    set result [xmlrpc::construct {} $arglist]
    set result ==>  &lt;array>
                    &lt;data>
                        &lt;value>
                            &lt;i4>6682&lt;/i4>
                        &lt;/value>
                        &lt;value>
                            &lt;boolean>0&lt;/boolean>
                        &lt;/value>
                        &lt;value>
                            &lt;string>Iowa&lt;/string>
                        &lt;/value>
                        &lt;value>
                            &lt;double>8931.33333333&lt;/double>
                        &lt;/value>
                        &lt;value>
                            &lt;dateTime.iso8601>19040101T05:41:30&lt;/dateTime.iso8601>
                        &lt;/value>
                    &lt;/data>
                &lt;/array>
    </pre>
    <p>
    <code>struct</code>'s have the special format: <code>-struct {name1 {-datatype1 value1} name2 {-datatype2 value2}}</code>
    </p>
    Struct Example:
    <pre>
    set arglist {-struct {
        ctLeftAngleBrackets {-int 5} 
        ctRightAngleBrackets {-int 6} 
        ctAmpersands {-int 7} 
        ctApostrophes {-int 0} 
        ctQuotes {-int 3}}}

    set result [xmlrpc::construct {} $arglist]
    set result ==>  &lt;struct>
                    &lt;member>
                        &lt;name>ctLeftAngleBrackets&lt;/name>
                        &lt;value>
                            &lt;i4>5&lt;/i4>
                        &lt;/value>
                    &lt;/member>
                    &lt;member>
                        &lt;name>ctRightAngleBrackets&lt;/name>
                        &lt;value>
                            &lt;i4>6&lt;/i4>
                        &lt;/value>
                    &lt;/member>
                    &lt;member>
                        &lt;name>ctAmpersands&lt;/name>
                        &lt;value>
                            &lt;i4>7&lt;/i4>
                        &lt;/value>
                    &lt;/member>
                    &lt;member>
                        &lt;name>ctApostrophes&lt;/name>
                        &lt;value>
                            &lt;i4>0&lt;/i4>
                        &lt;/value>
                    &lt;/member>
                    &lt;member>
                        &lt;name>ctQuotes&lt;/name>
                        &lt;value>
                            &lt;i4>3&lt;/i4>
                        &lt;/value>
                    &lt;/member>
                &lt;/struct>
    </pre>
    <p>
    The context parameter is used internally to create tags within tags.
    </p>
    Example:
    <pre>
    set arglist {-int 33}
    set result [xmlrpc::construct {foo bar} $arglist]
    set result ==> &lt;foo>&lt;bar>&lt;i4>33&lt;/i4>&lt;/bar>&lt;/foo>
    </pre>

    @param context extra tags to wrap around the data
    @param arglist datatype-value list (or more complex types as described
                   above)

    @return XML formatted result
} {
    set result ""
    # list of valid options
    set options_list [list "-string" "-text" "-i4" "-int" "-integer" \
			  "-boolean" "-double" "-date" "-binary" "-base64" \
			  "-variable" "-structvariable" "-struct" \
			  "-array" "-keyvalue"]

    # if no valid option is specified, treat it as string
    if {[lsearch $options_list [lindex $arglist 0]] == -1} {
        set value "<string>[ad_quotehtml $arglist]</string>"
        return [xmlrpc::create_context $context $arglist]
    }

    if { [llength $arglist] % 2} {
        # datatype required for each value
        return -code error \
                "no value for option \"[lindex $arglist end]\""
    }
    
    foreach {option value} $arglist {
        switch -- $option {
            -string -
            -text {
                set value "<string>[ad_quotehtml $value]</string>"
                append result [xmlrpc::create_context $context $value]
            }

            -i4 -
            -int -
            -integer {
                if {![string is integer $value]} {
                    return -code error \
                        "value \"$value\" for option \"$option\" is not an integer:"
                }
                set value "<i4>$value</i4>"
                append result [xmlrpc::create_context $context $value]
            }

            -boolean {
                set value "<boolean>[string is true $value]</boolean>"
                append result [xmlrpc::create_context $context $value]
            }

            -double {
                if {![string is double $value]} {
                    return -code error \
                        "value \"$value\" for option \"$option\" is not a floating point value"
                }
                set value "<double>$value</double>"
                append result [xmlrpc::create_context $context $value]
            }

            -date {
                if {[catch {clock format [clock scan $value] \
                                -format {%Y%m%dT%T} } datevalue]} {
                    return -code error \
                        "value \"$value\" for option \"$option\" is not a valid date ($datevalue)"
                }
                
                set value "<dateTime.iso8601>$datevalue</dateTime.iso8601>"
                append result [xmlrpc::create_context $context $value]
            }

            -binary -
            -base64 {                
                # it is up to the application to do the encoding
                # before the data gets here
                set value "<base64>$value</base64>"
                append result [xmlrpc::create_context $context $value]
            }

            -array {
                set data "<array><data>"
                foreach datum $value {
                    append data [xmlrpc::construct value $datum]
                }
                append data "</data></array>"
                append result [xmlrpc::create_context $context $data]
            }
            
            -struct -
            -keyvalue {
                set data "<struct>" 
                foreach {name mvalue} $value {
                    append data "<member><name>[ad_quotehtml $name]</name>"
                    append data [xmlrpc::construct value $mvalue]
                    append data "</member>"
                }
                append data "</struct>"
                append result [xmlrpc::create_context $context $data]
            }

            default {
                # anything else will be ignored
                ns_log notice xmlrpc::construct ignored option: $option \
                    with value: $value
            }
        }
    }
    
    return $result
}

ad_proc -private xmlrpc::create_context {
    context
    value
} {
    Return the value wrapped in appropriate context tags. If context is
    a list of items, then the result will be wrapped in multiple tags. 
    Example:
    <pre>
    xmlrpc::create_context {param value} 78
    returns ==> "<param><value>78</value></param>"
    </pre>

    @param context context to create 
    @param value character data
    @return string with value wrapped in context tags
} {
    # reverse the list (algorithm from TCL Wiki)
    set r_context {}
    set i [llength $context]
    while {$i} {lappend r_context [lindex $context [incr i -1]]}

    set result "$value"
    foreach child_name $r_context {
        set result "<$child_name>$result</$child_name>"
    }

    return $result
}

ad_proc -public xmlrpc::remote_call {
    url
    method
    {args ""}
} {
    Invoke a method on a remote server using XML-RPC

    @param url url of service
    @param method method to call
    @param args list of args to the method

    @return the response of the remote service. Error if remote service returns
    a fault.
} {
    set call "<?xml version=\"1.0\"?><methodCall><methodName>$method</methodName>"
    append call "<params>"
    if { [llength $args] } {
        append call [xmlrpc::construct {param value} $args]
    }
    append call "</params></methodCall>"

    # now re-parse and then re-extract to make sure it's well formed
    set doc [xml_parse -persist $call]
    if { [catch {xml_doc_render $doc} request] } {
        return -code error \
            "xmlrpc::fault XML is not well formed. error = $request"
    }
    xml_doc_free $doc

    # make the call
    if {[catch {xmlrpc::httppost -url $url -content $request } response ]} {
        ns_log error xmlrpc::remote_call \
            url: $url request: $request error: $response
        return -code error [list HTTP_ERROR \
                                "HTTP request failed due to \"$response\""]
    }
    return [xmlrpc::parse_response $response]
}

ad_proc -private xmlrpc::httppost {
    -url
    {-timeout 30}
    {-depth 0}
    -content
} {
    The proc util_httppost doesn't work for our needs. We need to send
    Content-type of text/xml and we need to send a Host header. So, roll 
    our own XML-RPC HTTP POST. Wait - lars-blogger sends out XML-RPC pings
    to weblogs.com. I'll steal the POST code from there and simplify that
    call.
    
    @author Vinod Kurup    
} {
    if {[incr depth] > 10} {
        return -code error "xmlrpc::httppost: Recursive redirection: $url"
    }
    set req_hdrs [ns_set create]

    # headers necesary for a post and the form variables
    ns_set put $req_hdrs Accept "*/*"
    ns_set put $req_hdrs User-Agent "[ns_info name]-Tcl/[ns_info version]"
    ns_set put $req_hdrs "Content-type" "text/xml"
    ns_set put $req_hdrs "Content-length" [string length $content]

    set http [ns_httpopen POST $url $req_hdrs 30 $content]
    set rfd [lindex $http 0]
    set wfd [lindex $http 1]
    set rpset [lindex $http 2]

    flush $wfd
    close $wfd

    set headers $rpset
    set response [ns_set name $headers]
    set status [lindex $response 1]

    # follow 302
    if {$status == 302} {
        set location [ns_set iget $headers location]
        if {$location != ""} {
            ns_set free $headers
            close $rfd
            set page [xmlrpc::httppost -url $location \
                          -timeout $timeout -depth $depth -content $content]
        }
    } else {
        set length [ns_set iget $headers content-length]
        if [string match "" $length] {set length -1}
        set err [catch {
            while 1 {
                set buf [_ns_http_read $timeout $rfd $length]
                append page $buf
                if [string match "" $buf] break
                if {$length > 0} {
                    incr length -[string length $buf]
                    if {$length <= 0} break
                }
            }
        } errMsg]
        ns_set free $headers
        close $rfd
        if $err {
            global errorInfo
            return -code error -errorinfo $errorInfo $errMsg
        }
    }    
    return $page
}

ad_proc -private xmlrpc::parse_response {xml} {
    Parse the response from a XML-RPC call.

    @param xml the XML response
    @return result 
} {
    set doc [xml_parse -persist $xml]
    set root [xml_doc_get_first_node $doc]

    if { ![string equal [xml_node_get_name $root] "methodResponse"] } {
        set root_name [xml_node_get_name $root]
        xml_doc_free $doc
        return -code error "xmlrpc::parse_response: invalid server reponse - root node is not methodResponse. it's $root_name"
    }
    
    set node [xml_node_get_first_child $root]
    switch -- [xml_node_get_name $node] {
        params {
            # need more error checking here.
            # if the response is not well formed, we'll probably
            # get an error, but it may be hard to track down
            set param [xml_node_get_first_child $node]
            set value [xml_node_get_first_child $param]
            set result [xmlrpc::decode_value $value]
        }
        fault {
            # should do more checking here...
            array set fault [xmlrpc::decode_value \
                                 [xml_node_get_first_child $node]]
            xml_doc_free $doc
            return -code error -errorcode $fault(faultCode) $fault(faultString)
        }
        default {
            set type [xml_node_get_name $node]
            xml_doc_free $doc
            return -code error "xmlrpc::parse_response: invalid server response ($type)"
        }
    }
    xml_doc_free $doc

    return $result
}

ad_proc -private xmlrpc::invoke {
    xml
} {
    Take the XML-RPC request and invoke the method on the server.
    The methodName element contains the Tcl procedure to evaluate. The
    method is called from the global stack level.

    @param xml XML-RPC data from the client
    @return result encoded in XML and ready for return to the client
} {
    # check that the XML-RPC Server is enabled
    if { ![xmlrpc::enabled_p] } {
        set result [xmlrpc::fault 3 "XML-RPC Server disabled"]
        ns_log error "xmlrpc::invoke fault $result"
        return $result
    }

    ns_log debug "xmlrpc::invoke REQUEST: $xml"
    if {[catch {set doc [xml_parse -persist $xml]} err_msg]} {
        set result [xmlrpc::fault 1 "error parsing request: $err_msg"]
        ns_log error "xmlrpc::invoke: error parsing request: $err_msg"
    } else {
        # parse OK - get data
        set data [xml_doc_get_first_node $doc]

        set method_name \
            [xml_node_get_content \
                 [lindex \
                      [xml_node_get_children_by_name $data methodName] 0 ]]

        set arguments [list]
        set params [xml_node_get_children_by_name $data params]
        foreach parameter [xml_node_get_children_by_name $params param] {
            lappend arguments \
                [xmlrpc::decode_value [xml_node_get_first_child $parameter]]
        }

        set errno [catch {xmlrpc::invoke_method $method_name $arguments} result]
        if { $errno } {
            set result [xmlrpc::fault $errno $result]
	    global errorInfo
            ns_log error "xmlrpc_invoke: error in xmlrpc method REQUEST: $xml RESULT: $result\n$errorInfo"
        } else {
            # success
            set result [xmlrpc::respond $result]
            ns_log debug "xmlrpc::invoke result $result"
        }
    }
    xml_doc_free $doc

    return $result
}

ad_proc -private xmlrpc::invoke_method {
    method_name
    arguments
} {
    Call the given method on the OpenACS server. It's up to the caller
    to catch any error that we get.

    @param method_name methodName from XML-RPC
    @param arguments list of arguments
    @return result of the OpenACS proc
    @author Vinod Kurup
} {
    # check that the method is registered as a valid XML-RPC method
    if {![nsv_exists xmlrpc_procs $method_name]} {
        return -code error -errorcode 2 "methodName $method_name doesn't exist"
    }
    ns_log debug "xmlrpc::invoke_method method $method_name args $arguments"
    set result [uplevel #0 [list $method_name] $arguments]
    return $result
}
