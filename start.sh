export TZ=-0300
nohup bundle exec rackup -p4567 --host 0.0.0.0 >log.out 2>error.out
