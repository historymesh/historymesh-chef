# Utils needed to build the static assets for HistoryMesh django app

include_recipe "perl"

cpan_module "CSS::Prepare" do
  force :true
end
cpan_module "JavaScript::Prepare"
