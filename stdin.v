use "libuv.so"
{
  uv_guess_handle = "uv_guess_handle"(i32): i32;
}

stdin
{
  create(): tty | pipe | file | none
  {
    // TODO: doesn't work, need correct _state in the handler
    match :::uv_guess_handle(0)
    {
      (7) -> pipe::open 0;
      (14) -> tty;
      (17) -> file::stdin;
    }
    else
    {
      none
    }
  }
}
