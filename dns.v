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
    var count = 0;
    var cur = res;

    while cur != ffi::ptr
    {
      count = count + 1;
      cur = _addrinfo.load[ffi::ptr](cur, 7)
    }

    count
  }

  // Walk an addrinfo linked list and build an array of addr.
  _collect(res: ffi::ptr): array[addr]
  {
    let n = dns::_count res;
    var addrs = array[addr]::fill(
      n, addr::_from_ptr(_addrinfo.load[ffi::ptr](res, 5)));
    var cur = res;
    var i = 0;

    while cur != ffi::ptr
    {
      addrs(i) = addr::_from_ptr(_addrinfo.load[ffi::ptr](cur, 5));
      i = i + 1;
      cur = _addrinfo.load[ffi::ptr](cur, 7)
    }

    addrs
  }

  resolve(self: dns, handler: array[addr]->none): dns
  {
    let cb = ffi::callback[(ffi::ptr, i32, ffi::ptr)->none]();

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
        handler(array[addr]::fill(0, addr::invalid))
      }

      ffi::unpin cb;
      ffi::external.remove;
      _req::free(req);
    }

    cb.bind wrapper;

    _lock::run
    {
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
        handler(array[addr]::fill(0, addr::invalid))
      }
    }

    self
  }
}
