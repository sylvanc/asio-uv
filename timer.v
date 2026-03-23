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

    create(): _state
    {
      let _handle = array[u8]::fill :::uv_handle_size(13); // UV_TIMER
      let _cb = ffi::callback (handle: ffi::ptr): none -> {}
      new {_handle, _cb, _active = false}
    }

    init(self: _state, handler: _state->none): none
    {
      self._cb = ffi::callback (handle: ffi::ptr): none ->
      {
        self._active = false;
        ffi::external.remove;
        handler self
      }

      :::uv_timer_init(:::uv_default_loop(), self._handle)
    }

    apply(self: _state, timeout: u64): none
    {
      if !self._active
      {
        self._active = true;
        ffi::external.add
      }

      :::uv_timer_start(self._handle, self._cb.raw, timeout, 0)
    }

    cancel(self: _state): none
    {
      if !self._active
      {
        return
      }

      self._active = false;
      ffi::external.remove;
      :::uv_timer_stop(self._handle)
    }

    close(self: _state): none
    {
      :::uv_close(self._handle, none)
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

  close(self: timer): none
  {
    self _lock::run t -> t.close
  }
}
