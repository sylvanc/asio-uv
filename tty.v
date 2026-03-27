use "libuv.so"
{
  uv_tty_init = "uv_tty_init"(ffi::ptr, uv_handle, i32, i32): i32;
  uv_tty_set_mode = "uv_tty_set_mode"(uv_handle, i32): i32;
  uv_tty_get_winsize = "uv_tty_get_winsize"(uv_handle, ffi::ptr, ffi::ptr): i32;
  uv_tty_reset_mode = "uv_tty_reset_mode"(): i32;
}

tty
{
  _state
  {
    _handle: array[u8];
    _r: _stream_reader;
    _on_read: (_state, array[u8], usize)->none;
    _on_resize: (_state, usize, usize)->none;
    _closed: bool;

    create(_on_read: (_state, array[u8], usize)->none): _state
    {
      new
      {
        _handle = handle::tty(),
        _r = _stream_reader,
        _on_read,
        _on_resize = ((s: _state, w: usize, h: usize): none -> {}),
        _closed = false
      }
    }

    on_read(self: _state, h: (_state, array[u8], usize)->none): none
    {
      self._on_read = h
    }

    on_resize(self: _state, resize: (_state, usize, usize)->none): none
    {
      self._on_resize = resize;
      self._resize
    }

    close(self: _state): none
    {
      self.final;
      self._closed = true;
    }

    _init(self: _state): none
    {
      let rcb = (data, size) ->
      {
        self._on_read()(self, data, size)
      }

      :::uv_tty_init(:::uv_default_loop(), self._handle, 0, 0);
      // :::uv_tty_set_mode(self._handle, 3); // UV_TTY_MODE_RAW_VT
      :::uv_tty_set_mode(self._handle, 1); // UV_TTY_MODE_RAW
      self._r.start(self._handle, rcb);
      ffi::external.add
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
      if !self._closed
      {
        ffi::external.remove;
        self._r.stop(self._handle);
        :::uv_tty_reset_mode();
        :::uv_close(self._handle, none)
      }
    }
  }

  _c: cown[_state];
  _sigwinch: signal;

  create(on_read: (_state, array[u8], usize)->none): tty
  {
    let _c = cown _state on_read;
    let _sigwinch = signal 28; // SIGWINCH
    let self = freeze new {_c, _sigwinch};
    self _lock::run t -> t._init;

    _sigwinch.init
    {
      self _lock::run t -> t._resize;
    }

    self
  }

  on_read(self: _state, h: (_state, array[u8], usize)->none): none
  {
    self _lock::run t -> t.on_read h
  }

  on_resize(self: tty, h: (_state, usize, usize)->none): none
  {
    self _lock::run t -> t.on_resize h
  }

  close(self: tty): none
  {
    self _lock::run t -> t.close
  }
}
