use test = "https://github.com/sylvanc/test" "main";

main(): none
{
  // ===== addr tests =====

  (test "addr - create from port") tc ->
  {
    let a = addr 8080;
    tc.assert(a.valid, "addr should be valid");
    tc.assert(a.port == 8080, "port should be 8080");
  }

  (test "addr - create from ipv4") tc ->
  {
    let a = addr("127.0.0.1", 8080);
    tc.assert(a.valid, "addr should be valid");
    tc.assert(a.family == 2, "family should be AF_INET (2)");
    tc.assert(a.port == 8080, "port should be 8080");
    tc.assert(a.ip == "127.0.0.1", "ip should be 127.0.0.1");
  }

  (test "addr - create from ipv6") tc ->
  {
    let a = addr("::1", 8080);
    tc.assert(a.valid, "addr should be valid");
    tc.assert(a.family == 10, "family should be AF_INET6 (10)");
    tc.assert(a.port == 8080, "port should be 8080");
  }

  (test "addr - ip4 explicit") tc ->
  {
    let a = addr::ip4("0.0.0.0", 80);
    tc.assert(a.valid, "addr should be valid");
    tc.assert(a.family == 2, "family should be AF_INET (2)");
    tc.assert(a.port == 80, "port should be 80");
  }

  (test "addr - ip6 explicit") tc ->
  {
    let a = addr::ip6("::", 80);
    tc.assert(a.valid, "addr should be valid");
    tc.assert(a.family == 10, "family should be AF_INET6 (10)");
    tc.assert(a.port == 80, "port should be 80");
  }

  (test "addr - ip4 from port") tc ->
  {
    let a = addr::ip4 80;
    tc.assert(a.valid, "addr should be valid");
    tc.assert(a.family == 2, "family should be AF_INET (2)");
    tc.assert(a.port == 80, "port should be 80");
  }

  (test "addr - ip6 from port") tc ->
  {
    let a = addr::ip6 80;
    tc.assert(a.valid, "addr should be valid");
    tc.assert(a.family == 10, "family should be AF_INET6 (10)");
    tc.assert(a.port == 80, "port should be 80");
  }

  (test "addr - invalid") tc ->
  {
    let a = addr::invalid;
    tc.assert(!a.valid, "addr should not be valid");
  }

  (test "addr - invalid ip string") tc ->
  {
    let a = addr("not_an_ip", 80);
    tc.assert(!a.valid, "addr should not be valid");
  }

  (test "addr - port zero") tc ->
  {
    let a = addr 0;
    tc.assert(a.valid, "addr should be valid");
    tc.assert(a.port == 0, "port should be 0");
  }

  // ===== timer tests =====

  (test "timer - fires") tc ->
  {
    let t = timer (t: timer::_state) ->
    {
      tc.assert(true, "timer fired");
    }
    t 10
  }

  (test "timer - cancel") tc ->
  {
    let cancelled = timer (t: timer::_state) ->
    {
      tc.assert(false, "cancelled timer should not fire");
    }
    (cancelled 50).cancel;

    let verify = timer (t: timer::_state) ->
    {
      tc.assert(true, "cancel succeeded");
    }
    verify 100
  }

  (test "timer - zero delay") tc ->
  {
    let t = timer (t: timer::_state) ->
    {
      tc.assert(true, "zero-delay timer fired");
    }
    t 0
  }

  // ===== tcp tests =====

  (test "tcp - echo") tc ->
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
          tc.assert(size == 4, "echo should return 4 bytes");
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

  test.done
}
