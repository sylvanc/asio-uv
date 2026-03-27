use "libuv.so"
{
  uv_guess_handle = "uv_guess_handle"(i32): i32;
  uv_poll_init = "uv_poll_init"(ffi::ptr, ffi::ptr, i32): i32;
  uv_poll_start = "uv_poll_start"(ffi::ptr, i32, ffi::ptr): i32;
  uv_poll_stop = "uv_poll_stop"(ffi::ptr): i32;
}

use "libc.so.6"
{
  posix_read = "read"(i32, ffi::ptr, usize): isize;
}

stdin
{
  _state
  {
    _handle: array[u8];
    _chunk: array[u8];
    _cb: ffi::callback[(ffi::ptr, i32, i32)->none];
    _active: bool;
    _closed: bool;

    create(): _state
    {
      let _handle = array[u8]::fill(:::uv_handle_size(14)); // UV_TTY_T
      let _cb = ffi::callback (handle: ffi::ptr, status: i32, events: i32): none -> {};
      new {_handle, _chunk = array[u8]::fill(4096), _cb, _active = false, _closed = false}
    }

    init(self: _state, handler: string->none): none
    {
      self._cb = ffi::callback (handle: ffi::ptr, status: i32, events: i32): none ->
      {
        if self._closed
        {
          return
        }

        if (status < 0) | ((events & 1) == 0) // UV_READABLE
        {
          self.close;
          return
        }

        let nread = :::posix_read(0, self._chunk, self._chunk.size);

        if nread <= 0
        {
          self.close;
          return
        }

        handler(self._chunk_string(nread.usize))
      };

      :::uv_poll_init(:::uv_default_loop(), self._handle, 0);
      :::uv_poll_start(self._handle, 1, self._cb.raw); // UV_READABLE
      self._active = true;
      ffi::external.add
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
        self._active = false;
        ffi::external.remove
      }

      :::uv_poll_stop(self._handle);
      :::uv_close(self._handle, none)
    }

    _chunk_string(self: _state, len: usize): string
    {
      let data = array[u8]::fill(len + 1);
      data.copy_from(0, self._chunk, 0, len);
      data(len) = 0;
      string(data)
    }
  }

  _supported: bool;
  _c: cown[_state];

  create(handler: string->none): stdin
  {
    let t = :::uv_guess_handle(0);
    let _supported = (:::uv_guess_handle(0) == 14) | (:::uv_guess_handle(0) == 7);
    let _c = cown _state;
    let self = new {_supported, _c};

    if _supported
    {
      self _lock::run t -> t.init handler
    }

    self
  }

  supported(self: stdin): bool
  {
    self._supported
  }
}
