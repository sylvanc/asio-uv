use "libuv.so"
{
  uv_tcp_init = "uv_tcp_init"(ffi::ptr, ffi::ptr): i32;
  uv_tcp_connect =
    "uv_tcp_connect"(ffi::ptr, ffi::ptr, ffi::ptr, ffi::ptr): i32;
  uv_tcp_getpeername = "uv_tcp_getpeername"(ffi::ptr, ffi::ptr, ffi::ptr): i32;
  uv_tcp_nodelay = "uv_tcp_nodelay"(ffi::ptr, i32): i32;
  uv_tcp_keepalive = "uv_tcp_keepalive"(ffi::ptr, i32, u32): i32;
  uv_shutdown = "uv_shutdown"(ffi::ptr, ffi::ptr, ffi::ptr): i32;
}

tcp
{
  _state
  {
    _handle: uv_handle;
    _addr: addr;
    _r: _stream_reader;
    _w: _stream_writer;
    _on_read: stream_read::cb;

    wrap(_handle: uv_handle): _state
    {
      let _on_read = (s: stream_read, data: array[u8], size: usize): none -> {}
      let self = new
      {
        _handle,
        _addr = _state::_get_peer _handle,
        _r = _stream_reader,
        _w = _stream_writer,
        _on_read
      }

      ffi::pin self;
      ffi::external.add;
      self
    }

    connect(_addr: addr): _state
    {
      let _on_read = (s: stream_read, data: array[u8], size: usize): none -> {}
      new
      {
        _handle = handle,
        _addr,
        _r = _stream_reader,
        _w = _stream_writer,
        _on_read
      }
    }

    start(self: _state, h: stream_read::cb): none
    {
      if !handle::open self._handle
      {
        self._handle = handle::tcp;
        :::uv_tcp_init(:::uv_default_loop(), self._handle);
        ffi::pin self;
        ffi::external.add;

        let connect_cb = ffi::callback (req: uv_req, status: i32): none ->
        {
          ffi::unpin :::uv_req_get_data(req);
          _req::free req;

          if status < 0
          {
            // Deliver connect failure as a read error.
            h(self, array[u8]::fill 0, 0);
            self.close;
            return
          }

          // Fill in peer addr now that we're connected.
          self._addr = _state::_get_peer self._handle;

          // Start reading.
          self.start h
        }

        ffi::pin connect_cb;
        let req = _req::connect();
        :::uv_req_set_data(req, ffi::ptr connect_cb);

        if :::uv_tcp_connect(
            req, self._handle, self._addr.raw, connect_cb.raw) < 0
        {
          ffi::unpin connect_cb;
          _req::free req;
          h(self, array[u8]::fill 0, 0);
          self.close;
        }

        return
      }

      self._on_read = h;

      let cb = (data, size) ->
      {
        if !handle::open self._handle
        {
          return
        }

        self._on_read()(self, data, size)
      }

      if !self._r.start(self._handle, cb)
      {
        self._on_read()(self, array[u8]::fill 0, 0);
        self.close
      }
    }

    write(self: _state, data: array[u8]): none
    {
      self.write(data, data.size)
    }

    write(self: _state, data: array[u8], size: usize): none
    {
      if !handle::open self._handle
      {
        return
      }

      self._w.write(self._handle, data, size)
    }

    nodelay(self: _state, enable: bool): none
    {
      if !handle::open self._handle
      {
        return
      }

      :::uv_tcp_nodelay(self._handle, if enable { 1 } else { 0 })
    }

    keepalive(self: _state, enable: bool, delay: u32): none
    {
      if !handle::open self._handle
      {
        return
      }

      :::uv_tcp_keepalive(self._handle, if enable { 1 } else { 0 }, delay)
    }
    
    shutdown(self: _state): none
    {
      if !handle::open self._handle
      {
        return
      }

      let cb = ffi::callback (req: uv_req, status: i32): none ->
      {
        ffi::unpin :::uv_req_get_data(req);
        _req::free req;
      }

      ffi::pin cb;
      let req = _req::shutdown();
      :::uv_req_set_data(req, ffi::ptr cb);
      :::uv_shutdown(req, self._handle, cb.raw)
    }

    close(self: _state): none
    {
      if !handle::open self._handle
      {
        return
      }

      self._handle = handle::close self._handle;
      ffi::external.remove;
      ffi::unpin self
    }

    _get_peer(h: uv_handle): addr
    {
      let buf = array[u8]::fill(128);
      let len = i32 128;
      :::uv_tcp_getpeername(h, buf, ffi::ptr len);
      addr::_from_sockaddr(buf)
    }

    final(self: _state): none
    {
      handle::close self._handle
    }
  }

  _c: cown[_state];

  // Wrap an already-initialized handle as a tcp connection.
  _wrap(handle: uv_handle): tcp
  {
    let _c = cown _state::wrap handle;
    freeze new {_c}
  }

  create(a: addr): tcp
  {
    let _c = cown _state::connect a;
    freeze new {_c}
  }

  start(self: tcp, h: stream_read::cb): none
  {
    self._c _lock::run t -> t.start h
  }

  write(self: tcp, data: array[u8]): none
  {
    self._c _lock::run t -> t.write data
  }

  write(self: tcp, data: array[u8], size: usize): none
  {
    self._c _lock::run t -> t.write(data, size)
  }

  nodelay(self: tcp, enable: bool = true): none
  {
    self._c _lock::run t -> t.nodelay enable
  }

  keepalive(self: tcp, enable: bool = true, delay: u32 = 30): none
  {
    self._c _lock::run t -> t.keepalive enable delay
  }

  shutdown(self: tcp): none
  {
    self._c _lock::run t -> t.shutdown
  }

  close(self: tcp): none
  {
    self._c _lock::run t -> t.close
  }
}
