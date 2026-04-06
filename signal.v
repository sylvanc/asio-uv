use "libuv.so"
{
  uv_signal_init = "uv_signal_init"(ffi::ptr, ffi::ptr): i32;
  uv_signal_start = "uv_signal_start"(ffi::ptr, ffi::ptr, i32): i32;
  uv_unref = "uv_unref"(ffi::ptr): none;
}

signal
{
  _state
  {
    _handle: uv_handle;
    _signum: i32;
    _cb: ffi::callback[(uv_handle, i32)->none];

    create(signum: i32): _state
    {
      let _cb = ffi::callback (handle: uv_handle, signum: i32): none -> {}

      new
      {
        _handle = handle,
        _signum = signum,
        _cb
      }
    }

    start(self: _state, handler: ()->none): none
    {
      if !handle::open self._handle
      {
        self._handle = handle::signal;
        :::uv_signal_init(:::uv_default_loop(), self._handle);
        ffi::pin self
      }

      self._cb = ffi::callback (h: uv_handle, signum: i32): none ->
      {
        if !handle::open self._handle
        {
          return
        }

        handler()
      }

      :::uv_signal_start(self._handle, self._cb.raw, self._signum)
    }

    close(self: _state): none
    {
      if !handle::open self._handle
      {
        return
      }

      self._handle = handle::close self._handle
      ffi::unpin self
    }

    unref(self: _state): none
    {
      if !handle::open self._handle
      {
        return
      }

      :::uv_unref(self._handle)
    }

    final(self: _state): none
    {
      handle::close self._handle
    }
  }

  _c: cown[_state];

  create(signum: i32, handler: ()->none): signal
  {
    let _c = cown _state(signum);
    let self = freeze new {_c}
    self.start handler;
    self
  }

  create(signum: i32): signal
  {
    let _c = cown _state signum;
    freeze new {_c}
  }

  start(self: signal, handler: ()->none): none
  {
    self._c _lock::run t -> t.start handler
  }

  close(self: signal): none
  {
    self._c _lock::run t -> t.close
  }

  unref(self: signal): none
  {
    self._c _lock::run t -> t.unref
  }
}
