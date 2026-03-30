use "libuv.so"
{
  uv_guess_handle = "uv_guess_handle"(i32): i32;
}

stdin
{
  create(): tty | pipe | file | none
  {
    match :::uv_guess_handle(0)
    {
      (7.i32) -> pipe::open 0;
      (14.i32) -> tty;
      (17.i32) -> file::stdin;
    }
    else
    {
      new {}
    }
  }

  start(self: tty, h: stream_read::cb): none {}
  close(self: tty): none {}
}
