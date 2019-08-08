workflow "New workflow" {
  on = "pull_request"
  resolves = ["Run Houston CI"]
}

action "Install Houston" {
  uses = "actions/npm@59b64a598378f31e49cb76f27d6f3312b582f680"
  runs = "npm i -g @elementaryos/houston"
}

action "Run Houston CI" {
  uses = "actions/setup-node@78148dae5052c4942d5b0f92719061df122a3b1c"
  runs = "houston ci"
  args = "--type system-app --name-domain io.elementary.appcenter --name-human AppCenter"
  needs = ["Install Houston"]
}
