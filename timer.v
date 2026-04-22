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
    _handle: uv_handle;
    _cb: ffi::callback[ffi::ptr->none];
    _active: bool;
    _in_handler: bool;

    create(handler: _state->none): _state
    {
      let self = new
      {
        _handle = handle,
        _cb = ffi::callback[ffi::ptr->none](),
        _active = false,
        _in_handler = false
      }

      self._cb = ffi::callback (handle: ffi::ptr): none ->
      {
        if !self._active
        {
          return
        }

        self._active = false;
        self._in_handler = true;
        handler self;
        self._in_handler = false;

        if !self._active
        {
          ffi::unpin self;
          ffi::external.remove
        }
      }

      self
    }

    apply(self: _state, timeout: u64): _state
    {
      if !handle::open self._handle
      {
        self._handle = handle::timer;
        :::uv_timer_init(:::uv_default_loop(), self._handle);
      }

      self._activate true;
      :::uv_timer_start(self._handle, self._cb.raw, timeout, 0);
      self
    }

    cancel(self: _state): _state
    {
      if !handle::open self._handle
      {
        return self
      }

      :::uv_timer_stop(self._handle);
      self._activate false;
      self
    }

    close(self: _state): _state
    {
      self.cancel;
      self._handle = handle::close self._handle;
      self
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
      handle::close self._handle;
    }
  }

  _c: cown[_state];

  create(handler: _state->none): timer
  {
    mem::freeze new {_c = cown _state handler}
  }

  apply(self: timer, timeout: u64): timer
  {
    self._c _lock::run t -> t timeout;
    self
  }

  cancel(self: timer): timer
  {
    self._c _lock::run t -> t.cancel;
    self
  }
}
