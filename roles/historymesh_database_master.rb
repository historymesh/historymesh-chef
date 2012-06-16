name "historymesh_database_master"
description "DB master for historymesh app"

run_list(
  "recipe[postgresql::server]",
  "recipe[historymesh::pg_setup]",
)
