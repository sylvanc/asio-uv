use "libuv.so"
{
  uv_udp_init = "uv_udp_init"(ffi::ptr, uv_handle): i32;
  uv_udp_bind = "uv_udp_bind"(uv_handle, ffi::ptr, u32): i32;
  uv_udp_send = "uv_udp_send"(
    uv_req, uv_handle, uv_buf, u32, ffi::ptr, ffi::ptr): i32;
  uv_udp_recv_start = "uv_udp_recv_start"(uv_handle, ffi::ptr, ffi::ptr): i32;
  uv_udp_recv_stop = "uv_udp_recv_stop"(uv_handle): i32;
  uv_udp_set_broadcast = "uv_udp_set_broadcast"(uv_handle, i32): i32;
  uv_udp_set_ttl = "uv_udp_set_ttl"(uv_handle, i32): i32;
}

udp
{
  _state
  {
    _handle: uv_handle;
    _addr: addr;
    _on_recv: (udp, array[u8], usize, addr)->none;
    _acb: ffi::callback[(uv_handle, i32, uv_buf)->none];
    _rcb: ffi::callback[(uv_handle, isize, uv_buf, ffi::ptr, u32)->none];
    _wcb: ffi::callback[(uv_req, i32)->none];
    _recv_active: bool;

    create(_addr: addr): _state
    {
      let _on_recv =
        (u: udp, data: array[u8], size: usize, a: addr): none -> {}

      let _acb = ffi::callback
        (handle: uv_handle, suggested_size: i32, buf: uv_buf): none ->
      {
        let data = array[u8]::fill(suggested_size.usize);
        ffi::pin data;
        _uv_buf_type.store[array[u8]](buf, 0, data);
        _uv_buf_type.store[usize](buf, 1, suggested_size.usize)
      }

      let _rcb = ffi::callback
        (handle: uv_handle, nread: isize, buf: uv_buf,
         sa: ffi::ptr, flags: u32): none -> {}

      let _wcb = ffi::callback (req: uv_req, status: i32): none ->
      {
        let buf = :::uv_req_get_data(req);
        let data = _uv_buf_type.load[array[u8]](buf, 0);
        ffi::unpin data;
        _uv_buf_type.free buf;
        _req::free req
      }

      new
      {
        _handle = handle,
        _addr,
        _on_recv,
        _acb,
        _rcb,
        _wcb,
        _recv_active = false
      }
    }

    _ensure_init(self: _state): none
    {
      if !handle::open self._handle
      {
        self._handle = handle::udp;
        :::uv_udp_init(:::uv_default_loop(), self._handle);
        :::uv_udp_bind(self._handle, self._addr.raw, 0);
        ffi::pin self;
        ffi::external.add
      }
    }

    start(self: _state, h: (udp, array[u8], usize, addr)->none): _state
    {
      self._ensure_init;

      if self._recv_active
      {
        :::uv_udp_recv_stop(self._handle)
      }

      self._on_recv = h;

      self._rcb = ffi::callback
        (handle: uv_handle, nread: isize, buf: uv_buf,
         sa: ffi::ptr, flags: u32): none ->
      {
        let size = _uv_buf_type.load[usize](buf, 1);

        if size == 0
        {
          return
        }

        let data = _uv_buf_type.load[array[u8]](buf, 0);
        ffi::unpin data;

        if nread > 0
        {
          let sender = addr::_from_ptr sa;
          self._on_recv()(self, data, nread.usize, sender)
        }
        else if nread < 0
        {
          self._on_recv()(self, data, 0, addr::invalid)
        }
      }

      if :::uv_udp_recv_start(
          self._handle, self._acb.raw, self._rcb.raw) < 0
      {
        self._on_recv()(self, array[u8]::fill 0, 0, addr::invalid);
        return self.close
      }

      self._recv_active = true;
      self
    }

    send(self: _state, data: array[u8], dest: addr): _state
    {
      self.send(data, data.size, dest)
    }

    send(self: _state, data: array[u8], size: usize, dest: addr): _state
    {
      self._ensure_init;

      if !handle::open self._handle
      {
        return self
      }

      let sz = size min data.size;
      ffi::pin data;
      let buf = _uv_buf_type.alloc;
      _uv_buf_type.store[array[u8]](buf, 0, data);
      _uv_buf_type.store[usize](buf, 1, sz);

      let req = _req::udp_send;
      :::uv_req_set_data(req, buf);

      if :::uv_udp_send(req, self._handle, buf, 1, dest.raw, self._wcb.raw) < 0
      {
        ffi::unpin data;
        _uv_buf_type.free buf;
        _req::free req
      }

      self
    }

    broadcast(self: _state, enable: bool): _state
    {
      if !handle::open self._handle
      {
        return self
      }

      :::uv_udp_set_broadcast(self._handle, if enable { 1 } else { 0 });
      self
    }

    ttl(self: _state, val: i32): _state
    {
      if !handle::open self._handle
      {
        return self
      }

      :::uv_udp_set_ttl(self._handle, val);
      self
    }

    close(self: _state): _state
    {
      if !handle::open self._handle
      {
        return self
      }

      if self._recv_active
      {
        :::uv_udp_recv_stop(self._handle);
        self._recv_active = false
      }

      self._handle = handle::close self._handle;
      ffi::external.remove;
      ffi::unpin self;
      self
    }

    final(self: _state): none
    {
      handle::close self._handle
    }
  }

  _c: cown[_state];

  create(a: addr): udp
  {
    let _c = cown _state a;
    mem::freeze new {_c}
  }

  start(self: udp, h: (udp, array[u8], usize, addr)->none): udp
  {
    self._c _lock::run u -> u.start h;
    self
  }

  send(self: udp, data: array[u8], dest: addr): udp
  {
    self._c _lock::run u -> u.send(data, dest);
    self
  }

  send(self: udp, data: array[u8], size: usize, dest: addr): udp
  {
    self._c _lock::run u -> u.send(data, size, dest);
    self
  }

  broadcast(self: udp, enable: bool = true): udp
  {
    self._c _lock::run u -> u.broadcast enable;
    self
  }

  ttl(self: udp, val: i32): udp
  {
    self._c _lock::run u -> u.ttl val;
    self
  }

  close(self: udp): udp
  {
    self._c _lock::run u -> u.close;
    self
  }
}
