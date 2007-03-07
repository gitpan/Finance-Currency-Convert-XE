use Test::More;
eval "use Test::YAML::Meta 0.03";
plan skip_all => "Test::YAML::Meta 0.03 required for testing META.yml" if $@;
meta_yaml_ok();


