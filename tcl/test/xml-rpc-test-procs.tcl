# /packages/xml-rpc/tcl/test/xml-rpc-test-procs.tcl
ad_library {
     Test the XML-RPC interface
     @author Vinod Kurup [vinod@kurup.com]
     @creation-date Sat Oct 25 10:49:55 2003
     @cvs-id $Id$
}

aa_register_case -cats script xml_rpc_mounted {
    Test to make sure the xml-rpc package has been mounted
} {
    aa_run_with_teardown -rollback -test_code {
        aa_false "XML-RPC url not null" [empty_string_p [xmlrpc::url]]
    }
}

aa_register_case -cats script xml_rpc_fault {
    Test the fault generation code
} {
    set expected_code 22
    set expected_string "my error message with <b>html</b> codes"

    aa_run_with_teardown -rollback -test_code {
        set result [xmlrpc::fault $expected_code $expected_string]
        
        # extract faultCode and faultString
        set doc [xml_parse -persist $result]
        set value_node [xml_node_get_first_child [xml_node_get_first_child [xml_doc_get_first_node $doc]]]
        array set fault [xmlrpc::decode_value $value_node]
        xml_doc_free $doc

        aa_equals "Proper faultCode" $fault(faultCode) $expected_code
        aa_equals "Proper faultString" $fault(faultString) $expected_string
    }
}

ad_proc -private xmlrpc_decode_test_prep { value } { 
    Takes the contents of a &lt;value> node, calls xmlrpc::decode_value and
    returns the result. This is done repeatedly in the xml_rpc_decode_value
    test, so I broke it out into a separate function for that purpose 
} {
    set doc [xml_parse -persist "<value>$value</value>"]
    set result [xmlrpc::decode_value [xml_doc_get_first_node $doc]]
    xml_doc_free $doc
    return $result

}

aa_register_case -cats script xml_rpc_decode_value {
    Test xmlrpc::decode_value to be sure it decodes properly
} {
    aa_run_with_teardown -rollback -test_code {
        set result [xmlrpc_decode_test_prep "<string>a string</string>"]
        aa_equals "string test" $result "a string"

        set result [xmlrpc_decode_test_prep "- a naked string"]
        aa_equals "naked string test" $result "- a naked string"
        
        set result [xmlrpc_decode_test_prep "<int>22</int>"]
        aa_equals "int test" $result 22

        set result [xmlrpc_decode_test_prep "<int>33</int>"]
        aa_equals "i4 test" $result 33

        set result [xmlrpc_decode_test_prep "<double>3.1415</double>"]
        aa_equals "double test" $result 3.1415

        set result [xmlrpc_decode_test_prep "<boolean>1</boolean>"]
        aa_equals "boolean test 1" $result 1

        set result [xmlrpc_decode_test_prep "<boolean>f</boolean>"]
        aa_equals "boolean test 2" $result 0

        set result [xmlrpc_decode_test_prep "<dateTime.iso8601>20030821T083122</dateTime.iso8601>"]
        aa_equals "date test" $result 1061469082


        unset result
        array set result [xmlrpc_decode_test_prep "<struct><member><name>id</name><value><int>19</int></value></member><member><name>content</name><value><string>My content</string></value></member></struct>"]
        aa_equals "struct test 1" $result(id) 19
        aa_equals "struct test 2" $result(content) "My content"

        unset result 
        set result [xmlrpc_decode_test_prep "<array><data><value>phrase 1</value><value>2nd phrase</value><value>final phrase</value></data></array>"]
        aa_equals "array test 1" [lindex $result 0] "phrase 1"
        aa_equals "array test 2" [lindex $result 1] "2nd phrase"
        aa_equals "array test 3" [lindex $result 2] "final phrase"

        unset result
        set result [xmlrpc_decode_test_prep "<array><data><value>phrase 1</value><value><struct><member><name>sublist</name><value><array><data><value>Got it!</value></data></array></value></member></struct></value></data></array>"]
        array set struct [lindex $result 1]
        aa_equals "array inside struct inside array" [lindex $struct(sublist) 0] "Got it!"
    }
}

aa_register_case -cats script xml_rpc_respond {
    Test the response generation code
} {
    set expected_data "my data"

    aa_run_with_teardown -rollback -test_code {
        set result [xmlrpc::respond $expected_data]
        
        # extract data
        set doc [xml_parse -persist $result]
        set value_node [xml_node_get_first_child [xml_node_get_first_child [xml_node_get_first_child [xml_doc_get_first_node $doc]]]]
        set data [xmlrpc::decode_value $value_node]
        xml_doc_free $doc

        aa_equals "Proper data" $data $expected_data
    }
}

aa_register_case -cats script xml_rpc_construct {
    Test the construction code
} {

    aa_run_with_teardown -rollback -test_code {
        # use testcases from the ad_proc documentation

        # int test
        set arglist {-int 33} 
        set result [xmlrpc::construct {} $arglist]
        aa_equals "int contruction" $result "<i4>33</i4>"

        # array test
        set arglist {-array {
            {-int 6682} 
            {-boolean 0} 
            {-text Iowa} 
            {-double 8931.33333333} 
            {-date {Fri Jan 01 05:41:30 EST 1904}}}}
 
        set result [xmlrpc::construct {} $arglist]
        aa_equals "array construction" $result "<array><data><value><i4>6682</i4></value><value><boolean>0</boolean></value><value><string>Iowa</string></value><value><double>8931.33333333</double></value><value><dateTime.iso8601>19040101T05:41:30</dateTime.iso8601></value></data></array>"

        # struct test
        set arglist {-struct {
            ctLeftAngleBrackets {-int 5} 
            ctRightAngleBrackets {-int 6} 
            ctAmpersands {-int 7} 
            ctApostrophes {-int 0} 
            ctQuotes {-int 3}}}
        
        set result [xmlrpc::construct {} $arglist]
        aa_equals "struct test" $result "<struct><member><name>ctLeftAngleBrackets</name><value><i4>5</i4></value></member><member><name>ctRightAngleBrackets</name><value><i4>6</i4></value></member><member><name>ctAmpersands</name><value><i4>7</i4></value></member><member><name>ctApostrophes</name><value><i4>0</i4></value></member><member><name>ctQuotes</name><value><i4>3</i4></value></member></struct>"
    }

    # test context parameter
    set arglist {-int 33}
    set result [xmlrpc::construct "foo bar" $arglist]
    aa_equals "context test" $result "<foo><bar><i4>33</i4></bar></foo>"

}

aa_register_case -cats web xml_rpc_validate {
    Test the standard XML-RPC validation suite
} {

    # run the validation suite specified in validator-procs.tcl
    # if those procs change, this proc needs to change too
    set test_list \
        [list \
             arrayOfStructsTest 6 \
             countTheEntities {ctLeftAngleBrackets 4 ctRightAngleBrackets 4 ctAmpersands 9 ctApostrophes 7 ctQuotes 1} \
             easyStructTest 6 \
             echoStructTest {bob 5} \
             manyTypesTest {1 0 wazzup 3.14159 994261830 R0lGODlhFgASAJEAAP/////OnM7O/wAAACH5BAEAAAAALAAAAAAWABIAAAJAhI+py40zDIzujEDBzW0n74AaFGChqZUYylyYq7ILXJJ1BU95l6r23RrRYhyL5jiJAT/Ink8WTPoqHx31im0UAAA7} \
             moderateSizeArrayCheck {WisconsinNew York} \
             nestedStructTest 7 \
             simpleStructReturnTest {times1000 2000 times100 200 times10 20}
        ]
    set url [ad_url][xmlrpc::url]

    aa_run_with_teardown -rollback -test_code {
        foreach {test_name expected} $test_list {
            set result [validate1.$test_name $url]
            aa_equals $test_name $result $expected
        }
    }
}
