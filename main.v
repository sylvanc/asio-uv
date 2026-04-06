use print = "https://github.com/sylvanc/print" "main";

main(): i32
{
  let a = addr 9163;

  let server = tcp_listener(a) (server, conn) ->
  {
    conn.start (conn, data, size) ->
    {
      if size > 0
      {
        print "server got data";
        conn.write(data, size);
        conn.shutdown
      }
      else
      {
        print "server got EOF";
        conn.close
      }
    }

    server.close
  }

  let client = tcp(a).start (conn, data, size) ->
  {
    if size > 0
    {
      print "client got data";
      conn.shutdown
    }
    else
    {
      print "client got EOF";
      conn.close
    }
  }

  client.write array[u8]::fill(4, 'h');
  0
}
