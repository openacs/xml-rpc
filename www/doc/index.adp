
<property name="context">{/doc/xml-rpc/ {XML-RPC server}} {XML-RPC}</property>
<property name="doc(title)">XML-RPC</property>
<master>
<h2>XML-RPC Server Documentation</h2>
<h3>Overview</h3>
<blockquote><p>XML-RPC is a protocol which allows clients to make remote
procedure calls on your server. Data is transformed into a standard
XML format before being transferred between the client and server.
This allows software using different OS&#39;s and programming
languages to interact. See <a href="http://xml-rpc.com">XML-RPC.com</a> for more information.</p></blockquote>
<h3>Why do we need it in OpenACS?</h3>
<blockquote><p>Some XML-RPC protocols have become popular in the web world. The
<a href="http://www.blogger.com/developers/api/1_docs/">Blogger
API</a> and the <a href="https://web.archive.org/web/20160809165901/http://xmlrpc.scripting.com:80/metaWeblogApi.html">
Metaweblog API</a> allow users to manage their blogs using tools of
their choice and these have become widespread enough that users
expect to find this functionality in any blogging software. For
this reason, it&#39;s important to provide this minimum of
functionality.</p></blockquote>
<h3>User Documentation</h3>
<blockquote><p>There are no user-facing pages. XML-RPC client software may
require the user to know the URL that is accepting XML-RPC
requests, which is admin-definable (default:
http://example.com/RPC2/). XML-RPC savvy users can call the XML-RPC
method <code>system.listMethods</code> to see which methods the
server supports.</p></blockquote>
<h3>Admin Documentation</h3>
<blockquote>
<p>The server is installed by default at /RPC2/. Administrators can
change this by unmounting the package and remounting it at the
desired URL. The server can be disabled or enabled via the /admin
pages.</p><p>The XML-RPC folks have defined a standard validation suite.
These tests are implemented in the Automated Testing package, so
admins can test their server against this suite (locally) by
running all the automated tests. They can also go to
http://validator.xmlrpc.com to test their site&#39;s validity
(remotely) from there.</p>
</blockquote>
<h3>Developer Documentation</h3>
<blockquote>
<h4>Adding XML-RPC support to your package</h4><blockquote>
<p>The first thing you need to do is write the methods that you
want to be available via XML-RPC. They should be defined as
ad_procs just as any other OpenACS procs except for 2
differences.</p><ol>
<li>They need to be able to <strong>accept arguments</strong> as
sent to them from xmlrpc::decode
<p>In XML-RPC, every value has a datatype. Since TCL is a
weakly-typed language, we could care less about the datatype (for
the most part). So for scalar values (int, boolean, string, double,
dateTime.iso8601, base64), xmlrpc::decode simply sends along the
value to your proc. <strong>To recap, for scalar values, you need
to do nothing special.</strong> For the 2 complex types (structs
and arrays), the values are sent to your proc as TCL structures -
XML-RPC structs are sent TCL arrays and XML-RPC arrays are sent as
TCL lists. For example, if your proc expects a struct with 3
members (name, address and phone), then this is how the beginning
of your proc will look.</p><pre>
  array set user_info $struct
  set name $user_info(name)
  set address $user_info(address)
  set phone $user_info(phone)
  </pre>
Or if your proc expects an array with n integers, which it then
sums, then this is how your proc will look.
<pre>
  foreach num $array {
      incr sum $num
  }
  </pre>
</li><li>They need to be able to <strong>return data</strong> that
xmlrpc::respond will be able to translate to XML.
<p>Scalar data should be returned as a 2 item list {-datatype
value}. So if your proc returns an int, its last statement might
be:</p><pre>
  return [list -int $result]
  </pre>
Returning complex data structures (struct, array) is a little more
*ahem* complex. One of the confusing things is the terminology. As
I noted above, XML-RPC arrays are equivalent to TCL lists and
XML-RPC structs are equivalent to TCL arrays. The other confusing
thing is that XML-RPC is strongly typed and TCL isn&#39;t, so when
you&#39;re converting from TCL to XML-RPC, you need to add the
datatype for each scalar value.
<ul>
<li>Returning an array of mixed type
<pre>
    return [list -array [list [list -int 36] [list -string "foo"]]]
    </pre>
</li><li>Returning a struct (foo=22, bar=blah)
<pre>
    return [list -struct [list foo [list -int 22] bar [list -string blah]]]
    </pre>
</li><li>Returning the above struct using a TCL array
<pre>
    set my_struct(foo) [list -int 22]
    set my_struct(bar) [list -string blah]
    return [list -struct [array get my_struct]]
    </pre>
</li><li>Returning an array of structs
<pre>
    set user1(name) {-string "George Bush"} 
    set user1(id) {-int 41}
    set user2(name) {-string "Bill Clinton"} 
    set user2(id) {-int 42}
    return [list -array [list 
                             [list -struct [array get user1]] 
                             [list -struct [array get user2]]]]
    </pre>
</li>
</ul>
</li>
</ol><p>Once your procs are defined in packagekey/tcl/foo-procs.tcl,
register them in packagekey/tcl/foo-init.tcl. The *-init.tcl files
are loaded after all the *-procs.tcl files have been loaded, so
xmlrpc::register_proc will be available if the xmlrpc package is
installed. Make sure you add the xmlrpc package as a dependency of
your package if you register any XML-RPC procs. If you don&#39;t
want your package to depend on xmlrpc, you can test for the
existence of the xmlrpc_procs nsv before calling
xmlrpc::register_proc</p><p>This registers 'system.listMethods'</p><pre>
xmlrpc::register_proc system.listMethods
</pre>
</blockquote><h4>Implementation details</h4><blockquote>
<p>Here is the sequence of events in an XML-RPC call. See the
documentation for each proc for more details.</p><ol>
<li>A POST request is made to your XML-RPC URL.</li><li>The <code>xmlrpc::get_content</code> proc grabs the content of
the POST request. This is a bit of a hack to cover the fact that
there is no <code>ns_conn content</code> proc.</li><li>
<code>xmlrpc::invoke</code> is called to process the XML
request.</li><li>If the server is disabled, a fault is returned</li><li>The XML is parsed for the methodName and arguments.
<code>xmlrpc::decode_value</code> decodes the XML-RPC params into
TCL variables.</li><li>
<code>xmlrpc::invoke_method</code> checks to be sure the method
is registered and then attempts to call the OpenACS proc</li><li>
<code>xmlrpc::invoke</code> catches any errors from this
attempt and creates an XML-RPC fault to return to the client if so.
If there was no error, then <code>xmlrpc::respond</code> is called
to format the result as an XML-RPC response.</li><li>
<code>xmlrpc::construct</code> does the heavy work of
converting the TCL results back into valid XML-RPC params</li><li>Finally, if no errors occur in this process, the result is
returned to the client as text/xml</li>
</ol><p>More details are provided in the ad_proc documentation for each
proc.</p>
</blockquote>
</blockquote>
<h3>XML-RPC client</h3>
<blockquote>
<p>This package also implements a simple XML-RPC client. Any
package that needs to make XML-RPC calls can simply add a
dependency to this package and then call
<code>xmlrpc::remote_call</code>. As an example, the
<code>system.add</code> method sums a variable number of ints. To
call the <code>system.add</code> method on http://example.com/RPC2/,
do this:</p><pre>
catch {xmlrpc::remote_call http://example.com/RPC2/ system.add -int 4 -int 44 -int 23} result
set result ==&gt; 71
</pre><p>It&#39;s important to <strong>always</strong><code>catch</code>
outgoing XML-RPC calls. If there&#39;s an error, it will be written
to the catch variable (<code>result</code> in the example above).
If there&#39;s no error, then the return value will be in
<code>result</code>.</p><p>
<em>Implementation detail</em>: The client needs to be able to
POST requests to other servers. The util_httppost proc in
acs-tcl/tcl/utilities-procs.tcl doesn&#39;t work because it
doesn&#39;t let you specify the Content-Type, which needs to be
text/xml, and it doesn&#39;t add Host headers, which are required
if the server you&#39;re POSTing to is using virtual hosting. So,
this package implements its own HTTP POST proc (which was stolen
from lars-blogger&#39;s weblogs.com XML-RPC ping).</p>
</blockquote>
<h3>History of XML-RPC in OpenACS</h3>
<blockquote>
<p>The first implementation of XML-RPC for AOLServer was ns_xmlrpc,
whose credits state:</p><blockquote>Ns_xml conversion by Dave Bauer (dave at
thedesignexperience.org) with help from Jerry Asher (jerry at
theashergroup.com). This code is based on the original Tcl-RPC by
Steve Ball with contributions by Aaron Swartz. The original Tcl-RPC
uses TclXML and TclDOM to parse the XML. It works fine but since
OpenACS-4 will use ns_xml I converted it.</blockquote><p>I took this version and converted it into a OpenACS service
package. All of the xml procs now use the XML abstraction procs
inside acs-tcl (which currently use tDOM). All the procs are in a
xmlrpc:: namespace and documentation has been added. I added
support for some standard XML-RPC reserved procs
(system.listMethods, system.methodHelp, system.multicall). I
changed the semantics slightly in one area. XML-RPC arrays were
being converted to TCL arrays, with the name of each item being an
integer index. I thought it made more sense to make these TCL lists
(since that is what a TCL list is anyways). It makes the code more
consistent and makes it easier to understand how to deal with
XML-RPC datatypes.</p><blockquote>XML-RPC struct = TCL array.<br>
XML-RPC array = TCL list.</blockquote>
</blockquote>
<h3>ChangeLog</h3>
<blockquote><ul>
<li>First revision - 2003-10-13 - Vinod Kurup</li><li>Validation tests now implemented via automated-testing -
2003-11-01</li>
</ul></blockquote>
<hr>
<address><a href="mailto:vinod\@kurup.com">Vinod Kurup</a></address>
