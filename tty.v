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
    _in_handler: bool;

    create(_sigwinch: signal, _on_read: stream_read::cb): _state
    {
      let _on_resize = (s: _state, w: usize, h: usize): none -> {}
      let self = new
      {
        _handle = handle::tty,
        _r = _stream_reader,
        _sigwinch,
        _on_read,
        _on_resize,
        _closed = false,
        _in_handler = false
      }

      let rcb = (data, size) ->
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

      :::uv_tty_init(:::uv_default_loop(), self._handle, 0, 0);
      // :::uv_tty_set_mode(self._handle, 3); // UV_TTY_MODE_RAW_VT
      :::uv_tty_set_mode(self._handle, 1); // UV_TTY_MODE_RAW
      ffi::pin self;
      ffi::external.add;
      self._r.start(self._handle, rcb);
      self._resize;
      self
    }

    on_read(self: _state, h: stream_read::cb): none
    {
      self._on_read = h
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

      self._r.stop(self._handle);
      :::uv_tty_reset_mode();
      :::uv_close(self._handle, none);
      ffi::external.remove;
      ffi::unpin self
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
        self._r.stop(self._handle);
        ffi::external.remove;
        ffi::unpin self;
        :::uv_tty_reset_mode();
        :::uv_close(self._handle, none)
      }
    }
  }

  _c: cown[_state];

  create(on_read: stream_read::cb): tty
  {
    let sigwinch = signal 28;
    let _c = cown _state(sigwinch, on_read);
    let self = freeze new {_c}

    sigwinch.start
    {
      self._resize
    }

    self
  }

  on_read(self: tty, h: stream_read::cb): none
  {
    self _lock::run t -> t.on_read h
  }

  on_resize(self: tty, h: resize_cb): none
  {
    self _lock::run t -> t.on_resize h
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
