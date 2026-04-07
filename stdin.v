use "libuv.so"
{
  uv_guess_handle = "uv_guess_handle"(i32): i32;
}

stdin
{
  once create(): tty | pipe | file | stdin
  {
    match :::uv_guess_handle(0)
    {
      // TODO: should we be inferring i32 here?
      (7.i32) -> pipe::_stdin;
      (14.i32) -> tty::_stdin;
      (17.i32) -> file::_stdin;
    }
    else
    {
      freeze new {}
    }
  }

  start(self: stdin, h: stream_read::cb): stdin { self }
  close(self: stdin): stdin { self }
}
