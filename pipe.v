use "libuv.so"
{
  uv_pipe_init = "uv_pipe_init"(ffi::ptr, ffi::ptr, i32): i32;
  uv_pipe_open = "uv_pipe_open"(ffi::ptr, i32): i32;
}

pipe
{
  _state
  {
    _handle: uv_handle;
    _fd: i32;
    _r: _stream_reader;
    _w: _stream_writer;
    _on_read: stream_read::cb;

    create(fd: i32): _state
    {
      let _on_read = (s: stream_read, data: array[u8], size: usize): none -> {}

      new
      {
        _handle = handle,
        _fd = fd,
        _r = _stream_reader,
        _w = _stream_writer,
        _on_read
      }
    }

    start(self: _state, h: stream_read::cb): none
    {
      if !handle::open self._handle
      {
        self._handle = handle::pipe;
        :::uv_pipe_init(:::uv_default_loop(), self._handle, 0);
        :::uv_pipe_open(self._handle, self._fd);
        ffi::pin self;
        ffi::external.add
      }

      self._on_read = h;

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
    }

    write(self: _state, data: array[u8]): none
    {
      self.write(data, data.size)
    }

    write(self: _state, data: array[u8], size: usize): none
    {
      if !handle::open self._handle
      {
        return
      }

      self._w.write(self._handle, data, size)
    }

    close(self: _state): none
    {
      if !handle::open self._handle
      {
        return
      }

      self._handle = handle::close self._handle;
      ffi::external.remove;
      ffi::unpin self
    }

  }

  _c: cown[_state];

  _stdin(): pipe
  {
    let _c = cown _state 0;
    mem::freeze new {_c}
  }

  start(self: pipe, h: stream_read::cb): none
  {
    self._c _lock::run p -> p.start h
  }

  write(self: pipe, data: array[u8]): none
  {
    self._c _lock::run p -> p.write data
  }

  write(self: pipe, data: array[u8], size: usize): none
  {
    self._c _lock::run p -> p.write(data, size)
  }

  close(self: pipe): none
  {
    self._c _lock::run p -> p.close
  }
}
