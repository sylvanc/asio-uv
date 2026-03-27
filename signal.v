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
    _cb: ffi::callback[(ffi::ptr, i32)->none];
    _init: bool;

    create(signum: i32): _state
    {
      let _handle = handle::signal();
      let _cb = ffi::callback (handle: ffi::ptr, signum: i32): none -> {}
      new {_signum = signum, _handle, _cb, _init = false}
    }

    init(self: _state, handler: ()->none): none
    {
      if self._init
      {
        return
      }

      self._cb = ffi::callback (handle: ffi::ptr, signum: i32): none ->
      {
        handler()
      }

      :::uv_signal_init(:::uv_default_loop(), self._handle);
      :::uv_signal_start(self._handle, self._cb.raw, self._signum);
      :::uv_unref(self._handle);
      self._init = true
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
    let _c = cown _state(signum);
    let self = new {_c};
    self _lock::run t -> t.init handler;
    self
  }

  create(signum: i32): signal
  {
    let _c = cown _state(signum);
    new {_c}
  }

  init(self: signal, handler: ()->none): none
  {
    self _lock::run t -> t.init handler
  }
}
