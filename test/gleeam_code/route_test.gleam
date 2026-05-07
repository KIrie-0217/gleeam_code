import gleeam_code.{Auth, Fetch, GlobalOpts, Init, Submit, Test}

pub fn parse_global_with_directory_test() {
  let assert #(GlobalOpts(directory: "/tmp/proj"), ["init"]) =
    gleeam_code.parse_global(["-C", "/tmp/proj", "init"])
}

pub fn parse_global_default_test() {
  let assert #(GlobalOpts(directory: "."), ["fetch", "two-sum"]) =
    gleeam_code.parse_global(["fetch", "two-sum"])
}

pub fn parse_global_empty_test() {
  let assert #(GlobalOpts(directory: "."), []) = gleeam_code.parse_global([])
}

pub fn route_init_test() {
  let assert Ok(Init) = gleeam_code.route(["init"])
}

pub fn route_auth_test() {
  let assert Ok(Auth) = gleeam_code.route(["auth"])
}

pub fn route_fetch_test() {
  let assert Ok(Fetch("two-sum")) = gleeam_code.route(["fetch", "two-sum"])
}

pub fn route_fetch_number_test() {
  let assert Ok(Fetch("1")) = gleeam_code.route(["fetch", "1"])
}

pub fn route_test_test() {
  let assert Ok(Test("two-sum")) = gleeam_code.route(["test", "two-sum"])
}

pub fn route_submit_test() {
  let assert Ok(Submit("two-sum")) = gleeam_code.route(["submit", "two-sum"])
}

pub fn route_fetch_missing_arg_test() {
  let assert Error("Missing argument: <slug-or-number>") =
    gleeam_code.route(["fetch"])
}

pub fn route_unknown_test() {
  let assert Error(_) = gleeam_code.route(["unknown"])
}

pub fn route_empty_test() {
  let assert Error(_) = gleeam_code.route([])
}
