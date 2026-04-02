use "libuv.so"
{
  uv_pipe_init = "uv_pipe_init"(ffi::ptr, ffi::ptr, i32): i32;
  uv_pipe_open = "uv_pipe_open"(ffi::ptr, i32): i32;
}

pipe
{
  _state
  {
    _handle: array[u8];
    _r: _stream_reader;
    _w: _stream_writer;
    _on_read: stream_read::cb;
    _started: bool;
    _closed: bool;

    create(fd: i32): _state
    {
      let _on_read = (s: stream_read, data: array[u8], size: usize): none -> {}
      let self = new
      {
        _handle = handle::pipe,
        _r = _stream_reader,
        _w = _stream_writer,
        _on_read,
        _started = false,
        _closed = false
      }

      if :::uv_pipe_init(:::uv_default_loop(), self._handle, 0) < 0
      {
        self._closed = true;
        return self
      }

      if :::uv_pipe_open(self._handle, fd) < 0
      {
        self.close;
        return self
      }

      self
    }

    start(self: _state, h: stream_read::cb): none
    {
      if self._closed | self._started
      {
        return
      }

      self._started = true;
      self._on_read = h;
      ffi::pin self;
      ffi::external.add;

      let cb = (data, size) ->
      {
        if self._closed
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
    }

    write(self: _state, data: array[u8]): none
    {
      if self._closed
      {
        return
      }

      self._w.write(self._handle, data)
    }

    close(self: _state): none
    {
      if self._closed
      {
        return
      }

      self._closed = true;

      if self._started
      {
        self._started = false;
        self._r.stop(self._handle);
        ffi::external.remove;
        ffi::unpin self
      }

      :::uv_close(self._handle, none);
    }

    final(self: _state): none
    {
      if self._closed
      {
        return
      }

      if self._started
      {
        ffi::external.remove;
        ffi::unpin self
      }

      :::uv_close(self._handle, none);
    }
  }

  _c: cown[_state];

  _stdin(): pipe
  {
    let _c = cown _state 0;
    freeze new {_c}
  }

  start(self: pipe, h: stream_read::cb): none
  {
    self._c _lock::run p -> p.start h
  }

  write(self: pipe, data: array[u8]): none
  {
    self._c _lock::run p -> p.write data
  }

  close(self: pipe): none
  {
    self._c _lock::run p -> p.close
  }
}
