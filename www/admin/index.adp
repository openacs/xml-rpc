<master>
<property name="doc(title)">XML-RPC Administration</property>

<table>
<tr>
  <th>XML-RPC URL:</th> 
  <td>@rpc_url@ </td>
</tr>

<tr>
  <th>Status: </th> 
  <td>
    <a href="toggle"><if @server_enabled_p;literal@ true>Enabled</if><else>Disabled</else></a>
  </td>
</tr>

</table>

<p>
The following procedures are registered:
</p>

<table>
<tr>
<th>Proc Name</th> <th>Enabled?</th>
</tr>

<multiple name="rpc_procs">
  <tr>
    <td>@rpc_procs.name;noquote@</td> <td>@rpc_procs.enabled_p@</td>
  </tr>
</multiple>
</table>
