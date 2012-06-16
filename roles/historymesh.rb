name "historymesh"
description "polyglot role for the historymesh server"

run_list(
  "recipe[nginx]",
  "recipe[postgresql::client]",
  "recipe[restpose]",
  "recipe[application]"
)
