use "libuv.so"
{
  uv_getaddrinfo = "uv_getaddrinfo"(
    ffi::ptr, ffi::ptr, ffi::ptr, ffi::ptr, ffi::ptr, ffi::ptr): i32;
  uv_freeaddrinfo = "uv_freeaddrinfo"(ffi::ptr): none;
}

// struct addrinfo layout (48 bytes on x86-64):
//   0: ai_flags (i32), 4: ai_family (i32), 8: ai_socktype (i32),
//   12: ai_protocol (i32), 16: ai_addrlen (u32 + 4 pad),
//   24: ai_addr (ptr), 32: ai_canonname (ptr), 40: ai_next (ptr)
use _addrinfo =
  ffi::struct[(i32, i32, i32, i32, usize, ffi::ptr, ffi::ptr, ffi::ptr)];

dns
{
  host: string;
  service: string;

  create(host: string, service: string = ""): dns
  {
    new {host, service}
  }

  // Count entries in an addrinfo linked list.
  _count(res: ffi::ptr): usize
  {
    let null = ffi::ptr;
    var count = 1;
    var cur = res;

    while _addrinfo.load[ffi::ptr](cur, 7) != null
    {
      count = count + 1;
      cur = _addrinfo.load[ffi::ptr](cur, 7)
    }

    count
  }

  // Extract an addr from an addrinfo entry using its ai_family and ai_addr.
  _extract(cur: ffi::ptr): addr
  {
    let family = _addrinfo.load[i32](cur, 1);
    let ai_addr = _addrinfo.load[ffi::ptr](cur, 5);
    let ip_buf = array[u8]::fill(64);

    if family == 2
    {
      :::uv_ip4_name(ai_addr, ip_buf, 64);
      let port = _sockaddr.load[u16](ai_addr, 1);
      addr::ip4(string ip_buf, :::ntohs(port))
    }
    else
    {
      :::uv_ip6_name(ai_addr, ip_buf, 64);
      let port = _sockaddr.load[u16](ai_addr, 1);
      addr::ip6(string ip_buf, :::ntohs(port))
    }
  }

  // Walk an addrinfo linked list and build an array of addr.
  _collect(res: ffi::ptr): array[addr]
  {
    let n = dns::_count(res);
    var addrs = array[addr]::fill(n, dns::_extract(res));
    var cur = res;
    var i = 0;

    while i < n
    {
      addrs(i) = dns::_extract(cur);
      i = i + 1;
      cur = _addrinfo.load[ffi::ptr](cur, 7)
    }

    addrs
  }

  resolve(self: dns, handler: array[addr]->none): none
  {
    let wrapper = (req: ffi::ptr, status: i32, res: ffi::ptr): none ->
    {
      if status == 0
      {
        let addrs = dns::_collect(res);
        :::uv_freeaddrinfo(res);
        handler(addrs)
      }
      else
      {
        handler(array[addr]::fill(0))
      }

      ffi::unpin :::uv_req_get_data(req);
      ffi::external.remove;
      _req::free(req);
    }

    _lock::run
    {
      let cb = ffi::callback wrapper;
      let req = _req::getaddrinfo();
      :::uv_req_set_data(req, ffi::ptr cb);
      ffi::pin cb;
      ffi::external.add;

      if :::uv_getaddrinfo(
        :::uv_default_loop(), req, cb.raw,
        self.host.cstring, self.service.cstring, ffi::ptr) < 0
      {
        ffi::unpin cb;
        ffi::external.remove;
        _req::free req;
        handler(array[addr]::fill(0))
      }
    }
  }
}
