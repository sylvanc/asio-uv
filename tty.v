use "libuv.so"
{
  uv_tty_init = "uv_tty_init"(ffi::ptr, uv_handle, i32, i32): i32;
  uv_tty_set_mode = "uv_tty_set_mode"(uv_handle, i32): i32;
  uv_tty_get_winsize = "uv_tty_get_winsize"(uv_handle, ffi::ptr, ffi::ptr): i32;
  uv_tty_reset_mode = "uv_tty_reset_mode"(): i32;
}

tty
{
  use resize_cb = (_state, usize, usize)->none;

  _state
  {
    _handle: uv_handle;
    _r: _stream_reader;
    _sigwinch: signal;
    _on_read: stream_read::cb;
    _on_resize: resize_cb;

    create(_sigwinch: signal): _state
    {
      let _on_read = (s: stream_read, data: array[u8], size: usize): none -> {}
      let _on_resize = (s: _state, w: usize, h: usize): none -> {}

      new
      {
        _handle = handle,
        _r = _stream_reader,
        _sigwinch,
        _on_read,
        _on_resize
      }
    }

    start(self: _state, h: stream_read::cb): _state
    {
      self._on_read = h;

      if !handle::open self._handle
      {
        self._handle = handle::tty;
        :::uv_tty_init(:::uv_default_loop(), self._handle, 0, 0);
        :::uv_tty_set_mode(self._handle, 1);
        ffi::pin self;
        ffi::external.add;
      }

      let cb = (data, size) ->
      {
        if !handle::open self._handle
        {
          return
        }

        self._on_read()(self, data, size);
      }

      if !self._r.start(self._handle, cb)
      {
        self._on_read()(self, array[u8]::fill 0, 0);
        self.close
      }
      else
      {
        self._resize
      }
    }

    on_resize(self: _state, resize: resize_cb): _state
    {
      self._on_resize = resize;
      self._resize
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

    _resize(self: _state): _state
    {
      if !handle::open self._handle
      {
        return self
      }

      let w = i32 0;
      let h = i32 0;
      :::uv_tty_get_winsize(self._handle, ffi::ptr w, ffi::ptr h);
      self._on_resize()(self, w.usize, h.usize);
      self
    }

    final(self: _state): none
    {
      handle::close self._handle;
      self._sigwinch.close;
    }
  }

  _c: cown[_state];

  _stdin(): tty
  {
    let sigwinch = signal 28;
    let _c = cown _state sigwinch;
    let self = freeze new {_c}

    sigwinch.start
    {
      self._resize
    }

    self
  }

  on_resize(self: tty, h: (_state, usize, usize)->none): tty
  {
    self._c _lock::run t -> t.on_resize h;
    self
  }

  start(self: tty, h: stream_read::cb): tty
  {
    self._c _lock::run t -> t.start h;
    self
  }

  close(self: tty): tty
  {
    self._c _lock::run t -> t.close;
    self
  }

  _resize(self: tty): tty
  {
    self._c _lock::run t -> t._resize;
    self
  }
}
