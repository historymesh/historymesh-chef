name "historymesh_run_migrations"
description "Runs migrations for history mesh once them removes itself from the runlist"

override_attributes(
  "apps" => { "historymesh" => { "_default" => { "run_migrations" => true } } }
)

