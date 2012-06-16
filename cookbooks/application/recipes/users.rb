
app = node.run_state[:current_app]

group app['group']

user app['owner'] do
  shell "/bin/false"
  group app['group']
  system true
end
