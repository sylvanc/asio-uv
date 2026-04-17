main(): none
{
  let a = addr("127.0.0.1", 9123);

  let server = tcp_listener(a).start
    (s: tcp_listener::_state, conn: tcp) ->
  {
    conn.start (conn: stream_read, data: array[u8], size: usize) ->
    {
      if size > 0
      {
        conn.write(data, size)
      }
      else
      {
        conn.close
      }
    }
  }

  let t = timer (t: timer::_state) ->
  {
    let client = tcp(a).start
      (conn: stream_read, data: array[u8], size: usize) ->
    {
      if size > 0
      {
        ffi::exit_code 0;
        conn.close;
        server.close
      }
      else
      {
        conn.close
      }
    }
    client.write(array[u8]::fill(4, 72))
  }
  t 10
}
