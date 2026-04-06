use "libuv.so"
{
  uv_tcp_bind = "uv_tcp_bind"(ffi::ptr, ffi::ptr, i32): i32;
  uv_tcp_simultaneous_accepts =
    "uv_tcp_simultaneous_accepts"(ffi::ptr, i32): i32;
  uv_listen = "uv_listen"(ffi::ptr, i32, ffi::ptr): i32;
  uv_accept = "uv_accept"(ffi::ptr, ffi::ptr): i32;
}

tcp_listener
{
  _state
  {
    _handle: uv_handle;
    _addr: addr;
    _cb: ffi::callback[(uv_handle, i32)->none];

    create(_addr: addr): _state
    {
      let _cb = ffi::callback (server: uv_handle, status: i32): none -> {}
      new { _handle = handle, _addr, _cb }
    }

    start(self: _state, handler: (_state, tcp)->none): none
    {
      if !handle::open self._handle
      {
        self._handle = handle::tcp;
        :::uv_tcp_init(:::uv_default_loop(), self._handle);
        :::uv_tcp_bind(self._handle, self._addr.raw, 0);
        :::uv_tcp_simultaneous_accepts(self._handle, 1);
        ffi::pin self;
        ffi::external.add
      }

      self._cb = ffi::callback (server: uv_handle, status: i32): none ->
      {
        if status < 0
        {
          return
        }

        let client = handle::tcp;
        :::uv_tcp_init(:::uv_default_loop(), client);

        if :::uv_accept(server, client) < 0
        {
          handle::close client;
          return
        }

        handler(self, tcp::_wrap client)
      }

      :::uv_listen(self._handle, 128, self._cb.raw);
    }

    close(self: _state): none
    {
      if !handle::open self._handle
      {
        return
      }

      self._handle = handle::close self._handle;
      ffi::unpin self;
      ffi::external.remove
    }

    final(self: _state): none
    {
      handle::close self._handle
    }
  }

  _c: cown[_state];

  create(a: addr): tcp_listener
  {
    let _c = cown _state a;
    freeze new {_c}
  }

  start(self: tcp_listener, handler: (_state, tcp)->none): none
  {
    self._c _lock::run t -> t.start handler
  }

  close(self: tcp_listener): none
  {
    self._c _lock::run t -> t.close
  }
}
