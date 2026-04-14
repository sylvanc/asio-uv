use test = "https://github.com/sylvanc/test" "main";

main(): none
{
  (test "addr - create from port") tc ->
  {
    let a = addr 8080;
    tc.assert(a.valid, "addr should be valid");
    tc.assert(a.port == 8080, "port should be 8080");
  }

  test.done
}
