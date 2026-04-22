use test = "https://github.com/sylvanc/test" "main";

main(): none
{
  asio_uv::tests;
  test.done
}

tests(): none
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

  (test "timer - cancel rearm") tc ->
  {
    var count = 0;
    let t = timer (t: timer::_state) ->
    {
      count = count + 1;
      tc.assert(count == 1, "should fire exactly once after rearm");
    }
    (t 50).cancel;
    t 10
  }

  // ===== tcp tests =====

  (test "tcp - echo") tc ->
  {
    let a = addr("127.0.0.1", 9123);

    let server = tcp_listener(a).start
      (s: tcp_listener::_state, conn: tcp) ->
    {
      conn.start (s: stream_read, data: array[u8], size: usize) ->
      {
        if size > 0
        {
          s.write(data, size)
        }
        else
        {
          s.close
        }
      }
    }

    let t = timer (t: timer::_state) ->
    {
      let client = tcp(a).start
        (s: stream_read, data: array[u8], size: usize) ->
      {
        if size > 0
        {
          tc.assert(size == 4, "echo should return 4 bytes");
          s.close;
          server.close
        }
        else
        {
          s.close
        }
      }

      client.write(array[u8]::fill(4, 72))
    }

    t 10
  }

  (test "dns - resolve localhost") tc ->
  {
    dns("localhost", "80").resolve (addrs: array[addr]) ->
    {
      tc.assert(addrs.size > 0, "localhost should resolve");
    }
  }

  (test "addr - resolve") tc ->
  {
    let a = addr("127.0.0.1", 80);
    a.resolve (d: dns) ->
    {
      tc.assert(d.host.size > 0, "resolve should return a host");
    }
  }

  // ===== udp tests =====

  (test "udp - echo") tc ->
  {
    let recv_addr = addr("127.0.0.1", 9200);
    let send_addr = addr("127.0.0.1", 9201);

    let sender = udp send_addr;
    let receiver = udp(recv_addr).start
      (u: udp::_state, data: array[u8], size: usize, from: addr) ->
    {
      tc.assert(size == 4, "should receive 4 bytes");
      u.close
    }

    let t = timer (t: timer::_state) ->
    {
      sender.send(array[u8]::fill(4, 42), recv_addr);

      let cleanup = timer (t: timer::_state) ->
      {
        sender.close
      }
      cleanup 200
    }
    t 10
  }

  // ===== tcp additional tests =====

  (test "tcp - shutdown") tc ->
  {
    let a = addr("127.0.0.1", 9124);

    let server = tcp_listener(a).start
      (s: tcp_listener::_state, conn: tcp) ->
    {
      conn.start (s: stream_read, data: array[u8], size: usize) ->
      {
        if size > 0
        {
          tc.assert(size == 4, "server should receive 4 bytes");
        }

        s.close
      }
    }

    let t = timer (t: timer::_state) ->
    {
      let client = tcp(a).start
        (s: stream_read, data: array[u8], size: usize) ->
      {
        s.close;
        server.close
      }

      client.write(array[u8]::fill(4, 99));
      client.shutdown
    }
    t 10
  }

  (test "tcp - connect refused") tc ->
  {
    let a = addr("127.0.0.1", 9999);

    let client = tcp(a).start
      (s: stream_read, data: array[u8], size: usize) ->
    {
      tc.assert(size == 0, "connect failure should give size 0");
      s.close
    }
  }

  (test "tcp - options") tc ->
  {
    let a = addr("127.0.0.1", 9125);

    let server = tcp_listener(a).start
      (s: tcp_listener::_state, conn: tcp) ->
    {
      conn.nodelay true;
      conn.keepalive(true, 30);
      conn.start (s: stream_read, data: array[u8], size: usize) ->
      {
        s.close
      }
    }

    let t = timer (t: timer::_state) ->
    {
      let client = tcp(a).start
        (s: stream_read, data: array[u8], size: usize) ->
      {
        s.close;
        server.close
      }

      client.nodelay true;
      client.keepalive(true, 30);
      tc.assert(true, "options set without crash");
      client.close
    }
    t 10
  }

  // ===== timer additional tests =====

  (test "timer - rearm") tc ->
  {
    var count = 0;

    let t = timer (t: timer::_state) ->
    {
      count = count + 1;

      if count < 2
      {
        t 10
      }
      else
      {
        tc.assert(count == 2, "timer should fire twice");
      }
    }
    t 10
  }
}
