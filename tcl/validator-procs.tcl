# /packages/xml-rpc/tcl/validator-procs.tcl
ad_library {
    XML-RPC Validation Test
    Written by, Aaron Swartz <aaron@theinfo.org>
    Enhanced by Jerry Asher <jerry@theashergroup.com>
    Edited for xml-rpc package by Vinod Kurup <vinod@kurup.com>
    contains:
        xml-rpc server validation implementation
        xml-rpc client validator test implementation

    @creation-date Thu Oct  9 22:14:04 2003
    @cvs-id $Id$
}

############################################################
# The xml-rpc client validator procedures begin here:

# Takes an array, each of whose members is a struct.  Return the
# sum of all the values named curly from each struct.


proc validator1.arrayOfStructsTest {params} {
    set number 0
    foreach {param} $params {
        array set struct $param
        incr number $struct(curly)
    }
    return [list -int $number]
}


# Takes a string.
# Return the number of each entity in a struct.

proc validator1.countTheEntities {args} {
    set string $args
        
    # For each type of entity, do a regsub -all and return the result as an 
    # integer, then place it all in a struct with the proper names and return 
    # it.

    return \
        [list -struct \
             [list ctLeftAngleBrackets  \
                  [list -int [regsub -all {\<} $string "" string]] \
                  ctRightAngleBrackets \
                  [list -int [regsub -all {\>} $string "" string]] \
                  ctAmpersands \
                  [list -int [regsub -all {&}  $string "" string]] \
                  ctApostrophes \
                  [list -int [regsub -all {\'} $string "" string]] \
                  ctQuotes \
                  [list -int [regsub -all {\"} $string "" string]]
             ]
        ]
}


# Takes a struct.
# Return the sum of the values larry, curly and moe.

proc validator1.easyStructTest {struct} {
    # De-list-ify the stuct:
    array set bigStruct $struct
    # Return the sum as an integer:
    return [list -int [expr \
            $bigStruct(moe) \
            + $bigStruct(curly) \
            + $bigStruct(larry)]]
}


proc validator1.echoStructTest {struct} {
    foreach {name value} $struct {
        if {[llength $value] > 1} {
            # For the substructs:
            foreach {name2 value2} $value {
                set returnArray($name2) [list -int $value2]
            }
            set output($name) [list -struct [array get returnArray]]
        } else {
            set output($name) $value
        }
        array set returnArray ""
    }
    return [list -struct [array get output]]
}


proc validator1.manyTypesTest {
    number boolean string double dateTime base64
} {
    return [list -array \
             [list \
               [list -int $number] \
               [list -boolean $boolean] \
               [list -text $string] \
               [list -double $double] \
               [list -date [clock format $dateTime]] \
               [list -base64 $base64]]]
}


proc validator1.moderateSizeArrayCheck {array} {
#    array set bigArray $array
#    set counter 0
#    while {[info exists bigArray($counter)]} {
#        incr counter
#    }
#    set counter [expr $counter - 1]
#    return "-string [list "$bigArray(0)$bigArray($counter)"]"
    return "-string \"[lindex $array 0][lindex $array end]\""
}


proc validator1.nestedStructTest {struct} {
    array set bigStruct $struct
    array set 2000 $bigStruct(2000)
    array set April $2000(04)
    array set first $April(01)
    return "-int [expr $first(larry) + $first(curly) + $first(moe)]"
}


proc validator1.simpleStructReturnTest {number} {
    set struct(times10) [list -int [expr $number * 10]]
    set struct(times100) [list -int [expr $number * 100]]
    set struct(times1000) [list -int [expr $number * 1000]]

    return "-struct [list [array get struct]]"
}


############################################################
# XML-RPC Server Validator
# change URL to the server you are trying to validate! for each of
# these procs..

proc validate1.arrayOfStructsTest {
{url http://www.theashergroup.com/RPC2}
    {array ""}
} {
    if {[string equal "" $array]} {
        set array [list \
              [list -struct [list moe [list -int 1] \
                                  curly [list -int 2] \
                                  larry [list -int 3]]] \
              [list -struct [list moe [list -int 1] \
                                  curly [list -int 2] \
                                  larry [list -int 3]]] \
              [list -struct [list moe [list -int 1] \
                                  curly [list -int 2] \
                                  larry [list -int 3]]]]
    }
    return [xmlrpc::remote_call $url validator1.arrayOfStructsTest -array $array]
}

proc validate1.countTheEntities {
                                 {url http://www.theashergroup.com/RPC2}
                                 {string ""}
                             } {
    if {[string equal "" $string]} {
        set string "l'&d>&f&x'>jsua\"&'wmq&'n<t'>k'i<ezc<rv&<&poby&&gh>'"
    }

    return [xmlrpc::remote_call $url validator1.countTheEntities -string $string]
}

proc validate1.easyStructTest {
    {url "http://www.theashergroup.com/RPC2"}
    {struct ""}
} {
    if {[string equal "" $struct]} {
        set struct \
              [list moe [list -int 1] \
                    curly [list -int 2] \
                    larry [list -int 3]]

    }
    return [xmlrpc::remote_call $url validator1.easyStructTest -struct $struct]
}

proc validate1.echoStructTest {
    {url "http://www.theashergroup.com/RPC2"}
    {struct ""}
} {
    if {[string equal $struct ""]} {
        set struct [list bob [list -int 5]]
    }
    return [xmlrpc::remote_call $url validator1.echoStructTest -struct $struct]
}

proc validate1.manyTypesTest {
    {url http://www.theashergroup.com/RPC2}
    {int 1} 
    {boolean 0}
    {string wazzup}
    {double 3.14159}
    {date "20010704T11:50:30"}
    {base64 "R0lGODlhFgASAJEAAP/////OnM7O/wAAACH5BAEAAAAALAAAAAAWABIAAAJAhI+py40zDIzujEDBzW0n74AaFGChqZUYylyYq7ILXJJ1BU95l6r23RrRYhyL5jiJAT/Ink8WTPoqHx31im0UAAA7"}
} {
    return [xmlrpc::remote_call $url validator1.manyTypesTest \
              -int $int -boolean $boolean -string $string \
              -double $double -date $date -base64 $base64]
}

proc validate1.moderateSizeArrayCheck {
                                       {url http://www.theashergroup.com/RPC2}
                                       {array ""}
                                   } {
    if {[string equal "" $array]} {
        set array [list Wisconsin Vermont Utah Idaho Kansas California \
                       Virginia Iowa {New York} Mississippi Maine Delaware \
                       Ohio Washington {West Virginia} Delaware Kentucky \
                       {Rhode Island} Hawaii Oregon Kansas {South Carolina} \
                       Maine Louisiana {West Virginia} Nebraska Georgia \
                       {North Dakota} {North Dakota} Hawaii California Hawaii \
                       {South Dakota} Texas Kentucky Alaska Pennsylvania \
                       Missouri Ohio Wisconsin Hawaii Pennsylvania \
                       Utah Alabama Ohio Michigan Idaho \
                       Montana {New York} Arizona Alaska Vermont \
                       {North Carolina} Washington Alabama {New Mexico} Utah \
                       Nevada {South Dakota} Oklahoma Arizona Mississippi \
                       {New York} Illinois {North Carolina} Georgia Wisconsin \
                       Pennsylvania Wisconsin Minnesota Arkansas Alaska \
                       Iowa Louisiana {West Virginia} Georgia Arizona \
                       Washington Wisconsin Delaware {South Dakota} Delaware \
                       Kentucky {North Dakota} Wisconsin Connecticut Alabama \
                       Delaware Colorado Alabama {New Mexico} Iowa \
                       Michigan Wyoming Oklahoma {South Dakota} Kentucky \
                       Massachusetts Hawaii {North Carolina} Virginia \
                       Delaware Wyoming Colorado Louisiana {West Virginia} \
                       Michigan Utah Connecticut Oklahoma {South Dakota} \
                       {South Dakota} California Minnesota {Rhode Island} \
                       Georgia Kansas Kentucky Michigan Wyoming Nevada \
                       Missouri {New York} Maine Oregon Tennessee {New York} \
                       Washington Connecticut {South Dakota} Wyoming \
                       Minnesota {South Dakota} {New York} {West Virginia} \
                       Hawaii {North Dakota} Ohio Washington Delaware \
                       Massachusetts Nebraska Texas {New York}]
    }
    return [xmlrpc::remote_call $url validator1.moderateSizeArrayCheck -array $array]
}

proc validate1.nestedStructTest {
    {url http://www.theashergroup.com/RPC2}
    {moe 1}
    {larry 2}
    {curly 4}
    {startyear 1999}
    {endyear 2001}
} {
    
    set calendar ""
    # for each year
    for {set y $startyear} {$y <= $endyear} {incr y} {

        set year [list]
        # for each month
        for {set m 1} {$m <= 12} {incr m} {

            set month [list]
            # for each day
            set mstr [format %02d $m]
            for {set d 1} {$d <= 31} {incr d} {
                set dstr [format %02d $d]
                # exit test (to find end of month)
                set date \
                        [clock format \
                          [clock scan "[expr $d - 1] day" \
                            -base [clock scan "$y-${mstr}-01"]] \
                          -format "%y:%m:%d"]
                set date [split $date :]
                set reald [lindex $date 2]
                if {![string equal $reald $dstr]} {
                    break
                }
                
                if {($y == 2000) && ($m == 4) && ($d == 1)} {
                    set dayta \
                        [list -struct \
                           [list moe [list -int $moe] \
                                 curly [list -int $curly] \
                                 larry [list -int $larry]]]
                } else {
                    set dayta \
                        [list -struct \
                           [list moe [list -int [expr 2 * $moe]]]]
                }
                set month [concat $month [list $dstr $dayta]]
            }
            set year [concat $year       [list $mstr [list -struct $month]]]
        }
        set calendar [concat $calendar   [list $y    [list -struct $year]]]
    }
    
    return [xmlrpc::remote_call $url validator1.nestedStructTest -struct $calendar]
}


proc validate1.simpleStructReturnTest {
    {url http://www.theashergroup.com/RPC2}
    {number 2}
} {
    return [xmlrpc::remote_call $url validator1.simpleStructReturnTest -int $number]
}

