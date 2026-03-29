use "libuv.so"
{
  uv_signal_init = "uv_signal_init"(ffi::ptr, ffi::ptr): i32;
  uv_signal_start = "uv_signal_start"(ffi::ptr, ffi::ptr, i32): i32;
  uv_signal_stop = "uv_signal_stop"(ffi::ptr): i32;
  uv_unref = "uv_unref"(ffi::ptr): none;
}

signal
{
  _state
  {
    _signum: i32;
    _handle: array[u8];
    _cb: ffi::callback[(ffi::ptr, i32)->none];

    // Signal state spans three independent concerns:
    // - libuv handle lifetime: _initialized, _closed
    // - active callback/pin lifetime: _active, _in_handler
    // - keepalive policy vs currently-held external token:
    //   _referenced, _externally_active
    _active: bool;
    _initialized: bool;
    _referenced: bool;
    _externally_active: bool;
    _in_handler: bool;
    _closed: bool;

    create(signum: i32): _state
    {
      let _handle = handle::signal;
      let _cb = ffi::callback (handle: ffi::ptr, signum: i32): none -> {}
      new
      {
        _signum = signum,
        _handle,
        _cb,
        _active = false,
        _initialized = false,
        _referenced = true,
        _externally_active = false,
        _in_handler = false,
        _closed = false
      }
    }

    _activate(self: _state, active: bool): none
    {
      if self._active == active
      {
        return
      }

      self._active = active;

      if !self._in_handler
      {
        if active
        {
          ffi::pin self;

          if self._referenced
          {
            ffi::external.add;
            self._externally_active = true
          }
        }
        else
        {
          if self._externally_active
          {
            ffi::external.remove;
            self._externally_active = false
          }

          ffi::unpin self
        }
      }
    }

    start(self: _state, handler: ()->none): none
    {
      if self._closed | self._active
      {
        return
      }

      self._cb = ffi::callback (handle: ffi::ptr, signum: i32): none ->
      {
        if !self._active | self._closed
        {
          return
        }

        self._in_handler = true;
        handler();
        self._in_handler = false;

        if !self._active
        {
          if self._externally_active
          {
            ffi::external.remove;
            self._externally_active = false
          }

          ffi::unpin self
        }
      }

      if !self._initialized
      {
        if :::uv_signal_init(:::uv_default_loop(), self._handle) < 0
        {
          return
        }

        self._initialized = true;

        if !self._referenced
        {
          :::uv_unref(self._handle)
        }
      }

      if :::uv_signal_start(self._handle, self._cb.raw, self._signum) < 0
      {
        return
      }

      self._activate true;
    }

    stop(self: _state): none
    {
      if !self._active | self._closed
      {
        return
      }

      :::uv_signal_stop(self._handle);
      self._activate false
    }

    unref(self: _state): none
    {
      if !self._referenced
      {
        return
      }

      self._referenced = false;

      if self._initialized & !self._closed
      {
        :::uv_unref(self._handle)
      }

      if self._externally_active
      {
        ffi::external.remove;
        self._externally_active = false
      }
    }

    close(self: _state): none
    {
      if self._closed
      {
        return
      }

      self._closed = true;

      if self._active
      {
        :::uv_signal_stop(self._handle);
        self._activate false
      }

      if self._initialized
      {
        :::uv_close(self._handle, none)
      }
    }

    final(self: _state): none
    {
      if self._closed
      {
        return
      }

      if self._active
      {
        :::uv_signal_stop(self._handle)
      }

      if self._externally_active
      {
        ffi::external.remove
      }

      if self._active | self._externally_active
      {
        ffi::unpin self
      }

      if self._initialized
      {
        :::uv_close(self._handle, none)
      }
    }
  }

  _c: cown[_state];

  create(signum: i32, handler: ()->none): signal
  {
    let _c = cown _state(signum);
    let self = new {_c}
    self.start handler;
    self
  }

  create(signum: i32): signal
  {
    let _c = cown _state(signum);
    new {_c}
  }

  start(self: signal, handler: ()->none): none
  {
    self _lock::run t -> t.start handler
  }

  stop(self: signal): none
  {
    self _lock::run t -> t.stop
  }

  close(self: signal): none
  {
    self _lock::run t -> t.close
  }

  unref(self: signal): none
  {
    self _lock::run t -> t.unref
  }
}
