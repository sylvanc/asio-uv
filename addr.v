use "libuv.so"
{
  uv_ip4_addr = "uv_ip4_addr"(ffi::ptr, i32, ffi::ptr): i32;
  uv_ip6_addr = "uv_ip6_addr"(ffi::ptr, i32, ffi::ptr): i32;
  uv_ip4_name = "uv_ip4_name"(ffi::ptr, ffi::ptr, usize): i32;
  uv_ip6_name = "uv_ip6_name"(ffi::ptr, ffi::ptr, usize): i32;
  uv_getnameinfo = "uv_getnameinfo"(
    ffi::ptr, uv_req, ffi::ptr, ffi::ptr, i32): i32;
}

use
{
  ntohs = "ntohs"(u16): u16;
  memcpy = "memcpy"(ffi::ptr, ffi::ptr, usize): ffi::ptr;
}

// sockaddr_in/sockaddr_in6 layout:
//   offset 0: sa_family (u16)
//   offset 2: sin_port / sin6_port (u16, network byte order)
use _sockaddr = ffi::struct[(u16, u16)];

addr
{
  _data: array[u8];

  // An invalid address (AF_UNSPEC, family=0).
  once invalid(): addr
  {
    new {_data = array[u8]::fill(28)}
  }

  _from_sockaddr(_data: array[u8]): addr
  {
    mem::freeze new {_data}
  }

  // Create an addr from a C sockaddr pointer.
  _from_ptr(sa: ffi::ptr): addr
  {
    let family = _sockaddr.load[u16](sa, 0);

    if family == 2
    {
      let _data = array[u8]::fill(16);
      :::memcpy(_data, sa, 16);
      mem::freeze new {_data}
    }
    else if family == 10
    {
      let _data = array[u8]::fill(28);
      :::memcpy(_data, sa, 28);
      mem::freeze new {_data}
    }
    else
    {
      addr::invalid
    }
  }

  // Create from IP string and port. Auto-detects IPv4 vs IPv6.
  create(ip: string, port: u16): addr
  {
    let _data = array[u8]::fill(28);
    let cs = ip.cstring;

    if :::uv_ip4_addr(cs, port.i32, ffi::ptr _data) == 0
    {
      return mem::freeze new {_data}
    }

    if :::uv_ip6_addr(cs, port.i32, ffi::ptr _data) == 0
    {
      return mem::freeze new {_data}
    }

    addr::invalid
  }

  // Create from port only. Binds all interfaces.
  create(port: u16): addr
  {
    addr::ip6 port
  }

  // Create an IPv4 address from an IP string and port.
  ip4(ip: string, port: u16): addr
  {
    let _data = array[u8]::fill(16);

    if :::uv_ip4_addr(ip.cstring, port.i32, ffi::ptr _data) == 0
    {
      return mem::freeze new {_data}
    }

    addr::invalid
  }

  // Create an IPv4 address from a port only. Binds all interfaces.
  ip4(port: u16): addr
  {
    addr::ip4("0.0.0.0", port)
  }

  // Create an IPv6 address from an IP string and port.
  ip6(ip: string, port: u16): addr
  {
    let _data = array[u8]::fill(28);

    if :::uv_ip6_addr(ip.cstring, port.i32, ffi::ptr _data) == 0
    {
      return mem::freeze new {_data}
    }

    addr::invalid
  }

  // Create an IPv6 address from a port only. Binds all interfaces.
  ip6(port: u16): addr
  {
    addr::ip6("::", port)
  }

  // True if the address has a valid family (AF_INET or AF_INET6).
  valid(self: addr): bool
  {
    let f = self.family;
    (f == 2) | (f == 10)
  }

  // Get the address family. AF_INET=2, AF_INET6=10, AF_UNSPEC=0.
  family(self: addr): u16
  {
    _sockaddr.load[u16](ffi::ptr self._data, 0)
  }

  // Get the port number (host byte order).
  port(self: addr): u16
  {
    let p = _sockaddr.load[u16](ffi::ptr self._data, 1);
    :::ntohs(p)
  }

  // Get the IP address as a string.
  ip(self: addr): string
  {
    let buf = array[u8]::fill(64);

    if self.family == 2
    {
      :::uv_ip4_name(ffi::ptr self._data, buf, 64)
    }
    else
    {
      :::uv_ip6_name(ffi::ptr self._data, buf, 64)
    }

    string buf
  }

  // Get a pointer to the underlying sockaddr for FFI calls.
  raw(self: addr): ffi::ptr
  {
    ffi::ptr self._data
  }

  // Reverse-resolve this address to a hostname and service name.
  resolve(self: addr, handler: dns -> none): addr
  {
    let wrapper =
      (req: uv_req, status: i32,
       hostname: ffi::ptr, service: ffi::ptr): none ->
    {
      if status == 0
      {
        let host = string::from_cstr(hostname);
        let serv = string::from_cstr(service);
        handler(dns(host, serv))
      }
      else
      {
        handler(dns("", ""))
      }

      ffi::unpin :::uv_req_get_data(req);
      ffi::external.remove;
      _req::free req
    }

    _lock::run
    {
      let cb = ffi::callback wrapper;
      let req = _req::getnameinfo();
      :::uv_req_set_data(req, ffi::ptr cb);
      ffi::pin cb;
      ffi::external.add;

      if :::uv_getnameinfo(
          :::uv_default_loop(), req, cb.raw, self.raw, 0) < 0
      {
        ffi::unpin cb;
        ffi::external.remove;
        _req::free req;
        handler(dns("", ""))
      }
    }

    self
  }
}
