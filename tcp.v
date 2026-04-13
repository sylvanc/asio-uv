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

    start(self: _state, h: stream_read::cb): _state
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

        mem::merge(self, connect_cb);
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

        return self
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

      self
    }

    write(self: _state, data: array[u8]): _state
    {
      self.write(data, data.size)
    }

    write(self: _state, data: array[u8], size: usize): _state
    {
      if !handle::open self._handle
      {
        return self
      }

      self._w.write(self._handle, data, size);
      self
    }

    nodelay(self: _state, enable: bool): _state
    {
      if !handle::open self._handle
      {
        return self
      }

      :::uv_tcp_nodelay(self._handle, if enable { 1 } else { 0 });
      self
    }

    keepalive(self: _state, enable: bool, delay: u32): _state
    {
      if !handle::open self._handle
      {
        return self
      }

      :::uv_tcp_keepalive(self._handle, if enable { 1 } else { 0 }, delay);
      self
    }

    shutdown(self: _state): _state
    {
      if !handle::open self._handle
      {
        return self
      }

      let cb = ffi::callback (req: uv_req, status: i32): none ->
      {
        ffi::unpin :::uv_req_get_data(req);
        _req::free req;
      }

      ffi::pin cb;
      let req = _req::shutdown();
      :::uv_req_set_data(req, ffi::ptr cb);
      :::uv_shutdown(req, self._handle, cb.raw);
      self
    }

    close(self: _state): _state
    {
      if !handle::open self._handle
      {
        return self
      }

      self._handle = handle::close self._handle;
      ffi::external.remove;
      ffi::unpin self;
      self
    }

    _get_peer(h: uv_handle): addr
    {
      let buf = array[u8]::fill(128);
      let len = i32 128;

      if :::uv_tcp_getpeername(h, buf, ffi::ptr len) < 0
      {
        return addr::invalid
      }

      addr::_from_ptr(ffi::ptr buf)
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
    let _c = when () {_state::wrap handle}
    mem::freeze new {_c}
  }

  create(a: addr): tcp
  {
    let _c = cown _state::connect a;
    mem::freeze new {_c}
  }

  start(self: tcp, h: stream_read::cb): tcp
  {
    self._c _lock::run t -> t.start h;
    self
  }

  write(self: tcp, data: array[u8]): tcp
  {
    self._c _lock::run t -> t.write data;
    self
  }

  write(self: tcp, data: array[u8], size: usize): tcp
  {
    self._c _lock::run t -> t.write(data, size);
    self
  }

  nodelay(self: tcp, enable: bool = true): tcp
  {
    self._c _lock::run t -> t.nodelay enable;
    self
  }

  keepalive(self: tcp, enable: bool = true, delay: u32 = 30): tcp
  {
    self._c _lock::run t -> t.keepalive enable delay;
    self
  }

  shutdown(self: tcp): tcp
  {
    self._c _lock::run t -> t.shutdown;
    self
  }

  close(self: tcp): tcp
  {
    self._c _lock::run t -> t.close;
    self
  }
}
