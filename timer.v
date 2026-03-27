use "libuv.so"
{
  uv_timer_init = "uv_timer_init"(ffi::ptr, ffi::ptr): i32;
  uv_timer_start = "uv_timer_start"(ffi::ptr, ffi::ptr, u64, u64): i32;
  uv_timer_stop = "uv_timer_stop"(ffi::ptr): i32;
}

timer
{
  _state
  {
    _handle: array[u8];
    _cb: ffi::callback[ffi::ptr->none];
    _active: bool;
    _in_handler: bool;
    _closed: bool;

    create(): _state
    {
      let _handle = handle::timer();
      let _cb = ffi::callback (handle: ffi::ptr): none -> {}
      new {_handle, _cb, _active = false, _in_handler = false, _closed = false}
    }

    init(self: _state, handler: _state->none): none
    {
      self._cb = ffi::callback (handle: ffi::ptr): none ->
      {
        if !self._active | self._closed
        {
          return
        }

        self._active = false;
        self._in_handler = true;
        handler self;
        self._in_handler = false;

        if !self._active
        {
          ffi::external.remove
        }
      }

      :::uv_timer_init(:::uv_default_loop(), self._handle)
    }

    apply(self: _state, timeout: u64): none
    {
      if self._closed
      {
        return
      }

      self._activate true;
      :::uv_timer_start(self._handle, self._cb.raw, timeout, 0)
    }

    cancel(self: _state): none
    {
      if !self._active | self._closed
      {
        return
      }

      :::uv_timer_stop(self._handle);
      self._activate false
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
          ffi::external.add
        }
        else
        {
          ffi::external.remove;
          ffi::unpin self
        }
      }
    }

    final(self: _state): none
    {
      if !self._closed
      {
        if self._active
        {
          ffi::external.remove;
          ffi::unpin self
        }

        :::uv_close(self._handle, none)
      }
    }
  }

  _c: cown[_state];

  create(handler: _state->none): timer
  {
    let _c = cown _state;
    let self = new {_c};
    self _lock::run t -> t.init handler;
    self
  }

  apply(self: timer, timeout: u64): none
  {
    self _lock::run t -> t timeout
  }

  cancel(self: timer): none
  {
    self _lock::run t -> t.cancel
  }
}
