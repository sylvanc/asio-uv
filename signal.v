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
    _signum: i32;
    _handle: array[u8];
    _cb: ffi::callback;

    create(signum: i32, handler: ()->none): _state
    {
      let _handle = array[u8]::fill :::uv_handle_size(16); // UV_SIGNAL
      let _cb = ffi::callback (handle: array[u8], signum: i32): none ->
      {
        handler()
      }

      new {_signum = signum, _handle, _cb}
    }

    init(self: _state): none
    {
      :::uv_signal_init(:::uv_default_loop(), self._handle);
      :::uv_signal_start(self._handle, self._cb, self._signum);
      :::uv_unref(self._handle)
    }

    final(self: _state): none
    {
      self._cb.free
    }
  }

  _c: cown[_state];

  once sigpipe(): signal
  {
    // Block SIGPIPE.
    // TODO: not on windows
    signal(13, {}) // SIGPIPE
  }

  create(signum: i32, handler: ()->none): signal
  {
    let _c = cown _state(signum, handler);
    let self = new {_c};
    self _lock::run t -> t.init;
    self
  }
}
