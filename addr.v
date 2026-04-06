use "libuv.so"
{
  uv_ip4_addr = "uv_ip4_addr"(ffi::ptr, i32, ffi::ptr): i32;
  uv_ip6_addr = "uv_ip6_addr"(ffi::ptr, i32, ffi::ptr): i32;
  uv_ip4_name = "uv_ip4_name"(ffi::ptr, ffi::ptr, usize): i32;
  uv_ip6_name = "uv_ip6_name"(ffi::ptr, ffi::ptr, usize): i32;
}

use
{
  ntohs = "ntohs"(u16): u16;
}

// sockaddr_in/sockaddr_in6 layout:
//   offset 0: sa_family (u16)
//   offset 2: sin_port / sin6_port (u16, network byte order)
use _sockaddr = ffi::struct[(u16, u16)];

addr
{
  _data: array[u8];

  _from_sockaddr(_data: array[u8]): addr
  {
    freeze new {_data}
  }

  // Create from IP string and port. Auto-detects IPv4 vs IPv6.
  create(ip: string, port: u16): addr
  {
    let _data = array[u8]::fill(128);
    let cs = ip.cstring;

    if :::uv_ip4_addr(cs, port.i32, ffi::ptr _data) == 0
    {
      return freeze new {_data}
    }

    :::uv_ip6_addr(cs, port.i32, ffi::ptr _data);
    freeze new {_data}
  }

  // Create from port only. Binds all interfaces.
  create(port: u16): addr
  {
    addr::ip6(port)
  }

  // Create an IPv4 address from an IP string and port.
  ip4(ip: string, port: u16): addr
  {
    let _data = array[u8]::fill(128);
    :::uv_ip4_addr(ip.cstring, port.i32, ffi::ptr _data);
    freeze new {_data}
  }

  // Create an IPv4 address from a port only. Binds all interfaces.
  ip4(port: u16): addr
  {
    addr::ip4("0.0.0.0", port)
  }

  // Create an IPv6 address from an IP string and port.
  ip6(ip: string, port: u16): addr
  {
    let _data = array[u8]::fill(128);
    :::uv_ip6_addr(ip.cstring, port.i32, ffi::ptr _data);
    freeze new {_data}
  }

  // Create an IPv6 address from a port only. Binds all interfaces.
  ip6(port: u16): addr
  {
    addr::ip6("::", port)
  }

  // Get the address family. AF_INET=2, AF_INET6=10.
  family(self: addr): u16
  {
    _sockaddr.load[u16](ffi::ptr self._data, 0)
  }

  // Get the port number (host byte order).
  port(self: addr): u16
  {
    let p: u16 = _sockaddr.load[u16](ffi::ptr self._data, 1);
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
}
