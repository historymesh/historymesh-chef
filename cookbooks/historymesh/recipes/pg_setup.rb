include_recipe "database"

data_bag = data_bag_item("apps","historymesh")
username = data_bag["databases"]["_default"]["username"]

passwords = Chef::EncryptedDataBagItem.load("passwords", "postgres")

conn_info = {:host => 'localhost', :username => 'postgres', :password => node['postgresql']['password']['postgres'] }

postgresql_database data_bag["databases"]["_default"]["database"] do
  encoding 'UTF8'
  connection conn_info
end

postgresql_database_user username do
  password passwords[username]
  connection conn_info
end
