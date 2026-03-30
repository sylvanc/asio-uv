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
    _handle: array[u8];
    _r: _stream_reader;
    _sigwinch: signal;
    _on_read: stream_read::cb;
    _on_resize: resize_cb;
    _closed: bool;
    _started: bool;
    _in_handler: bool;

    create(_sigwinch: signal): _state
    {
      let _on_read = (s: stream_read, data: array[u8], size: usize): none -> {}
      let _on_resize = (s: _state, w: usize, h: usize): none -> {}

      new
      {
        _handle = handle::tty,
        _r = _stream_reader,
        _sigwinch,
        _on_read,
        _on_resize,
        _closed = false,
        _started = false,
        _in_handler = false
      }
    }

    start(self: _state, h: stream_read::cb): none
    {
      if self._closed | self._started
      {
        return
      }

      self._on_read = h;

      if :::uv_tty_init(:::uv_default_loop(), self._handle, 0, 0) < 0
      {
        self._closed = true;
        self._sigwinch.close;
        self._fail_read;
        return
      }

      self._started = true;
      ffi::pin self;
      ffi::external.add;

      // :::uv_tty_set_mode(self._handle, 3); // UV_TTY_MODE_RAW_VT
      if :::uv_tty_set_mode(self._handle, 1) < 0
      {
        self._close;
        return
      }

      let cb = (data, size) ->
      {
        if self._closed
        {
          return
        }

        self._in_handler = true;
        self._on_read()(self, data, size);
        self._in_handler = false;

        if !self._started
        {
          ffi::external.remove;
          ffi::unpin self
        }
      }

      if !self._r.start(self._handle, cb)
      {
        self._close;
        return
      }

      self._resize
    }

    on_resize(self: _state, resize: resize_cb): none
    {
      self._on_resize = resize;
      self._resize
    }

    close(self: _state): none
    {
      if self._closed
      {
        return
      }

      self._closed = true;
      self._sigwinch.close;

      if self._started
      {
        self._started = false;
        self._r.stop self._handle;
        :::uv_tty_reset_mode();
        :::uv_close(self._handle, none);

        if !self._in_handler
        {
          ffi::external.remove;
          ffi::unpin self
        }
      }
    }

    _fail_read(self: _state): none
    {
      self._in_handler = true;
      self._on_read()(self, array[u8]::fill 0, 0);
      self._in_handler = false
    }

    _resize(self: _state): none
    {
      if self._closed
      {
        return
      }

      let w = i32 0;
      let h = i32 0;
      :::uv_tty_get_winsize(self._handle, ffi::ptr w, ffi::ptr h);
      self._on_resize()(self, w.usize, h.usize)
    }

    final(self: _state): none
    {
      if self._closed
      {
        return
      }

      self._sigwinch.close;

      if self._started
      {
        :::uv_tty_reset_mode();
        :::uv_close(self._handle, none);
        ffi::external.remove;
        ffi::unpin self
      }
    }
  }

  _c: cown[_state];

  create(): tty
  {
    let sigwinch = signal 28;
    let _c = cown _state(sigwinch);
    let self = freeze new {_c}

    sigwinch.start
    {
      self._resize
    }

    self
  }

  on_resize(self: tty, h: (_state, usize, usize)->none): none
  {
    self _lock::run t -> t.on_resize h
  }

  start(self: tty, h: stream_read::cb): none
  {
    self _lock::run t -> t.start h
  }

  close(self: tty): none
  {
    self _lock::run t -> t.close
  }

  _resize(self: tty): none
  {
    self _lock::run t -> t._resize
  }
}
